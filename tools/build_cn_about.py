#!/usr/bin/env python3
"""Derive web/cn.html — the Simplified-only, sites-free About page — from web/about.html.

2026-09-24 「简体 放在/cn ... 去掉site而且只有简体」: `/about` stays exactly as
it is (three scripts, the 相关网站 list). `/cn` is the same page for readers
in mainland China: Simplified only, no language switch, and without the
list of church sites.

It is DERIVED, not a second copy, so the two cannot drift: edit
web/about.html, rerun this, commit both. `--check` exits 1 when web/cn.html
is not what this would write (for CI or a pre-push look).

What it changes, and nothing else:
  * unwraps every `data-l="hans"` span, drops every `hant` / `en` one;
  * drops the language switch (`<nav class="bar">`) and the three
    "Other platforms · GitHub" buttons;
  * drops the 相关网站 section: its leading comment, the heading, the
    `.sites` grid and the credits note under it;
  * points canonical / og:url at /cn, and the feedback form's `position`
    at '/cn' so a message says which page it was written on;
  * replaces the script with the same form handler minus the three-script
    machinery;
  * adds a 「下载 Mac 版」 button (/dl/<app>-mac) beside the APK one on the
    Words and Sword cards.
"""
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'web' / 'about.html'
DST = ROOT / 'web' / 'cn.html'

VOID = {'meta', 'link', 'img', 'br', 'hr', 'input', 'source', 'wbr'}


class Keep(HTMLParser):
    """Re-emit the document, unwrapping hans spans and skipping hant/en."""

    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.out = []
        self.stack = []      # per open element: 'keep' | 'unwrap' | 'skip'
        self.skip_depth = 0

    def _mode(self, tag, attrs):
        if tag == 'span':
            l = dict(attrs).get('data-l')
            if l == 'hans':
                return 'unwrap'
            if l in ('hant', 'en'):
                return 'skip'
        return 'keep'

    def handle_starttag(self, tag, attrs):
        if tag in VOID:
            if not self.skip_depth:
                self.out.append(self.get_starttag_text())
            return
        mode = self._mode(tag, attrs)
        self.stack.append(mode)
        if mode == 'skip':
            self.skip_depth += 1
        elif not self.skip_depth and mode == 'keep':
            self.out.append(self.get_starttag_text())

    def handle_startendtag(self, tag, attrs):
        if not self.skip_depth:
            self.out.append(self.get_starttag_text())

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        mode = self.stack.pop()
        if mode == 'skip':
            self.skip_depth -= 1
        elif not self.skip_depth and mode == 'keep':
            self.out.append('</%s>' % tag)

    def _emit(self, s):
        if not self.skip_depth:
            self.out.append(s)

    def handle_data(self, d):
        self._emit(d)

    def handle_entityref(self, n):
        self._emit('&%s;' % n)

    def handle_charref(self, n):
        self._emit('&#%s;' % n)

    def handle_comment(self, c):
        self._emit('<!--%s-->' % c)

    def handle_decl(self, d):
        self._emit('<!%s>' % d)


CN_SCRIPT = """<script>
(function () {
  // Simplified only: there is no language to choose on this page, so none
  // of about.html's three-script machinery is here.
  var MSG = {
    sending: '发送中…',
    ok: '收到了，谢谢。我们会尽快回信。',
    need: '名字、邮箱和内容都要填。',
    addr: '邮箱地址看起来不对。',
    fail: '没能送出去 —— 你写的内容已经放进下面那个邮件链接里了，点一下直接寄给我们。'
  };

  var form = document.getElementById('cform');
  var note = document.getElementById('cnote');
  var cmail = document.getElementById('cmail');
  // Same shape the function validates with (submitFeedback.mjs).
  var EMAIL_RE = /^[^\\s@<>]+@[^\\s@<>]+\\.[a-zA-Z]{2,}$/;

  function say(key, cls) {
    note.textContent = MSG[key];
    note.className = 'note' + (cls ? ' ' + cls : '');
  }

  if (form) form.addEventListener('submit', function (e) {
    e.preventDefault();
    var f = form.elements;
    var name = f['name'].value.trim();
    var email = f['replyTo'].value.trim();
    var message = f['message'].value.trim();
    if (!name || !email || !message) { say('need', 'bad'); return; }
    if (!EMAIL_RE.test(email)) { say('addr', 'bad'); f['replyTo'].focus(); return; }

    var btn = form.querySelector('button.send');
    btn.disabled = true;
    say('sending');

    fetch('/api/submitFeedback', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        category: 'About page (CN)',
        name: name,
        replyTo: email,
        message: message,
        position: '/cn',
        locale: 'hans',
        browserLocale: navigator.language || '',
        userAgent: navigator.userAgent || '',
        theme: window.matchMedia &&
          window.matchMedia('(prefers-color-scheme: dark)').matches
          ? 'dark' : 'light'
      })
    }).then(function (r) {
      if (!r.ok) throw new Error('http ' + r.status);
      form.reset();
      say('ok', 'good');
    }).catch(function () {
      cmail.href = 'mailto:support@yahwehword.com' +
        '?subject=' + encodeURIComponent('yahwehword.com — ' + name) +
        '&body=' + encodeURIComponent(
          message + '\\n\\n— ' + name + ' <' + email + '>');
      say('fail', 'bad');
    }).then(function () { btn.disabled = false; });
  });
})();
</script>"""


