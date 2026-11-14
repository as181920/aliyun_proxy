import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const template = readFileSync(new URL('../../app/views/aliyun_proxy/captcha/_verification.html.erb', import.meta.url), 'utf8');
function verificationSource(attemptPath, eventPath, expiresIn) {
  const rendered = template.replace(/<%=[\s\S]*?%>/g, expression => {
    if (expression.includes('@captcha_attempt_path')) return JSON.stringify(attemptPath);
    if (expression.includes('@captcha_event_path')) return JSON.stringify(eventPath);
    if (expression.includes('@captcha_expires_in')) return JSON.stringify(expiresIn);
    if (expression.includes('@client_origin')) return 'null';
    if (expression.includes('@challenge.id')) return JSON.stringify('challenge');
    if (expression.includes('@client_options')) return JSON.stringify({ SceneId: 'scene' });
    if (expression.includes('@prefix')) return JSON.stringify('prefix');
    if (expression.includes('captcha_verification_path')) return JSON.stringify('/verify.json');
    return JSON.stringify({ loading: 'Loading', verifying: 'Verifying', retry: 'Try again', checking: 'Checking', failed: 'Failed', unavailable: 'Unavailable', wait: 'Wait {seconds}s' });
  });

  return rendered.match(/<script\b[^>]*>([\s\S]*?)<\/script>/)[1];
}

