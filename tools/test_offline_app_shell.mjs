import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const handlers = new Map(), buckets = new Map();
let claimed = false, offline = false;
const downloaded = new Map([['recording', new Response('saved audio')]]);
buckets.set('sermon-media-v1', downloaded);
const sandbox = {
  URL, Request, Promise,
  self: { location: { href: 'https://app.test/app_shell_sw.js?v=test', origin: 'https://app.test' },
    addEventListener: (type, handler) => handlers.set(type, handler),
    clients: { claim: async () => { claimed = true; } }, skipWaiting: async () => {} },
  caches: { keys: async () => [...buckets.keys()], delete: async name => buckets.delete(name),
    open: async name => {
      if (!buckets.has(name)) buckets.set(name, new Map());
      const entries = buckets.get(name);
      return { put: async (key, response) => entries.set(typeof key === 'string' ? key : key.url, response),
        match: async key => entries.get(typeof key === 'string' ? key : key.url), add: async () => {} };
    } },
  fetch: async request => {
    assert.equal(claimed, true, 'clients must be claimed before boot-file warming');
    if (offline) throw new Error('network disconnected');
    return new Response(new URL(request.url).pathname, { status: 200 });
  },
};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync('web/app_shell_sw.js', 'utf8'), sandbox);
let activation;
handlers.get('activate')({ waitUntil: promise => { activation = promise; } });
await activation;
assert.equal(buckets.get('sermon-media-v1'), downloaded);
const shell = [...buckets.entries()].find(([name]) => name.endsWith('-test'))?.[1];
assert.ok(shell);
for (const file of ['main.dart.js', 'flutter_bootstrap.js', 'version.json']) {
  assert.ok(shell.has('https://app.test/' + file), 'boot file must be cached: ' + file);
}
offline = true;
const response = await sandbox.networkFirst(new Request('https://app.test/main.dart.js'), false);
assert.equal(await response.text(), '/main.dart.js');
console.log('Offline app shell: claim order, three boot files, media retention and offline main fallback passed');
