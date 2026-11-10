import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const layout = readFileSync(new URL('../../app/views/layouts/aliyun_proxy/captcha.html.erb', import.meta.url), 'utf8').replace(/<%[\s\S]*?%>/g, '');
const source = layout.match(/<script\b[^>]*>([\s\S]*?)<\/script>/)[1];

test('embedded verification leaves cancellation to the parent dialog', () => {
  let removed = 0;
  runInNewContext(source, { window: { parent: {} }, document: { querySelectorAll: () => [{ remove() { removed++; } }] } });
  assert.equal(removed, 1);
});

test('standalone verification preserves its return action', () => {
  const window = {};
  window.parent = window;
  runInNewContext(source, { window, document: { querySelectorAll() { assert.fail('standalone return action must remain'); } } });
});
