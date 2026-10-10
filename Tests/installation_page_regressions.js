const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

// Exercise the actual HTML emitted by the production Swift generator.
const html = fs.readFileSync(process.argv[2], 'utf8');
const href = html.match(/<a\b[^>]*id="install"[^>]*href="([^"]+)"/)[1]
  .replaceAll('&amp;', '&').replaceAll('&quot;', '"')
  .replaceAll('&lt;', '<').replaceAll('&gt;', '>');
const installer = new URL(href);
assert.equal(installer.protocol, 'itms-services:');
assert.equal(installer.searchParams.get('action'), 'download-manifest');
assert.equal(new URL(installer.searchParams.get('url')).protocol, 'https:');
assert.ok(html.includes('>Cài đặt</a>'));
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(match => match[1]);
assert.ok(scripts.length);

for (const blocked of [false, true]) {
  const listeners = [];
  const scheduled = [];
  const navigations = [];
  const location = {};
  Object.defineProperty(location, 'href', {
    set(value) {
      navigations.push(value);
      if (blocked) throw new Error('Safari blocked automatic navigation');
    }
  });
  const context = vm.createContext({
    document: { getElementById(id) { assert.equal(id, 'install'); return { href }; } },
    window: {
      location,
      addEventListener(event, callback, options) {
        assert.equal(event, 'load');
        assert.equal(options.once, true);
        listeners.push(callback);
      }
    },
    setTimeout(callback, delay) {
      assert.ok(delay > 0 && delay < 1000);
      scheduled.push(callback);
    }
  });
  for (const script of scripts) vm.runInContext(script, context, { timeout: 1000 });
  assert.equal(navigations.length, 0, 'Wait until the install page has loaded');
  assert.equal(listeners.length, 1, 'Register a single install attempt');
  listeners[0]();
  assert.equal(navigations.length, 0, 'Let Safari finish displaying the page first');
  assert.equal(scheduled.length, 1);
  assert.doesNotThrow(() => scheduled[0](), 'Blocked auto navigation must preserve the manual action');
  assert.deepEqual(navigations, [href], 'Navigate using the full decoded installer URL exactly once');
}
console.log('PASS: Safari page waits for load, opens the exact installer link, and retains manual install when navigation is blocked');
