#!/usr/bin/env python3
"""Render the two store privacy policies (Markdown, one per app) to
web/privacy-sword.html and web/privacy-words.html.

The Markdown is the source of truth and lives in docs/privacy/. Each file
has a title line, then `## English` and `## 中文` sections whose
paragraphs are `**Heading.** text`. Output is one self-contained file with
no webfont (fonts.gstatic.com is unreachable from mainland China), like
web/about.html.
"""
import html, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
APPS = {
    "sword": ("Yahweh's Sword 雅伟之剑", "privacy-sword"),
    "words": ("Yahweh's Words 雅伟的话", "privacy-words"),
}

def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    return re.sub(r"(support@yahwehword\.com)", r'<a href="mailto:\1">\1</a>', s)

def render(md, app):
    name, slug = APPS[app]
    lines = md.strip().splitlines()
    meta = next(l for l in lines if l.startswith("Last updated"))
    body, cur = [], None
    for l in lines[1:]:
        if l.startswith("## "):
            if cur: body.append("</section>")
            cur = "en" if l[3:].strip() == "English" else "zh"
            body.append(f'<section id="{cur}" lang="{"en" if cur=="en" else "zh-Hans"}">')
            body.append(f'<h2>{"English" if cur=="en" else "中文"}</h2>')
        elif l.strip() and l is not meta and cur:
            body.append(f"<p>{inline(l)}</p>")
    body.append("</section>")
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Privacy Policy · {html.escape(name)}</title>
<meta name="robots" content="index,follow">
<link rel="canonical" href="https://yahwehword.com/privacy/{app}">
<link rel="icon" href="/favicon.png">
<style>
:root{{--bg:#f7f9ff;--fg:#181c20;--muted:#5b6670;--accent:#27638a;--rule:#d9e2ec}}
@media(prefers-color-scheme:dark){{:root{{--bg:#101417;--fg:#e0e3e8;--muted:#9aa5b1;--accent:#96cdf8;--rule:#2a3138}}}}
body{{margin:0;background:var(--bg);color:var(--fg);font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif}}
main{{max-width:44rem;margin:0 auto;padding:2rem 1rem 4rem}}
h1{{font-size:1.6rem;line-height:1.25;margin:0 0 .25rem}}
h2{{font-size:1.15rem;margin:0 0 .5rem;color:var(--accent)}}
.meta,nav{{color:var(--muted);font-size:.9rem}}
nav{{margin:.5rem 0 1.5rem}}
section{{border-top:1px solid var(--rule);padding-top:1.25rem;margin-top:1.5rem}}
a{{color:var(--accent)}}
</style>
</head>
<body>
<main>
<h1>Privacy Policy · 隐私政策<br>{html.escape(name)}</h1>
<div class="meta">{html.escape(meta)}</div>
<nav><a href="#en">English</a> · <a href="#zh">中文</a></nav>
{chr(10).join(body)}
</main>
</body>
</html>
"""

def main():
    check = "--check" in sys.argv
    stale = False
    for app, (_, slug) in APPS.items():
        src = ROOT / "docs" / "privacy" / f"{slug}.md"
        out = ROOT / "web" / f"{slug}.html"
        want = render(src.read_text(), app)
        if check:
            if not out.exists() or out.read_text() != want:
                print(f"STALE {out}"); stale = True
        else:
            out.write_text(want); print("wrote", out)
    sys.exit(1 if stale else 0)

main()
