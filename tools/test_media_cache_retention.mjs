import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';

const handlers = {};
const deleted = [];
const names = ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest',
  'song-media-v1', 'sermon-media-v1', 'seeksparks-shell-v3', 'unrelated-user-cache'];
runInNewContext(readFileSync('web/flutter_service_worker.js', 'utf8'), {
  self: {
    addEventListener: (name, callback) => { handlers[name] = callback; },
    clients: { claim: async () => {}, matchAll: async () => [] },
    registration: { unregister: async () => {} },
    skipWaiting: () => {},
  },
  caches: { keys: async () => names,
    delete: async (name) => { deleted.push(name); return true; } },
});
let completion;
handlers.activate({ waitUntil: (promise) => { completion = promise; } });
await completion;
assert.deepEqual(deleted.sort(), names.slice(0,3).sort());
const html = readFileSync('web/index.html','utf8');
// Also parse each inline script; malformed update cleanup must not break boot.
for (const match of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
  if (!match[2].trim()) continue;
  if (match[1].includes('application/ld+json')) JSON.parse(match[2]);
  else new Function(match[2]);
}
assert(!html.includes('keys.map(function(k)'));
console.log('Legacy worker removes only Flutter caches; media/unknown caches retained; inline JS parses.');
