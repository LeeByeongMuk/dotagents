"""Inline local stylesheets, images, and CSS url() references into one HTML file.

With --font, also adds a local @font-face named "GuideFont" for printing.
Content inside HTML comments is left untouched.
"""

import argparse
import base64
import mimetypes
import pathlib
import re
import sys
from urllib.parse import unquote, urlparse

COMMENT = re.compile(r"<!--.*?-->", re.S)
STYLESHEET = re.compile(r"<link\b[^>]*\brel=[\"']stylesheet[\"'][^>]*>", re.I)
HREF = re.compile(r"\bhref=[\"']([^\"']+)[\"']", re.I)
IMG_SRC = re.compile(r"(<img\b[^>]*?\bsrc=)([\"'])([^\"']+)\2", re.I)
IMG_SRC_BARE = re.compile(r"(<img\b[^>]*?\bsrc=)()([^\s\"'>]+)", re.I)
STYLE_BLOCK = re.compile(r"(<style\b[^>]*>)(.*?)(</style>)", re.I | re.S)
STYLE_ATTR = re.compile(r"(\bstyle=)([\"'])(.*?)\2", re.I | re.S)
CSS_URL = re.compile(r"url\(\s*((?:[\"']|&quot;|&#39;)?)([^)\"']+?)\1\s*\)")
HEAD = re.compile(r"<head\b[^>]*>", re.I)
FONT_FORMATS = {".ttf": "truetype", ".otf": "opentype", ".woff2": "woff2", ".woff": "woff"}


def is_local(ref: str) -> bool:
    scheme = urlparse(ref).scheme
    return scheme in ("", "file") and not ref.startswith("#")


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

    def inline_css_urls(css: str, css_base: pathlib.Path) -> str:
        def replace(match: re.Match) -> str:
            ref = match.group(2)
            if not is_local(ref):
                return match.group(0)
            path = resolve(ref, css_base)
            if not path.is_file():
                missing.append(str(path))
                return match.group(0)
            return f"url({data_uri(path)})"

        return CSS_URL.sub(replace, css)

    def replace_stylesheet(match: re.Match) -> str:
        href = HREF.search(match.group(0))
        if not href or not is_local(href.group(1)):
            return match.group(0)
        path = resolve(href.group(1), base)
        if not path.is_file():
            missing.append(str(path))
            return match.group(0)
        css = inline_css_urls(path.read_text(encoding="utf-8"), path.parent)
        return f"<style>\n{css}\n</style>"

    def replace_img(match: re.Match) -> str:
        ref = match.group(3)
        if not is_local(ref):
            return match.group(0)
        path = resolve(ref, base)
        if not path.is_file():
            missing.append(str(path))
            return match.group(0)
        return f"{match.group(1)}{match.group(2)}{data_uri(path)}{match.group(2)}"

    def inline_segment(segment: str) -> str:
        segment = STYLESHEET.sub(replace_stylesheet, segment)
        segment = STYLE_BLOCK.sub(lambda m: m.group(1) + inline_css_urls(m.group(2), base) + m.group(3), segment)
        segment = STYLE_ATTR.sub(lambda m: m.group(1) + m.group(2) + inline_css_urls(m.group(3), base) + m.group(2), segment)
        segment = IMG_SRC.sub(replace_img, segment)
        return IMG_SRC_BARE.sub(replace_img, segment)

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
