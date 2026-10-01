import { initializeApp } from 'https://www.gstatic.com/firebasejs/12.12.0/firebase-app.js';
import { getAuth, GoogleAuthProvider, browserSessionPersistence, setPersistence, getRedirectResult, signInWithRedirect, signOut } from 'https://www.gstatic.com/firebasejs/12.12.0/firebase-auth.js';
import { firebaseConfig } from './desktop-google-config.js';

const translations = {
  en: {title:'Sign in with Google',intro:'Continue securely in your browser, then return to the Windows app.',ready:'Ready to continue with your Google account.',continue:'Continue with Google',cancel:'Cancel',privacy:'This uses your Google account name and email to sign in and sync your own data. No Google Drive access is requested.',invalid:'This request is invalid or has expired. Start Google sign-in again from Yahweh’s Words on Windows.',return:'Returning your sign-in response to the app…',failed:'Sign-in could not be completed. Please try again from the app.',checking:'Checking your sign-in request…'},
  'zh-Hans':{title:'通过 Google 登录',intro:'在浏览器中安全登录，然后返回 Windows 应用。',ready:'可以继续使用你的 Google 账号登录。',continue:'继续使用 Google',cancel:'取消',privacy:'使用 Google 账号名称和邮箱登录并同步你自己的数据，不请求 Google 云端硬盘权限。',invalid:'登录请求无效或已过期，请在 Windows 雅伟之言中重新发起 Google 登录。',return:'正在将登录结果返回应用…',failed:'暂时无法完成登录，请从应用重新尝试。',checking:'正在检查登录请求…'},
  'zh-Hant':{title:'透過 Google 登入',intro:'在瀏覽器中安全登入，然後返回 Windows 應用。',ready:'可以繼續使用你的 Google 帳號登入。',continue:'繼續使用 Google',cancel:'取消',privacy:'使用 Google 帳號名稱和信箱登入並同步你自己的資料，不請求 Google 雲端硬碟權限。',invalid:'登入請求無效或已過期，請在 Windows 雅偉之言中重新發起 Google 登入。',return:'正在將登入結果返回應用…',failed:'暫時無法完成登入，請從應用重新嘗試。',checking:'正在檢查登入請求…'}
};
const params = new URLSearchParams(location.search);
let lang = params.get('lang') in translations ? params.get('lang') : 'en';
let statusKey = 'checking';
const text = () => {
  document.documentElement.lang = lang;
  for (const id of ['title','intro','continue','cancel','privacy']) document.getElementById(id).textContent = translations[lang][id];
  document.getElementById('status').textContent = translations[lang][statusKey];
};
const status = key => { statusKey = key; text(); };
const language = document.getElementById('language'); language.value = lang;
language.addEventListener('change',()=>{lang=language.value;text();}); text();

const port = Number(params.get('port'));
const state = params.get('state') || '';
const allowedHosts = new Set(['yahwehword.com','yswords.netlify.app','yswords-dev.netlify.app','yswords-qat.netlify.app']);
const valid = location.protocol === 'https:' && allowedHosts.has(location.hostname) &&
  /^\d{4,5}$/.test(params.get('port') || '') && Number.isInteger(port) && port >= 1024 && port <= 65535 && /^[A-Za-z0-9_-]{43}$/.test(state);
const storageKey = 'yswords.desktopGoogle.started';
let auth;

// A top-level form submits only to the fixed loopback address. No tokens in
// URLs, analytics, browser logs, localStorage or application server requests.
async function returnToApp(fields) {
  document.getElementById('continue').disabled = true;
  document.getElementById('cancel').disabled = true;
  status('return');
  if (auth) await signOut(auth);
  sessionStorage.removeItem(storageKey);
  const form = document.createElement('form');
  form.method = 'POST'; form.action = `http://127.0.0.1:${port}/google-sign-in`;
  for (const [name,value] of Object.entries({state,...fields})) {
    const input = document.createElement('input'); input.type = 'hidden'; input.name = name; input.value = value; form.append(input);
  }
  document.body.append(form); form.submit();
}

if (!valid) {
  status('invalid');
} else {
  try {
    // A named app and session-only persistence leave the main website account
    // untouched. Use same-origin /__/auth proxy to avoid third-party storage.
    auth = getAuth(initializeApp({...firebaseConfig,authDomain:location.hostname}, 'yswords-desktop-google'));
    await setPersistence(auth, browserSessionPersistence);
    const result = await getRedirectResult(auth);
    if (result) {
      const started = JSON.parse(sessionStorage.getItem(storageKey) || 'null');
      if (!started || started.state !== state || started.port !== port || Date.now()-started.time > 300000) throw new Error('Expired request');
      const credential = GoogleAuthProvider.credentialFromResult(result);
      if (!credential?.idToken && !credential?.accessToken) throw new Error('Missing credential');
      await returnToApp({...(credential.idToken ? {idToken:credential.idToken} : {}),...(credential.accessToken ? {accessToken:credential.accessToken} : {})});
    } else {
      status('ready');
      document.getElementById('continue').disabled = false;
      document.getElementById('cancel').disabled = false;
    }
    document.getElementById('continue').addEventListener('click',async()=>{
      document.getElementById('continue').disabled = true;
      try {
        sessionStorage.setItem(storageKey,JSON.stringify({state,port,time:Date.now()}));
        const provider = new GoogleAuthProvider(); provider.addScope('email'); provider.addScope('profile');
        provider.setCustomParameters({prompt:'select_account'});
        await signInWithRedirect(auth, provider);
      } catch (_) {status('failed');document.getElementById('continue').disabled=false;}
    });
    document.getElementById('cancel').addEventListener('click',()=>returnToApp({error:'cancelled'}).catch(()=>status('failed')));
  } catch (error) {
    // A fixed, non-identifying reason helps diagnose the browser handoff.
    // Never log the SDK error object, user or credential.
    const reason = error?.message === 'Expired request' ? 'expired-request' :
      error?.message === 'Missing credential' ? 'missing-google-credential' :
      ['auth/unauthorized-domain','auth/operation-not-allowed','auth/network-request-failed'].includes(error?.code) ? error.code : 'browser-sign-in-failed';
    console.error('Desktop Google sign-in:', reason);
    status(reason === 'expired-request' ? 'invalid' : 'failed');
  }
}
