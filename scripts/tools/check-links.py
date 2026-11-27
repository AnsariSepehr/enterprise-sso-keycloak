#!/usr/bin/env python3
"""Check that every relative link and #anchor in the Markdown files points at something real.

External (http, https, mailto) links are not fetched. Links inside code blocks and inline code are ignored.
Anchors follow GitHub's rules (lower case, punctuation dropped, spaces to dashes, duplicates numbered).
Exit code 1 if any link is broken. Run in CI and before every commit.
"""
import os
import re
import sys
from urllib.parse import unquote

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LINK = re.compile(r"!?\[(?:[^\]\\]|\\.)*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


def md_files():
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules")]
        for f in files:
            if f.endswith(".md"):
                yield os.path.join(base, f)


def strip_code(text):
    text = re.sub(r"^(```|~~~).*?^\1[ \t]*$", "", text, flags=re.S | re.M)
    return re.sub(r"`[^`\n]*`", "", text)


def slug(heading):
    h = re.sub(r"<[^>]+>", "", heading)
    h = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", h)
    h = h.replace("`", "").strip().lower()
    h = re.sub(r"[^\w\- ]", "", h, flags=re.U)
    return h.replace(" ", "-")


_anchor_cache = {}


def anchors(path):
    if path in _anchor_cache:
        return _anchor_cache[path]
    seen, result = {}, set()
    text = re.sub(r"^(```|~~~).*?^\1[ \t]*$", "", open(path, encoding="utf-8").read(), flags=re.S | re.M)
    for line in text.splitlines():
        m = HEADING.match(line)
        if not m:
            continue
        s = slug(m.group(2))
        n = seen.get(s, 0)
        seen[s] = n + 1
        result.add(s if n == 0 else f"{s}-{n}")
    _anchor_cache[path] = result
    return result


def main():
    bad = 0
    count = 0
    for md in sorted(md_files()):
        text = strip_code(open(md, encoding="utf-8").read())
        for m in LINK.finditer(text):
            target = m.group(1)
            if re.match(r"^(https?:|mailto:|tel:)", target):
                continue
            count += 1
            path, _, frag = target.partition("#")
            dest = md if not path else os.path.normpath(os.path.join(os.path.dirname(md), unquote(path)))
            rel = os.path.relpath(md, ROOT)
            if not os.path.exists(dest):
                print(f"{rel}: missing file  {target}")
                bad += 1
                continue
            if frag and dest.endswith(".md") and unquote(frag).lower() not in anchors(dest):
                print(f"{rel}: missing anchor  {target}")
                bad += 1
    print(f"check-links: {count} relative links checked, {bad} broken")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