function page({ loaded = true, traceless = true, fetch, start, attemptPath = null, eventPath = null, expiresIn = 600 } = {}) {
  const document = new EventTarget();
  const button = { disabled: true, textContent: 'Loading', isConnected: true,
    click() { if (!this.disabled) this.onclick?.(); } };
  const status = { textContent: '' };
  const cancel = {};
  const timers = new Map();
  const intervals = new Map();
  let now = Date.now();
  class Clock extends Date { static now() { return now; } }
  const calls = { initialized: 0, started: 0, shown: 0, hidden: 0, requests: 0, redirected: [] };
  let options, loader, instance, nextTimer = 0;
  const microtasks = [];
  document.getElementById = id => id === 'captcha-button' ? button : id === 'captcha-cancel' ? cancel : status;
  document.querySelector = () => ({ content: 'csrf-token' });
  document.createElement = () => ({ remove() { calls.loaderRemoved = true; } });
  document.head = { appendChild(script) { loader = script; } };
  const window = {
    setTimeout(callback, delay) { timers.set(++nextTimer, { callback, delay, deadline: now + delay }); return nextTimer; },
    clearTimeout(id) { timers.delete(id); },
    setInterval(callback) { intervals.set(++nextTimer, callback); return nextTimer; },
    clearInterval(id) { intervals.delete(id); },
    location: { replace(url) { calls.redirected.push(url); } }
  };
  const initialize = config => {
    calls.initialized++;
    options = config;
    instance = {
      visible: false,
      hide() { calls.hidden++; this.visible = false; },
      show() { calls.shown++; this.visible = true; }
    };
    if (traceless) instance.startTracelessVerification = () => {
      calls.started++;
      if (calls.started === 1) instance.visible = true;
      start?.();
    };
    config.getInstance(instance);
  };
  if (loaded) window.initAliyunCaptcha = initialize;
  runInNewContext(verificationSource(attemptPath, eventPath, expiresIn), {
    window, document, AbortController, Date: Clock,
    queueMicrotask(callback) { microtasks.push(callback); },
    fetch(...args) { calls.requests++; return fetch(...args); }
  });
  const runTimers = () => {
    while (microtasks.length) microtasks.shift()();
    for (const [id, { callback, deadline }] of [...timers]) {
      if (deadline <= now) { timers.delete(id); callback(); }
    }
  };
  return { document, window, button, status, cancel, calls, timers, intervals, initialize, runTimers,
    advance(seconds) { now += seconds * 1000; [...intervals.values()].forEach(callback => callback()); runTimers(); },
    async settle() { for (let tick = 0; tick < 8; tick++) await Promise.resolve(); },
    get instance() { return instance; }, get options() { return options; }, get loader() { return loader; } };
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
  assert.equal(p.timers.size, 0);
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

test('retry reopens an interaction that the user dismissed after a failed answer', () => {
  const p = page();
  p.runTimers();
  p.options.fail();
  p.instance.hide();
  p.options.onClose('userDismiss');
  assert.equal(p.instance.visible, false);

  p.button.click();

  assert.equal(p.instance.visible, true);
  assert.equal(p.calls.started, 2);
  assert.equal(p.calls.initialized, 1);
  assert.equal(p.calls.requests, 0);
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

test('activity verification waits for server permission before downloading a billable SDK', async () => {
  let complete, request;
  const permission = new Promise(resolve => { complete = resolve; });
  const p = page({ loaded: false, attemptPath: '/attempt.json', fetch(url, options) {
    request = { url, ...options };
    return permission;
  } });
  assert.equal(p.loader, undefined);
  assert.equal(p.calls.initialized, 0);
  assert.equal(request.url, '/attempt.json');
  assert.equal(request.method, 'POST');
  assert.equal(request.headers['X-CSRF-Token'], 'csrf-token');
  complete({ ok: true, json: async () => ({ allowed: true }) });
  await p.settle();
  assert.match(p.loader.src, /AliyunCaptcha\.js$/);
});

test('the first activity verification reuses its SDK initialization permission', async () => {
  const p = page({ attemptPath: '/attempt.json', fetch: async () => ({ ok: true, json: async () => ({ allowed: true }) }) });
  await p.settle();
  p.runTimers();
  assert.equal(p.calls.started, 1);
  assert.equal(p.calls.requests, 1);
});

test('activity retries need another server permission and never restart automatically', async () => {
  const p = page({ attemptPath: '/attempt.json', fetch: async () => ({ ok: true, json: async () => ({ allowed: true }) }) });
  await p.settle();
  p.runTimers();
  p.options.fail();
  await p.settle();
  assert.equal(p.calls.requests, 1);
  assert.equal(p.calls.started, 1);
  p.button.click();
  p.button.click();
  await p.settle();
  assert.equal(p.calls.requests, 2);
  assert.equal(p.calls.started, 2);
});

test('a cooldown displays seconds and prevents SDK calls until a manual retry', async () => {
  const p = page({ loaded: false, attemptPath: '/attempt.json', fetch: async () => ({
    ok: false, json: async () => ({ error: { message: 'Slow down' }, retry_after: 120 })
  }) });
  await p.settle();
  assert.equal(p.button.textContent, 'Wait 120s');
  assert.equal(p.button.disabled, true);
  p.button.click();
  assert.equal(p.calls.requests, 1);
  assert.equal(p.loader, undefined);
  p.advance(30);
  assert.equal(p.button.textContent, 'Wait 90s');
  p.advance(90);
  assert.equal(p.button.disabled, false);
  assert.equal(p.button.textContent, 'Try again');
  assert.equal(p.calls.requests, 1);
  assert.equal(p.intervals.size, 0);
});

test('an attempt network error leaves a manual retry without SDK initialization', async () => {
  const p = page({ attemptPath: '/attempt.json', fetch: async () => { throw new Error('offline'); } });
  await p.settle();
  assert.equal(p.status.textContent, 'Unavailable');
  assert.equal(p.button.disabled, false);
  assert.equal(p.calls.initialized, 0);
  assert.equal(p.calls.requests, 1);
});

test('a successful HTTP response without explicit attempt permission cannot start the SDK', async () => {
  const p = page({ attemptPath: '/attempt.json', fetch: async () => ({ ok: true, headers: { get: () => null }, json: async () => ({}) }) });
  await p.settle();
  assert.equal(p.calls.initialized, 0);
  assert.equal(p.button.disabled, false);
  assert.equal(p.status.textContent, 'Unavailable');
});

test('navigation clears cooldown timers and prevents late work', async () => {
  const p = page({ attemptPath: '/attempt.json', fetch: async () => ({ ok: false, json: async () => ({ retry_after: 120 }) }) });
  await p.settle();
  assert.equal(p.intervals.size, 1);
  p.document.dispatchEvent(new Event('turbo:before-render'));
  assert.equal(p.intervals.size, 0);
  assert.equal(p.button.onclick, null);
});

test('a late permission response cannot initialize an activity page after navigation', async () => {
  let complete, signal;
  const permission = new Promise(resolve => { complete = resolve; });
  const p = page({ attemptPath: '/attempt.json', fetch(_url, options) { signal = options.signal; return permission; } });
  p.document.dispatchEvent(new Event('turbo:before-cache'));
  complete({ ok: true, json: async () => ({ allowed: true }) });
  await p.settle();
  assert.equal(signal.aborted, true);
  assert.equal(p.calls.initialized, 0);
  assert.equal(p.loader, undefined);
});

test('a late throttling response cannot create a timer on a disposed activity page', async () => {
  let complete;
  const permission = new Promise(resolve => { complete = resolve; });
  const p = page({ attemptPath: '/attempt.json', fetch: () => permission });
  p.document.dispatchEvent(new Event('turbo:before-render'));
  complete({ ok: false, json: async () => ({ retry_after: 120 }) });
  await p.settle();
  assert.equal(p.intervals.size, 0);
});

test('activity cancellation reports once without blocking the return link', () => {
  const requests = [];
  const p = page({ eventPath: '/events.json', fetch(url, options) {
    requests.push({ url, ...options });
    return Promise.resolve({ ok: true });
  } });
  p.cancel.onclick({ preventDefault() { assert.fail('ordinary return must not be blocked'); } });
  p.cancel.onclick({});
  assert.equal(requests.length, 1);
  assert.equal(requests[0].keepalive, true);
  assert.equal(requests[0].headers['X-CSRF-Token'], 'csrf-token');
  assert.deepEqual(JSON.parse(requests[0].body), { captcha_event: { type: 'cancelled' } });
});

test('repeated SDK errors produce one observation and never an automatic retry', () => {
  const p = page({ eventPath: '/events.json', fetch: async () => ({ ok: true }) });
  p.runTimers();
  p.options.onError();
  p.options.onError();
  assert.equal(p.calls.requests, 1);
  assert.equal(p.calls.started, 1);
  assert.equal(p.button.textContent, 'Try again');
});

test('an active page reports expiry only after the server supplied lifetime', () => {
  const requests = [];
  const p = page({ eventPath: '/events.json', expiresIn: 600, fetch(url, options) {
    requests.push(JSON.parse(options.body));
    return Promise.resolve({ ok: true });
  } });
  p.advance(599);
  assert.equal(requests.length, 0);
  p.advance(2);
  p.advance(60);
  assert.deepEqual(requests, [{ captcha_event: { type: 'expired' } }]);
});

test('successful verification clears expiry observation before returning to the activity', async () => {
  const requests = [];
  const p = page({ eventPath: '/events.json', fetch(url) {
    requests.push(url);
    return Promise.resolve({ ok: true, json: async () => ({ redirect_url: '/activity' }) });
  } });
  p.runTimers();
  await p.options.success('proof');
  p.advance(700);
  assert.deepEqual(requests, ['/verify.json']);
  assert.deepEqual(p.calls.redirected, ['/activity']);
});

test('Turbo cleanup removes expiry observation without reporting an abandoned page as cancelled', () => {
  const p = page({ eventPath: '/events.json', fetch: async () => ({ ok: true }) });
  p.document.dispatchEvent(new Event('turbo:before-cache'));
  p.advance(700);
  p.cancel.onclick({});
  assert.equal(p.timers.size, 0);
  assert.equal(p.calls.requests, 0);
});

test('failed observation is ignored and does not change verification retry behavior', async () => {
  const p = page({ eventPath: '/events.json', fetch: async () => { throw new Error('offline'); } });
  p.runTimers();
  p.options.onError();
  await p.settle();
  assert.equal(p.calls.requests, 1);
  assert.equal(p.button.disabled, false);
  assert.equal(p.status.textContent, 'Unavailable');
});
