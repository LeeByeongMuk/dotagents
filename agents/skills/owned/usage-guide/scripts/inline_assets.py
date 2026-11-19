"""Inline local stylesheets, images, and CSS url() references into one HTML file.

With --font, also adds a local @font-face named "GuideFont" for printing.
Content inside HTML comments is left untouched.
"""

import argparse
import base64
from html import escape, unescape
from html.parser import HTMLParser
import mimetypes
import pathlib
import re
import sys
from urllib.parse import unquote, urlparse

COMMENT = re.compile(r"<!--.*?-->", re.S)
ATTRIBUTE = re.compile(r"""([^\s=/>]+)(?:(\s*=\s*)("[^"]*"|'[^']*'|[^\s>]+))?""")
SRCSET_URL = re.compile(r"[^, \t\n\f\r][^ \t\n\f\r]*")
SRCSET_DESCRIPTORS = re.compile(r"(?:[^,(]|\([^)]*(?:\)|$))*")
STYLE_BLOCK = re.compile(r"(<style\b[^>]*>)(.*?)(</style>)", re.I | re.S)
STYLE_ATTR = re.compile(r"(\bstyle=)([\"'])(.*?)\2", re.I | re.S)
CSS_URL = re.compile(r"url\(\s*((?:[\"']|&quot;|&#39;)?)([^)\"']+?)\1\s*\)")
HEAD = re.compile(r"<head\b[^>]*>", re.I)
FONT_FORMATS = {".ttf": "truetype", ".otf": "opentype", ".woff2": "woff2", ".woff": "woff"}


def is_local(ref: str) -> bool:
    parsed = urlparse(ref)
    return parsed.scheme == "file" or (
        not parsed.scheme and not parsed.netloc and not ref.startswith("#")
    )


def resolve(ref: str, base: pathlib.Path) -> pathlib.Path:
    parsed = urlparse(ref)
    path = pathlib.Path(unquote(parsed.path))
    return path if path.is_absolute() else (base / path).resolve()


def data_uri(path: pathlib.Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    if path.suffix.lower() == ".svg":
        mime = "image/svg+xml"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode('ascii')}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("output")
    parser.add_argument("--font")
    args = parser.parse_args()

    source = pathlib.Path(args.source).resolve()
    base = source.parent
    html = source.read_text(encoding="utf-8")
    missing: list[str] = []

    def inline_url(ref: str, asset_base: pathlib.Path) -> str:
        if not ref or not is_local(ref):
            return ref
        path = resolve(ref, asset_base)
        if not path.is_file():
            missing.append(str(path))
            return ref
        return data_uri(path)

    def inline_css_urls(css: str, css_base: pathlib.Path) -> str:
        def replace(match: re.Match) -> str:
            ref = match.group(2)
            inlined = inline_url(ref, css_base)
            return f"url({inlined})" if inlined != ref else match.group(0)

        return CSS_URL.sub(replace, css)

    def inline_srcset(value: str) -> str:
        # URL tokens may contain commas (especially data URLs). A trailing
        # comma, or a comma after descriptors outside parentheses, ends a candidate.
        parts = []
        cursor = 0
        while match := SRCSET_URL.search(value, cursor):
            ref = match.group().rstrip(",")
            url_end = match.start() + len(ref)
            parts.extend((value[cursor:match.start()], inline_url(ref, base), value[url_end:match.end()]))
            cursor = match.end()
            if url_end == cursor:
                descriptors = SRCSET_DESCRIPTORS.match(value, cursor)
                parts.append(descriptors.group())
                cursor = descriptors.end()
        parts.append(value[cursor:])
        return "".join(parts)

    def inline_tag(tag: str, original: str, attributes: dict) -> str:
        if tag == "link":
            href = attributes.get("href")
            if (attributes.get("rel") or "").strip().lower() != "stylesheet" or not href or not is_local(href):
                return original
            path = resolve(href, base)
            if not path.is_file():
                missing.append(str(path))
                return original
            css = inline_css_urls(path.read_text(encoding="utf-8"), path.parent)
            media = attributes.get("media")
            media_attr = f' media="{escape(media)}"' if media is not None else ""
            return f"<style{media_attr}>\n{css}\n</style>"

        def replace_attribute(match: re.Match) -> str:
            name, equals, raw_value = match.groups()
            key = name.lower()
            if raw_value is None or not (key == "srcset" or tag == "img" and key == "src"):
                return match.group()
            quote = raw_value[0] if raw_value[0] in "\"'" else ""
            value = unescape(raw_value[1:-1] if quote else raw_value)
            inlined = inline_srcset(value) if key == "srcset" else inline_url(value, base)
            if inlined == value:
                return match.group()
            quote = quote or '"'
            return f"{name}{equals}{quote}{escape(inlined)}{quote}"

        tag_end = len(tag) + 1
        return original[:tag_end] + ATTRIBUTE.sub(replace_attribute, original[tag_end:])

    line_starts = [0, *(match.end() for match in re.finditer("\n", html))]
    replacements = []

    class AssetTags(HTMLParser):
        def handle_starttag(self, tag, attributes):
            if tag not in ("img", "source", "link"):
                return
            original = self.get_starttag_text()
            rewritten = inline_tag(tag, original, dict(reversed(attributes)))
            if rewritten != original:
                line, column = self.getpos()
                start = line_starts[line - 1] + column
                replacements.append((start, start + len(original), rewritten))

    tags = AssetTags()
    tags.feed(html)
    tags.close()
    parts = []
    cursor = 0
    for start, end, replacement in replacements:
        parts.extend((html[cursor:start], replacement))
        cursor = end
    html = "".join([*parts, html[cursor:]])

    def inline_segment(segment: str) -> str:
        segment = STYLE_BLOCK.sub(lambda m: m.group(1) + inline_css_urls(m.group(2), base) + m.group(3), segment)
        return STYLE_ATTR.sub(lambda m: m.group(1) + m.group(2) + inline_css_urls(m.group(3), base) + m.group(2), segment)

    parts: list[str] = []
    cursor = 0
    for comment in COMMENT.finditer(html):
        parts.append(inline_segment(html[cursor : comment.start()]))
        parts.append(comment.group(0))
        cursor = comment.end()
    parts.append(inline_segment(html[cursor:]))
    result = "".join(parts)

    if missing:
        print("missing files:\n  " + "\n  ".join(sorted(set(missing))), file=sys.stderr)
        return 1

    if args.font:
        font = pathlib.Path(args.font).resolve()
        if not font.is_file():
            print(f"missing font: {font}", file=sys.stderr)
            return 1
        fmt = FONT_FORMATS.get(font.suffix.lower(), "truetype")
        face = (
            '<style>@font-face{font-family:"GuideFont";'
            f'src:url("{font.as_uri()}") format("{fmt}");'
            "font-weight:100 900;font-style:normal}</style>"
        )
        head = HEAD.search(result)
        result = result[: head.end()] + face + result[head.end() :] if head else face + result

    pathlib.Path(args.output).write_text(result, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
