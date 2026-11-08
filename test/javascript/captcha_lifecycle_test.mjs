import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const template = readFileSync(new URL('../../app/views/aliyun_proxy/captcha/_verification.html.erb', import.meta.url), 'utf8');
const rendered = template.replace(/<%=[\s\S]*?%>/g, expression => {
  if (expression.includes('@client_options')) return JSON.stringify({ SceneId: 'scene' });
  if (expression.includes('@prefix')) return JSON.stringify('prefix');
  if (expression.includes('captcha_verification_path')) return JSON.stringify('/verify.json');
  return JSON.stringify({ continue: 'Continue', checking: 'Checking', failed: 'Failed', unavailable: 'Unavailable' });
});

const source = rendered.match(/<script\b[^>]*>([\s\S]*?)<\/script>/)[1];

function page({ loaded = true, fetch } = {}) {
  const document = new EventTarget();
  const button = { disabled: true, textContent: 'Loading', isConnected: true };
  const status = { textContent: '' };
  const timers = new Map();
  const calls = { initialized: 0, hidden: 0, requests: 0, redirected: [] };
  let options, loader, nextTimer = 0;
  document.getElementById = id => id === 'captcha-button' ? button : status;
  document.querySelector = () => ({ content: 'csrf-token' });
  document.createElement = () => ({ remove() { calls.loaderRemoved = true; } });
  document.head = { appendChild(script) { loader = script; } };
  const window = {
    setTimeout(callback) { timers.set(++nextTimer, callback); return nextTimer; },
    clearTimeout(id) { timers.delete(id); },
    location: { replace(url) { calls.redirected.push(url); } }
  };
  const initialize = config => {
    calls.initialized++;
    options = config;
    config.getInstance({ hide() { calls.hidden++; } });
  };
  if (loaded) window.initAliyunCaptcha = initialize;
  runInNewContext(source, {
    window, document, AbortController,
    fetch(...args) { calls.requests++; return fetch(...args); }
  });
  return { document, window, button, status, calls, timers, initialize,
    get options() { return options; }, get loader() { return loader; } };
}

test('a Turbo-rendered page initializes with the already loaded SDK', () => {
  const p = page();
  for (const callback of p.timers.values()) callback();
  assert.equal(p.calls.initialized, 1);
  assert.equal(p.loader, undefined);
  assert.equal(p.button.disabled, false);
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
});

test('navigation aborts a pending request and its late result cannot redirect', async () => {
  let resolve;
  const response = new Promise(done => { resolve = done; });
  let signal;
  const p = page({ fetch(_url, options) { signal = options.signal; return response; } });
  const verifying = p.options.success('not-a-real-ticket');
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
