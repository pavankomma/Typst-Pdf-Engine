// SPDX-License-Identifier: MIT
// Invoice template. Data arrives as JSON in sys.inputs.data (see `tmpl`).
#let d = json(bytes(sys.inputs.at("data", default: "{}")))
#let accent = rgb("#2b5cab")
#let money(v) = {
  let cents = calc.round(v * 100)
  let whole = str(calc.div-euclid(cents, 100)).rev().clusters().chunks(3).map(c => c.join()).join(",").rev()
  let frac = str(calc.rem-euclid(cents, 100))
  d.currency + whole + "." + if frac.len() < 2 { "0" + frac } else { frac }
}

#set page(
  margin: (x: 2cm, top: 2.5cm, bottom: 2cm),
  footer: context [
    #set text(8pt, gray)
    #d.from.name · #d.from.email #h(1fr) Page #counter(page).display() of #counter(page).final().first()
  ],
)
#set text(font: "Libertinus Serif", size: 10pt)

// Header band
#grid(columns: (1fr, auto), align: (left, right),
  [#text(22pt, weight: "bold", fill: accent)[#d.from.name] \ #d.from.address.join("\n")],
  [#text(26pt, weight: "bold", tracking: 2pt)[INVOICE] \ *#d.number*],
)
#line(length: 100%, stroke: 2pt + accent)

// Parties and dates
#grid(columns: (1fr, 1fr, auto), gutter: 1em,
  [#text(gray)[BILL TO] \ *#d.to.name* \ #d.to.address.join("\n") \ #d.to.email],
  [],
  table(columns: 2, stroke: none, inset: 3pt, align: (left, right),
    text(gray)[Issued], d.date, text(gray)[Due], strong(d.due)),
)
#v(1em)

// Line items
#let subtotal = d.items.map(i => i.qty * i.price).sum()
#let tax = subtotal * d.tax_rate
#table(
  columns: (auto, 1fr, auto, auto, auto),
  align: (center, left, right, right, right),
  stroke: none, inset: 7pt,
  fill: (_, y) => if y == 0 { accent } else if calc.even(y) { luma(245) },
  table.header(..("#", "Description", "Qty", "Price", "Amount").map(h => text(white, weight: "bold", h))),
  ..d.items.enumerate().map(((n, i)) =>
    (str(n + 1), i.description, str(i.qty), money(i.price), money(i.qty * i.price))
  ).flatten(),
)

// Totals
#align(right, table(columns: 2, stroke: none, inset: 5pt, align: right,
  [Subtotal], money(subtotal),
  [Tax (#(d.tax_rate * 100)%)], money(tax),
  table.hline(stroke: 1pt + accent),
  text(13pt, weight: "bold")[Total], text(13pt, weight: "bold", fill: accent, money(subtotal + tax)),
))

// Cost breakdown bars
#v(1em)
#text(gray)[COST BREAKDOWN]
#for i in d.items {
  let share = i.qty * i.price / subtotal
  grid(columns: (5cm, 1fr, 3em), gutter: 6pt, align: horizon,
    text(9pt, i.description),
    box(width: 100%, height: 8pt, fill: luma(235), radius: 3pt,
      box(width: share * 100%, height: 8pt, fill: accent, radius: 3pt)),
    text(9pt)[#calc.round(share * 100)%])
}

#v(1fr)
#block(fill: luma(245), inset: 10pt, radius: 4pt, width: 100%)[*Notes* \ #d.notes]
