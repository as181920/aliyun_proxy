import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const source = readFileSync(new URL('../../app/assets/javascripts/aliyun_proxy/login_verification.js', import.meta.url), 'utf8');
const flush = () => new Promise(setImmediate);

function page(fetch) {
  const document = new EventTarget(), window = new EventTarget();
  window.location = { origin: 'https://example.com', href: 'https://example.com/login' };
  const status = {}, frame = { contentWindow: {} }, cancel = {};
  const dialog = { dataset: { locale: 'zh-CN', error: '验证服务暂不可用' },
    showModal() { this.open = true; }, close() { this.open = false; },
    querySelector: (selector) => selector === 'iframe' ? frame : selector === 'button' ? cancel : status };
  const fields = new Map([['session[name]', { value: 'account' }], ['session[password]', { value: 'secret' }], ['session[verification_code]', { value: '123456' }]]);
  const form = { id: 'session-form-by-password', action: '/sessions', submissions: 0,
    querySelector: (selector) => fields.get(selector.match(/name="([^"]+)"/)[1]),
    appendChild(input) { fields.set(input.name, input); },
    requestSubmit() { this.submissions++; submit(); } };
  document.querySelector = (selector) => selector === '[data-login-captcha]' ? dialog : { content: 'csrf' };
  document.querySelectorAll = () => [fields.get('session[password]'), fields.get('session[verification_code]')];
  document.createElement = () => ({});
  const requests = [];
  runInNewContext(source, { document, window, URL, AbortController, WeakSet,
    FormData: class extends Map {
      constructor() { super([...fields].map(([key, input]) => [key, input.value])); }
    },
    fetch(url, options) { requests.push(options); return fetch(url, options); }
  });
  function submit() {
    const event = new Event('submit', { cancelable: true });
    Object.defineProperty(event, 'target', { value: form });
    document.dispatchEvent(event);
  }
  function message(origin = window.location.origin, source = frame.contentWindow) {
    const event = new Event('message');
    Object.defineProperties(event, { origin: { value: origin }, source: { value: source }, data: { value: { type: 'aliyun_proxy:captcha_verified', challenge: 'proof' } } });
    window.dispatchEvent(event);
  }
  return { document, form, fields, status, requests, dialog, submit, message };
}

const challenge = async () => ({ json: async () => ({ error: { code: 'captcha.required' }, challenge_id: 'proof', challenge_url: 'https://example.com/challenge' }) });

test('native preflight omits credentials and preserves the selected page locale', async () => {
  const p = page(challenge);
  p.submit(); await flush();
  assert.equal(p.requests[0].body.has('session[password]'), false);
  assert.equal(p.requests[0].body.has('session[verification_code]'), false);
  assert.equal(p.requests[0].body.get('locale'), 'zh-CN');
  assert.equal(p.fields.get('session[password]').value, 'secret');
});

test('only the matching iframe can resume the original form with proof and locale', async () => {
  const p = page(challenge);
  p.submit(); await flush();
  p.message('https://evil.example'); p.message('https://example.com', {});
  assert.equal(p.form.submissions, 0);
  p.message();
  assert.equal(p.form.submissions, 1);
  assert.equal(p.fields.get('captcha_challenge').value, 'proof');
  assert.equal(p.fields.get('locale').value, 'zh-CN');
  assert.equal(p.requests.length, 1);
});

test('network errors show the localized fallback instead of browser English', async () => {
  const p = page(async () => { throw new Error('Failed to fetch'); });
  p.submit(); await flush();
  assert.equal(p.status.textContent, '验证服务暂不可用');
  assert.equal(p.form.submissions, 0);
});

test('Turbo caching clears credentials and disables late completion messages', async () => {
  const p = page(challenge);
  p.submit(); await flush();
  p.document.dispatchEvent(new Event('turbo:before-cache'));
  p.message();
  assert.equal(p.fields.get('session[password]').value, '');
  assert.equal(p.fields.get('session[verification_code]').value, '');
  assert.equal(p.form.submissions, 0);
  assert.equal(p.requests[0].signal.aborted, true);
});
