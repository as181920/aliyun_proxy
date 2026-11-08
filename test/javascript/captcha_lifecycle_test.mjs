import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const template = readFileSync(new URL('../../app/views/aliyun_proxy/captcha/_verification.html.erb', import.meta.url), 'utf8');
const rendered = template.replace(/<%=[\s\S]*?%>/g, expression => {
  if (expression.includes('@client_options')) return JSON.stringify({ SceneId: 'scene' });
  if (expression.includes('@prefix')) return JSON.stringify('prefix');
  if (expression.includes('captcha_verification_path')) return JSON.stringify('/verify.json');
  return JSON.stringify({ loading: 'Loading', verifying: 'Verifying', retry: 'Try again', checking: 'Checking', failed: 'Failed', unavailable: 'Unavailable' });
});

const source = rendered.match(/<script\b[^>]*>([\s\S]*?)<\/script>/)[1];

function page({ loaded = true, traceless = true, fetch, start } = {}) {
  const document = new EventTarget();
  const button = { disabled: true, textContent: 'Loading', isConnected: true,
    click() { if (!this.disabled) this.onclick?.(); } };
  const status = { textContent: '' };
  const timers = new Map();
  const calls = { initialized: 0, started: 0, shown: 0, hidden: 0, requests: 0, redirected: [] };
  let options, loader, nextTimer = 0;
  document.getElementById = id => id === 'captcha-button' ? button : status;
  document.querySelector = () => ({ content: 'csrf-token' });
  document.createElement = () => ({ remove() { calls.loaderRemoved = true; } });
  document.head = { appendChild(script) { loader = script; } };
  const window = {
    setTimeout(callback, delay) { timers.set(++nextTimer, { callback, delay }); return nextTimer; },
    clearTimeout(id) { timers.delete(id); },
    location: { replace(url) { calls.redirected.push(url); } }
  };
  const initialize = config => {
    calls.initialized++;
    options = config;
    const instance = { hide() { calls.hidden++; }, show() { calls.shown++; } };
    if (traceless) instance.startTracelessVerification = () => { calls.started++; start?.(); };
    config.getInstance(instance);
  };
  if (loaded) window.initAliyunCaptcha = initialize;
  runInNewContext(source, {
    window, document, AbortController,
    fetch(...args) { calls.requests++; return fetch(...args); }
  });
  const runTimers = () => {
    for (const [id, { callback }] of [...timers]) { timers.delete(id); callback(); }
  };
  return { document, window, button, status, calls, timers, initialize, runTimers,
    get options() { return options; }, get loader() { return loader; } };
}

test('a Turbo-rendered page initializes with the already loaded SDK', () => {
  const p = page();
  assert.equal(p.calls.initialized, 1);
  assert.equal(p.loader, undefined);
  assert.equal(p.options.button, '#captcha-trigger');
  assert.equal(p.calls.started, 0);
  assert.equal(p.button.disabled, true);
});

test('a ready page starts traceless verification once without a user click', () => {
  const p = page();
  assert.equal([...p.timers.values()][0].delay, 2000);
  p.runTimers();
  p.runTimers();
  p.button.click();
  assert.equal(p.calls.started, 1);
  assert.equal(p.button.disabled, true);
  assert.equal(p.button.textContent, 'Verifying');
});

test('successful verification checks the backend before automatically continuing', async () => {
  let request;
  const p = page({ fetch(url, options) {
    request = { url, ...options };
    return Promise.resolve({ ok: true, json: async () => ({ redirect_url: '/original-return' }) });
  } });
  p.runTimers();
  await p.options.success('not-a-real-ticket');
  assert.equal(request.url, '/verify.json');
  assert.equal(request.method, 'PATCH');
  assert.equal(request.headers['X-CSRF-Token'], 'csrf-token');
  assert.deepEqual(JSON.parse(request.body), { captcha: { verify_param: 'not-a-real-ticket' } });
  assert.deepEqual(p.calls.redirected, ['/original-return']);
});

test('a nontraceless instance opens its supported verification interface', () => {
  const p = page({ traceless: false });
  p.runTimers();
  assert.equal(p.calls.shown, 1);
  assert.equal(p.calls.started, 0);
});

test('vendor rejection enables a manual retry without an automatic retry loop', () => {
  const p = page();
  p.runTimers();
  p.options.fail();
  assert.equal(p.button.textContent, 'Try again');
  assert.equal(p.status.textContent, 'Failed');
  assert.equal(p.calls.initialized, 1);
  assert.equal(p.calls.started, 1);
  p.button.click();
  assert.equal(p.calls.started, 2);
});

test('closing the risk interaction leaves a retry instead of a stuck loading state', () => {
  const p = page();
  p.runTimers();
  p.options.onClose('userDismiss');
  assert.equal(p.button.disabled, false);
  p.button.click();
  assert.equal(p.calls.started, 2);
});

