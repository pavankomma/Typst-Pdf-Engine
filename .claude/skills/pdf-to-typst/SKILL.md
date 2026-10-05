---
name: pdf-to-typst
description: Turn any PDF (invoice, report, letter, certificate, form, resume) into a reusable data-driven Typst template for this repo — templates/<name>.typ plus data/<name>.json — rendered with `tmpl` and visually checked against the source. Use when the user provides a PDF and wants a .typ template, "recreate this PDF", "make a template from this", or "convert PDF to typst".
---

# PDF → Typst template

One PDF in, two files out:

| File | Holds |
|---|---|
| `templates/<name>.typ` | fixed layout |
| `data/<name>.json` | the values that change per document |

`<name>` = short kebab-case document kind (`invoice`, `offer-letter`, `lab-report`). If that file already exists, pick a new name; never overwrite. Ask only if no PDF path was given.

## 1. Read the source

- **Read** the PDF **without** `pages` — you get the text and a picture of each page. (`pages` needs poppler's `pdftoppm`; only use it for PDFs over 10 pages.)
- Note the page count, margins, font kind (serif/sans/mono) and sizes, colors (estimate hex), layout grid, header/footer, tables, and computed values (totals, counts).

## 2. Split data from layout

- **JSON**: names, addresses, dates, IDs, line items, amounts, free text, rates. Use the PDF's real values (swap personal data for realistic fakes if it looks private).
- **Template**: labels, headings, colors, spacing, decorations.
- **Computed in the template, never stored**: subtotals, tax, totals, row numbers, percentages, page X of Y.
- Repeating rows → array of objects. Keys `snake_case`.

## 3. Write the template

```typst
// SPDX-License-Identifier: MIT
// <Name> template. Data arrives as JSON in sys.inputs.data (see `tmpl`).
#let d = json(bytes(sys.inputs.at("data", default: "{}")))
#let accent = rgb("#2b5cab")

#set page(paper: "a4", margin: (x: 2cm, y: 2cm))   // "us-letter" if the source is 8.5×11in
#set text(font: "Libertinus Serif", size: 10pt)
```

| PDF element | Typst |
|---|---|
| Side-by-side blocks | `grid(columns: (1fr, auto), ...)` |
| Table, striped rows | `table(fill: (_, y) => ..., table.header(...), ..rows)` |
| Rule / divider | `line(length: 100%, stroke: 1pt + accent)`, `table.hline()` |
| Box, callout, badge | `block` / `box` with `fill`, `inset`, `radius`, `stroke` |
| Footer "Page X" | `set page(footer: context [Page #counter(page).display()])` |
| Footer "Page X of Y" | add `#counter(page).final().first()` |
| New section on a new page | `#pagebreak()` |
| Signature line | `line(length: 4.5cm, stroke: 0.5pt)` above the label |
| Push to page bottom | `#v(1fr)` |
| Loop / optional field | `#for x in d.items [...]`, `d.at("notes", default: none)` |
| Bar chart | nested `box(width: share * 100%)` |
| Logo / image | draw with shapes, or `image("assets/<file>")` with the file in `templates/assets/` |
| Money | copy `money()` from `templates/invoice.typ`; drop the decimals if the source shows whole amounts |

Pitfalls (each one is a compile error):
- `image("../...")` → "escapes the project root". Files go in `templates/assets/`.
- Field access on a missing key fails; use `d.at("key", default: ...)` for anything optional.
- Arrays spread into tables need `..rows.flatten()`; each cell must be content or a string (`str(n)` for numbers).
- `#` starts code inside markup: write `\#` for a literal hash, `\$` for a dollar sign in markup.
- `align(center, table(...))` centres the cell text too; set `align: left` on the table.
- Fonts that aren't installed fall back silently; check with `typst fonts` and pick one that is listed.

## 4. Render and compare

Work in a temp folder, never the repo. Use the session scratchpad if you have one:

```sh
OUT="<scratchpad or ${TMPDIR:-${TEMP:-/tmp}}>/pdf-to-typst"; mkdir -p "$OUT"
cp "<source.pdf>" "$OUT/source.pdf"
```

**Rasterize the source** with Typst itself (no other tools needed). Set `N` to the page count you saw in step 1:

```sh
cat > "$OUT/source.typ" <<'TYP'
#set page(width: auto, height: auto, margin: 0pt)
#let n = N
#for i in range(1, n + 1) { image("source.pdf", page: i); if i < n { pagebreak() } }
TYP
typst compile "$OUT/source.typ" "$OUT/src-{p}.png" --ppi 144
```

Page size from `src-1.png`: pixels × 72 / 144 = points (1224×1584 px = `"us-letter"`, ≈1191×1684 px = `"a4"`).

**Render the template** at the same resolution (`tmpl` writes PNGs when the output ends in `-{p}.png`; Typst's default is 144 ppi):

```sh
cargo run --quiet -- templates/<name>.typ data/<name>.json "$OUT/<name>-{p}.png"
cargo run --quiet -- templates/<name>.typ data/<name>.json "$OUT/<name>.pdf"
```

**Read** `src-N.png` and `<name>-N.png` together. They have the same scale, so pixel positions compare directly. Fix in order: structure → spacing → typography → color. Match body text size first: if your lines hold more words than the source's, raise `text(size:)`; if fewer, lower it. Repeat until it reads as the same document (two or three passes is normal). Font-substitution differences are fine. If the source has an obvious defect (overlapping or clipped text), build the intended layout and list it as a deviation.

On a Typst error, the message gives file:line; fix and re-run.

## 5. Hand off

Report: the two files, the render command (`cargo run -- templates/<name>.typ data/<name>.json out.pdf`), and any deliberate deviations (substituted font, simplified logo, dropped element). Do not commit.
