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
    const path = new URL(request.url).pathname;
    const response = new Response(path.endsWith('FontManifest.json') ? JSON.stringify([{fonts:[{asset:'fonts/test.otf'}]}]) : path, { status: 200 });
    Object.defineProperty(response, 'type', {value:'basic'});return response;
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
for (const file of ['main.dart.js', 'flutter_bootstrap.js', 'version.json', 'assets/AssetManifest.bin.json', 'canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm', 'assets/FontManifest.json', 'assets/fonts/test.otf']) {
  assert.ok(shell.has('https://app.test/' + file), 'boot file must be cached: ' + file);
}
const writes=[];
await sandbox.networkFirst(new Request('https://app.test/assets/loaded.json'), false, {waitUntil: p=>writes.push(p)});
assert.equal(writes.length,1,'runtime cache writes must extend the fetch lifetime');
await Promise.all(writes);
assert.ok(shell.has('https://app.test/assets/loaded.json'));
offline = true;
const response = await sandbox.networkFirst(new Request('https://app.test/main.dart.js'), false);
assert.equal(await response.text(), '/main.dart.js');
console.log('Offline app shell: claim order, boot files, renderer and fonts, media retention and offline main fallback passed');