test('SDK errors wait for manual retry before reinitializing', () => {
  const p = page();
  p.options.onError();
  assert.equal(p.timers.size, 0);
  assert.equal(p.status.textContent, 'Unavailable');
  p.button.click();
  assert.equal(p.calls.initialized, 2);
  p.runTimers();
  assert.equal(p.calls.started, 1);
});

test('SDK download failure can be retried without reloading the page', () => {
  const p = page({ loaded: false });
  const firstLoader = p.loader;
  firstLoader.onerror();
  assert.equal(p.button.disabled, false);
  p.button.click();
  assert.notEqual(p.loader, firstLoader);
  p.window.initAliyunCaptcha = p.initialize;
  p.loader.onload();
  p.runTimers();
  assert.equal(p.calls.started, 1);
});

test('backend rejection cannot redirect or automatically repeat verification', async () => {
  const p = page({ fetch: async () => ({ ok: false, json: async () => ({ error: { message: 'Rejected' } }) }) });
  p.runTimers();
  await p.options.success('not-a-real-ticket');
  assert.equal(p.status.textContent, 'Rejected');
  assert.deepEqual(p.calls.redirected, []);
  assert.equal(p.calls.initialized, 1);
  p.button.click();
  assert.equal(p.calls.initialized, 2);
  p.runTimers();
  assert.equal(p.calls.started, 2);
});

test('backend network failure permits a fresh manual verification', async () => {
  const p = page({ fetch: async () => { throw new Error('offline'); } });
  p.runTimers();
  await p.options.success('not-a-real-ticket');
  assert.equal(p.status.textContent, 'Unavailable');
  assert.equal(p.button.disabled, false);
  assert.deepEqual(p.calls.redirected, []);
  p.button.click();
  p.runTimers();
  assert.equal(p.calls.started, 2);
});

test('synchronous verification errors leave a usable retry button', () => {
  const p = page({ start() { throw new Error('SDK unavailable'); } });
  p.runTimers();
  assert.equal(p.button.disabled, false);
  assert.equal(p.status.textContent, 'Unavailable');
});

test('late vendor errors cannot unlock or restart pending backend verification', async () => {
  let resolve;
  const response = new Promise(done => { resolve = done; });
  const p = page({ fetch: () => response });
  p.runTimers();
  const verifying = p.options.success('not-a-real-ticket');
  p.options.fail();
  p.options.onError();
  p.options.onClose('userDismiss');
  p.button.click();
  assert.equal(p.button.disabled, true);
  assert.equal(p.status.textContent, 'Checking');
  assert.equal(p.calls.initialized, 1);
  resolve({ ok: true, json: async () => ({ redirect_url: '/original-return' }) });
  await verifying;
  assert.deepEqual(p.calls.redirected, ['/original-return']);
});

test('leaving before SDK download finishes cannot initialize the old page', () => {
  const p = page({ loaded: false });
  const loaded = p.loader.onload;
  p.document.dispatchEvent(new Event('turbo:before-render'));
  p.window.initAliyunCaptcha = p.initialize;
  loaded();
  assert.equal(p.calls.initialized, 0);
  assert.equal(p.calls.loaderRemoved, true);
});

test('before-cache clears delayed readiness and ignores late SDK callbacks', async () => {
  const p = page();
  p.document.dispatchEvent(new Event('turbo:before-cache'));
  p.options.fail();
  await p.options.success('not-a-real-ticket');
  assert.equal(p.timers.size, 0);
  assert.equal(p.button.disabled, true);
  assert.equal(p.calls.requests, 0);
  assert.equal(p.status.textContent, '');
  assert.equal(p.calls.hidden, 1);
  assert.equal(p.calls.started, 0);
  assert.equal(p.button.onclick, null);
});

test('navigation aborts a pending request and its late result cannot redirect', async () => {
  let resolve;
  const response = new Promise(done => { resolve = done; });
  let signal;
  const p = page({ fetch(_url, options) { signal = options.signal; return response; } });
  const verifying = p.options.success('not-a-real-ticket');
  await p.options.success('duplicate-ticket');
  p.options.onClose('userDismiss');
  assert.equal(p.button.disabled, true);
  assert.equal(p.calls.requests, 1);
  p.document.dispatchEvent(new Event('turbo:before-render'));
  resolve({ ok: true, json: async () => ({ redirect_url: '/should-not-open' }) });
  await verifying;
  assert.equal(signal.aborted, true);
  assert.deepEqual(p.calls.redirected, []);
});

test('both Turbo cleanup events close the instance only once', () => {
  const p = page();
  p.document.dispatchEvent(new Event('turbo:before-cache'));
  p.document.dispatchEvent(new Event('turbo:before-render'));
  assert.equal(p.calls.hidden, 1);
});