def build(src: str) -> str:
    # 1. the sites section: leading comment .. up to the Contact heading.
    a = src.index('<!-- 2026-09-17 「Also other links and references')
    b = src.index('<h2><span data-l="hans">联系我们')
    src = src[:a] + src[b:]

    # 2. the language switch.
    src, n = re.subn(r'\s*<nav class="bar">.*?</nav>', '', src, count=1, flags=re.S)
    assert n == 1, 'language switch not found'

    # 2b. the GitHub buttons: GitHub is unreliable from the mainland, and
    #     the Download button beside them already serves the APK.
    src, n = re.subn(r'\n?[ \t]*<a class="gh"[^>]*>.*?</a>', '', src, flags=re.S)
    assert n == 3, 'expected three GitHub buttons, found %d' % n

    # 3. the script is replaced wholesale (it is the one place text is
    #    written by JS rather than shipped as spans).
    src, n = re.subn(r'<script>.*?</script>', lambda m: CN_SCRIPT, src,
                     count=1, flags=re.S)
    assert n == 1, 'script not found'

    # 4. unwrap hans / drop hant+en.
    p = Keep()
    p.feed(src)
    p.close()
    out = ''.join(p.out)
    out = out.replace(
        '<!DOCTYPE html>\n',
        '<!DOCTYPE html>\n<!-- GENERATED by tools/build_cn_about.py from web/about.html '
        '-- edit that, not this. Simplified only, no sites list. Comments below '
        'are about.html\'s and describe it, not this page. -->\n', 1)

    # 4b. macOS package. The mainland page has no GitHub buttons, so this
    #     is the only way to a Mac build from here. /dl/<app>-mac resolves to
    #     the newest release's macOS zip (netlify/functions/latestApk.mjs),
    #     so it stays current without editing this page. The .app is ad-hoc
    #     signed, not notarised, hence the one-line first-open hint.
    def add_mac(m):
        slug = m.group(1)
        return (m.group(0) + '\n        <a class="dl" href="/dl/%s-mac">下载 Mac 版</a>' % slug)
    out, n = re.subn(r'<a class="dl" href="/dl/(words|sword)">下载 APK</a>',
                     add_mac, out)
    assert n == 2, 'expected two APK buttons, found %d' % n
    out, n = re.subn(
        r'(<a class="dl" href="/dl/(?:words|sword)-mac">下载 Mac 版</a>\s*</div>)',
        r'\1\n      <p class="host">Mac 版首次打开：在“访达”里右键点应用 → 打开。</p>', out)
    assert n == 2, 'mac hint anchor not found'

    # 5. head: one URL, one language.
    out = out.replace('https://yahwehword.com/about', 'https://yahwehword.com/cn')
    out = out.replace(' Three free Bible tools — read, study, see.', '')
    out = out.replace('三个免费的圣经工具：读、查、看。Three free Bible tools.',
                      '三个免费的圣经工具：读、查、看。')
    return out


def main() -> int:
    out = build(SRC.read_text(encoding='utf-8'))
    if '--check' in sys.argv:
        cur = DST.read_text(encoding='utf-8') if DST.exists() else None
        if cur != out:
            print('web/cn.html is stale: rerun tools/build_cn_about.py')
            return 1
        return 0
    DST.write_text(out, encoding='utf-8')
    print('wrote', DST.relative_to(ROOT), len(out), 'bytes')
    return 0


if __name__ == '__main__':
    sys.exit(main())
