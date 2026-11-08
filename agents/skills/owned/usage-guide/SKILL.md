---
name: usage-guide
description: Build an end-user usage guide (사용 가이드, 매뉴얼, 사용 방법 안내서) as a 16:9 PDF plus a standalone HTML, with screen captures or CSS mockups, red numbered markers, matching step explanations, and an FAQ. Use when the user asks for a guide, manual, or how-to document that operators, merchants, customers, or other end users of a product will read, typically right after a feature was built or changed. Do not use for internal planning or policy review documents, release notes, API references, or developer READMEs.
---

# Usage Guide

Turn a product feature into a document its end users can follow alone: where to go, what to press, and what happens next. The reader never sees the code, the tickets, or the team's decisions, so the guide carries none of them.

## Inputs

Settle these before writing. Derive each one from the conversation, the repository, and the change just made. Ask only for what stays unknown and would change the document.

- Scope: the tasks the reader must be able to finish.
- Reader: the role that reads the guide and the name the product uses for that role.
- Surfaces: the web or app screens where the tasks happen. Write one guide per surface when the readers differ.
- Product name and accent color: take the color from the project's design tokens or theme; otherwise keep the default in `guide.css`.
- Language: the user's conversation language unless the user names another. When it is not Korean, translate every Korean string in the skeleton, including its labels, captions, and closing sentence, and set `<html lang>`.
- Output directory: `~/Downloads` unless the user names another.

## Gather facts

1. Take every label, button, message, and menu name verbatim from its source: i18n resource files, components, or the running screen. Never paraphrase a UI string.
2. Trace the behavior the reader will meet: required fields and validation messages, conditions that hide or disable controls, states and their transitions, and what changes after saving.
3. Resolve menu paths as the reader sees them. When menus come from server data, confirm them on a real screen or list them as confirmation items.
4. When the real behavior blocks a step, guide the reader through a path that works and report the gap to the user. Do not document a workaround that needs internal tools.
5. Keep a list of facts you could not verify. Report them instead of guessing them into the guide.

## Structure

Copy `assets/skeleton.html` (as `guide.html`) and `assets/guide.css` into a fresh working directory, such as the session scratchpad, and write the guide there. Put captures in `img/` beside it. Keep this order:

1. Cover: product, title, one-line purpose, reader, version, and date.
2. Contents: two columns with section rows highlighted. Each `data-page-of="<page id>"` fills in its page number.
3. "What is <feature>?": one lead paragraph, a flow of 4 to 6 boxes, 3 term cards, and a core rules table of 4 to 6 rows.
4. Optional "where to find it": a table of tasks, menu paths, and who does them, plus the preparation order when tasks depend on each other.
5. Optional PART divider per surface or phase when the guide spans more than one.
6. One page per screen or task: a header with the section tag, the task title, and the menu path as the crumb; the screen on the left with red numbered markers; numbered steps on the right that match the markers; at most two callouts (참고 for context, 주의 for what fails or cannot be undone). Split a page that needs more than 6 steps.
7. FAQ: 8 to 10 rows of situation and what to do, each situation phrased the way the reader would say it.
8. Closing: the date and the screens the guide is based on, a note that names and amounts are examples, and related guides.

A typical guide runs 10 to 18 pages. The skeleton script adds the footer and page numbers to light pages; do not write them by hand.

## Writing rules

- Write only what the reader needs to act. Leave out ticket numbers, code, branch or deploy references, decision history, internal URLs (use menu names), error code identifiers (use the on-screen message), permission internals the reader cannot change, and production notes such as "mockup" or "assumption".
- Use a polite declarative voice. In Korean, use 합니다체.
- Quote UI text verbatim in 「」, write buttons as **[label]**, and write menu paths as `A › B › C`.
- Address the reader by the product's own name for the role.
- Mark sample names, amounts, and counts as examples in a caption or on the closing page.

## Screens

- Prefer real captures. Ask the user to log in to the browser or simulator session; never enter credentials yourself.
- Do not save, submit, or delete anything only to get a capture. Fill forms and capture without saving unless the user approves the action on a non-production environment.
- Never show real personal data such as names, phone numbers, emails, or addresses. Pick another screen or record, or mask it.
- Capture web screens at a 1440x900 viewport. If the capture tool can save only inside the workspace, save to a git-ignored path, move the files to the working directory, and delete the temporary folder.
- Place a capture with `.fit` (the whole image scaled to a width) or `.crop` (a window into a larger image, set with the image's `width`, `left`, and `top`). Place markers with `.num.pin` at percentage `left` and `top` of the container.
- Without captures, build mockups from the `guide.css` components with the real UI strings and caption them 예시 화면 (or its translation). Web: `.apanel`, `.atbl`, `.dlg`, `.fld`, `.btn`. Mobile: `.phone`, `.mcard`, `.mchip`, `.mbtn`, `.mtabs`, `.mrow`, `.sheet`, `.opt`.

## Render and verify

Run `scripts/render.sh <working-dir>/guide.html <output-dir> <file-name>`. It inlines CSS and images into `<file-name>.html`, prints `<file-name>.pdf` with headless Chrome, and writes review PNGs to a new temporary directory each successful run. It stages the outputs and checks Chrome, PDF metadata, fonts, and review rendering before replacing earlier files. It embeds the first Pretendard variable font it finds; set `GUIDE_FONT` to another variable font file when that does not fit the language.

Check every point before delivering:

1. `Pages` matches the intended page count and `Page size` is `960 x 540 pts`.
2. The intended font appears among the embedded fonts. If it is missing, the font did not load. If a system font appears beside it, a symbol the font lacks (such as ➔) fell back; replace that symbol.
3. Open every review PNG. Look for content clipped at the bottom (pages hide overflow), callouts overlapping the footer, markers off their targets, `?` in the contents, and leftover `{{` placeholders.
4. To check a marker precisely, render that region at 130 dpi with `pdftoppm -png -r 130 -f N -l N -x X -y Y -W W -H H`; CSS px = image px × 96 / 130.
5. Search `guide.html` for excluded content: ticket patterns, URLs, code identifiers, and error codes.

Common fixes: shrink a table with `table.t.tight` or split the page; let mockups size to their content instead of fixing `height`; prefix page-specific class names so they do not collide with `guide.css`.

## Deliver

- Name the files `<product>-<topic>-guide-<surface>` in the document language, for example `<제품>-<주제>-가이드-<화면>`.
- Hand over the PDF and the standalone HTML. The standalone HTML is also the source for later revisions: edit it and run `render.sh` on it again.
- Report the paths, the page count, which screens are captures and which are mockups, facts the user must confirm, and product gaps found while writing.

## Failure and side effects

- Stop and say what to install when Chrome or Chromium, python3, or poppler (`pdfinfo`, `pdffonts`, `pdftoppm`) is missing.
- Stop when a referenced image or stylesheet is missing; `render.sh` lists the missing files.
- Failed rendering or validation preserves earlier HTML and PDF files. If publication fails or is interrupted after publishing the HTML and before publishing the PDF, the script restores the earlier HTML. If restoration itself fails, it reports the retained backup path.
- Side effects: replaces the two output files after validation, leaves a temporary directory of review PNGs on success, and runs headless Chrome with an isolated profile that is deleted afterwards. Captures may need the user's login. Nothing is written to the project repository.
