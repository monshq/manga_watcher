#!/usr/bin/env python3
"""Print a compact outline of a manga page to pick CSS selectors from.

Usage: outline.py page.html

Only python stdlib is used. The output lists candidates, it doesn't decide:
selectors must always be checked with the app's /api/agent/test endpoint.
"""

import re
import sys
from collections import defaultdict
from html.parser import HTMLParser

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta",
        "source", "track", "wbr"}
SKIP = {"script", "style", "noscript", "template", "svg"}
# same rules as MangaWatcher.Manga.PageParser.extract_chapter
HREF_CHAPTER = re.compile(r"chapter[-/](\d+)")
TEXT_CHAPTER = re.compile(r"chapter\s+(\d+)", re.I)
# classes like "css-1x2y3z" or "sc-AbCdE" are generated and change on redeploys
GENERATED = re.compile(r"^(css|sc|jsx|svelte|tw)-|[0-9a-f]{6,}|^[a-zA-Z]{1,3}\d[\w-]*$")
# classes like "sm:col-span-9" or "text-[12px]" need escaping in selectors, skip them
PLAIN = re.compile(r"^[A-Za-z_][\w-]*$")


class Node:
    def __init__(self, tag, attrs, parent):
        self.tag = tag
        self.attrs = dict(attrs)
        self.parent = parent
        self.children = []
        self.text = []

    def classes(self):
        classes = (self.attrs.get("class") or "").split()
        return [c for c in classes if PLAIN.match(c) and not GENERATED.search(c)]

    def simple(self):
        if self.attrs.get("id") and not GENERATED.search(self.attrs["id"]):
            return f"{self.tag}#{self.attrs['id']}"
        classes = self.classes()[:2]
        return self.tag + "".join(f".{c}" for c in classes)

    def own_text(self):
        return " ".join(" ".join(self.text).split())

    def all_text(self):
        parts = [self.own_text()] + [c.all_text() for c in self.children]
        return " ".join(p for p in parts if p)

    def ancestors(self):
        node = self.parent
        while node is not None and node.tag != "#root":
            yield node
            node = node.parent

    def path(self, depth=3):
        """Selector of the element with up to `depth` identifiable ancestors."""
        parts = [self.simple()]
        for a in self.ancestors():
            if len(parts) > depth:
                break
            if a.attrs.get("id") or a.classes():
                parts.append(a.simple())
        return " ".join(reversed(parts))

    def container(self):
        """Nearest ancestor with an id or class, used to group links."""
        for a in self.ancestors():
            if a.attrs.get("id") and not GENERATED.search(a.attrs["id"]):
                return a
            if a.classes() and a.tag not in ("li", "span", "a"):
                return a
        return None


class Tree(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("#root", [], None)
        self.stack = [self.root]
        self.nodes = []
        self.skipping = 0

    def handle_starttag(self, tag, attrs):
        if self.skipping:
            if tag in SKIP:
                self.skipping += 1
            return
        if tag in SKIP:
            self.skipping = 1
            return
        node = Node(tag, attrs, self.stack[-1])
        self.stack[-1].children.append(node)
        self.nodes.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID and not self.skipping and self.stack[-1].tag == tag:
            self.stack.pop()

    def handle_endtag(self, tag):
        if self.skipping:
            if tag in SKIP:
                self.skipping -= 1
            return
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                return

    def handle_data(self, data):
        if not self.skipping and data.strip():
            self.stack[-1].text.append(data.strip())


def chapter_of(a):
    raw = " ".join(f'{k}="{v}"' for k, v in a.attrs.items() if v) + " " + a.all_text()
    m = HREF_CHAPTER.findall(raw)
    if len(m) == 1 and int(m[0]) < 1000:
        return int(m[0])
    m = TEXT_CHAPTER.findall(raw)
    return int(m[0]) if len(m) == 1 else None


def short(s, n=90):
    s = " ".join((s or "").split())
    return s if len(s) <= n else s[: n - 1] + "…"


def main(path):
    tree = Tree()
    with open(path, encoding="utf-8", errors="replace") as f:
        tree.feed(f.read())
    nodes = tree.nodes

    print("== meta")
    for n in nodes:
        prop = n.attrs.get("property") or n.attrs.get("name")
        if n.tag == "meta" and prop in ("og:title", "og:image", "twitter:image"):
            print(f'  meta[property="{prop}"]' if n.attrs.get("property") else f'  meta[name="{prop}"]',
                  "->", short(n.attrs.get("content")))
        if n.tag == "title":
            print("  <title> ->", short(n.own_text()))

    print("\n== title candidates (headings and *title* elements, own text only, first 12)")
    shown = 0
    for n in nodes:
        titled = any("title" in " ".join(e.classes()).lower() for e in (n, n.parent) if e)
        text = n.own_text()
        if shown < 12 and text and (n.tag in ("h1", "h2", "h3") or titled):
            shown += 1
            print(f"  {n.path()}  ->  {short(text)}")

    print("\n== image candidates (first 15)")
    shown = 0
    for n in nodes:
        if n.tag != "img" or shown >= 15:
            continue
        srcs = {k: v for k, v in n.attrs.items() if k in ("src", "data-src", "data-lazy-src") and v}
        if not srcs:
            continue
        shown += 1
        attrs = ", ".join(f"{k}={short(v, 70)}" for k, v in srcs.items())
        print(f"  {n.path()}  alt={short(n.attrs.get('alt'), 40)!r}  {attrs}")

    print("\n== link groups (by container, most chapter links first)")
    groups = defaultdict(list)
    for n in nodes:
        if n.tag == "a" and n.attrs.get("href"):
            c = n.container()
            key = (c.path(depth=1) if c else "") + " a"
            groups[key].append(n)
    ranked = sorted(groups.items(), key=lambda kv: (-sum(chapter_of(a) is not None for a in kv[1]), -len(kv[1])))
    for key, links in ranked[:8]:
        chapters = [c for c in (chapter_of(a) for a in links) if c is not None]
        top = f", max chapter {max(chapters)}" if chapters else ""
        print(f"  {key.strip()}  ({len(links)} links, {len(chapters)} with chapter{top})")
        for a in links[:3]:
            print(f"      {short(a.attrs.get('href'), 70)}  |  {short(a.all_text(), 40)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
