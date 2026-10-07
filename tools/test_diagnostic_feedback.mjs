import assert from 'node:assert/strict';
import {pathToFileURL,fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('..',import.meta.url));
const expectedApp='words';
let count=0;
{
 const {sanitizeDiagnostics} = await import(pathToFileURL(root+'/netlify/functions/_diagnostics.mjs'));
 const handler = (await import(pathToFileURL(root+'/netlify/functions/submitFeedback.mjs'))).default;
 const id = 'YD-'+'a'.repeat(32);
 const d = sanitizeDiagnostics({diagnosisId:id,appVersion:'1.7.14',platform:'ios',channel:'app_store',apiKey:'never',events:Array.from({length:100},()=>({kind:'audio',result:'paused',at:'2026-10-07T05:00:00.000Z',secret:'never'}))});
 assert.equal(d.diagnosisId,id); assert.equal(d.events.length,20); assert(!JSON.stringify(d).includes('never')); count++;
 assert.deepEqual(sanitizeDiagnostics({diagnosisId:'<script>',events:[{kind:'audio',result:'my private note'}]}),{events:[]}); count++;
 const oldFetch = globalThis.fetch; const oldKey = process.env.RESEND_API_KEY; delete process.env.RESEND_API_KEY;
 let written;
 globalThis.fetch = async (url, opts) => {written = JSON.parse(opts.body); return new Response('{}',{status:200});};
 try {
  const response = await handler(new Request('https://example.com/api/submitFeedback',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({message:'Diagnostic test (mock only)',diagnostics:{diagnosisId:id,app:'spoof',appVersion:'1.7.14'}})}));
  assert.equal(response.status,200); assert.equal(written.app,expectedApp); assert.equal(written.diagnostics.app,written.app); assert.equal(written.diagnostics.diagnosisId,id); count++;
  assert.equal((await handler(new Request('https://example.com/api/submitFeedback',{method:'POST',body:JSON.stringify({message:'a'.repeat(4001)})}))).status,400);count++;
  for (const value of [null,[],42]) {assert.equal((await handler(new Request('https://example.com/api/submitFeedback',{method:'POST',body:JSON.stringify(value)}))).status,400);count++;}
  globalThis.fetch = async () => {throw Error('offline');};
  assert.equal((await handler(new Request('https://example.com/api/submitFeedback',{method:'POST',body:JSON.stringify({message:'test'})}))).status,503);count++;
 } finally {globalThis.fetch=oldFetch;if(oldKey!==undefined)process.env.RESEND_API_KEY=oldKey;}
}
console.log(JSON.stringify({passed:count,network:'mocked; no real reports sent'}));
