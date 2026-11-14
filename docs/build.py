"""Builds the per-site descriptions from docs/description.md. Run from the repo root: python docs/build.py"""
import re

src = open("docs/description.md", encoding="utf-8").read().split("\n")
title, tagline, body = src[0][2:], src[2], "\n".join(src[3:]).strip()

def inline(t, bold, code, link):
    t = re.sub(r"\*\*(.+?)\*\*", lambda m: bold(m.group(1)), t)
    t = re.sub(r"`(.+?)`", lambda m: code(m.group(1)), t)
    return re.sub(r"\[(.+?)\]\((.+?)\)", lambda m: link(m.group(1), m.group(2)), t)

def render(h2, ul, p, bold, code, link):
    out, items = [], []
    def flush():
        if items: out.append(ul(items)); items.clear()
    for line in body.split("\n"):
        if line.startswith("- "): items.append(inline(line[2:], bold, code, link)); continue
        flush()
        if line.startswith("## "): out.append(h2(line[3:]))
        elif line.strip(): out.append(p(inline(line, bold, code, link)))
    flush()
    return out

html = render(lambda t: f"<h2>{t}</h2>", lambda i: "<ul>" + "".join(f"<li>{x}</li>" for x in i) + "</ul>",
              lambda t: f"<p>{t}</p>", lambda t: f"<strong>{t}</strong>", lambda t: f"<code>{t}</code>",
              lambda t, u: f'<a href="{u}">{t}</a>')
bb = render(lambda t: f"[size=5][b]{t}[/b][/size]", lambda i: "[list]\n" + "\n".join(f"[*]{x}" for x in i) + "\n[/list]",
            lambda t: t, lambda t: f"[b]{t}[/b]", lambda t: f"[b]{t}[/b]", lambda t, u: f"[url={u}]{t}[/url]")

open("docs/out/curseforge.html", "w", encoding="utf-8").write(f"<p>{tagline}</p>\n" + "\n".join(html) + "\n")
open("docs/out/wowinterface.bbcode", "w", encoding="utf-8").write(f"{tagline}\n\n" + "\n\n".join(bb) + "\n")
open("docs/out/wago.md", "w", encoding="utf-8").write(f"{tagline}\n\n{body}\n")
open("README.md", "w", encoding="utf-8").write(
    f"# {title}\n\n![Bruh Forever](assets/banner.png)\n\n{tagline}\n\n{body}\n\n"
    "## Install\n\nDownload from [CurseForge](https://www.curseforge.com/wow/addons/bruh-forever), "
    "[WoWInterface](https://www.wowinterface.com/downloads/info27302-BruhForever.html) or "
    "[Wago](https://addons.wago.io/addons/j6jAZONR), or grab the zip from the [latest GitHub release](../../releases/latest).\n\n"
    "## Contributing\n\nFork, branch, open a pull request against `main`. All changes go through a PR. "
    "Tests run with `lua tests/run.lua`.\n\n## License\n\nMIT, see [LICENSE](LICENSE).\n")
