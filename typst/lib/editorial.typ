// ============================================================
//  editorial.typ — quiet serif, space-driven hierarchy
//  Typst port of templates/editorial.tex. Same design decisions:
//    - One typeface. Hierarchy from size, case, grey value, space.
//    - Exactly one rule in the document.
//    - Ragged right; justification opens rivers at this measure.
//    - Lining figures so years scan as data.
//  Libertinus Serif is embedded in the typst binary, so this file
//  has no external font dependency at all.
// ============================================================

#let ink    = rgb("#15181C")   // body
#let ink2   = rgb("#4A5057")   // orgs, dates
#let ink3   = rgb("#8A9099")   // rules, markers, folio
#let accent = rgb("#1F3A5F")   // links only

// ---- entry macros -------------------------------------------
// The date column is a two-cell grid: `auto` sizes to the date,
// `1fr` takes the rest. A long title wraps inside its own cell,
// so the date can never ride down onto the wrap.
#let job(title, org, loc, dates) = block(above: 14pt, below: 3pt, sticky: true, width: 100%)[
  #grid(
    columns: (1fr, auto), column-gutter: 1em, align: (left, right + bottom),
    text(weight: "bold", title),
    text(size: 8.5pt, fill: ink2, dates),
  )
  #text(fill: ink2, style: "italic", org)#text(fill: ink3, ", " + loc)
]

#let edu(degree, school, dates) = block(above: 14pt, below: 3pt, sticky: true, width: 100%)[
  #grid(
    columns: (1fr, auto), column-gutter: 1em, align: (left, right + bottom),
    text(weight: "bold", degree),
    text(size: 8.5pt, fill: ink2, dates),
  )
  #text(fill: ink2, style: "italic", school)
]

#let skills(list) = block(above: 2pt, list)

// ---- the template ------------------------------------------
#let resume(
  name: none, jobtitle: none, email: none, web: none,
  github: none, twitter: none, city: none, phone: none,
  body,
) = {
  set document(title: name + " — Resume", author: name)

  set page(
    paper: "us-letter",
    margin: (top: 0.9in, bottom: 0.85in, left: 1in, right: 1in),
    footer: context align(center, text(8pt, fill: ink3)[
      #name #h(0.5em) · #h(0.5em)
      #counter(page).display() of #counter(page).final().first()
    ]),
  )

  set text(
    font: "Libertinus Serif", size: 10.5pt, fill: ink,
    lang: "en", number-type: "lining",
    // Typst's optimised line breaker keeps a good rag without hyphens
    hyphenate: false,
  )
  // ragged right, and loose enough that hyphens stay rare
  set par(justify: false, leading: 0.60em, spacing: 0.60em, linebreaks: "optimized")

  set list(marker: text(fill: ink3, [–]), indent: 0.5em, body-indent: 0.6em, spacing: 0.72em)
  show list: set block(above: 4pt, below: 4pt)

  show link: set text(fill: accent)

  // sections: small caps at body size, letterspaced. No rule.
  show heading.where(level: 1): it => block(above: 16pt, below: 5pt)[
    #text(size: 10.5pt, fill: ink2, tracking: 0.09em, weight: "regular",
          smallcaps(lower(it.body)))
  ]

  // ---- masthead ---------------------------------------------
  let sep = text(fill: ink3)[#h(0.35em)·#h(0.35em)]
  let bits = (
    if email != none { link("mailto:" + email)[#email] },
    if web != none { link("https://" + web)[#web] },
    if github != none { link("https://github.com/" + github)[github.com/#github] },
    if twitter != none { link("https://twitter.com/" + twitter)[@#twitter] },
    if phone != none { phone },
    if city != none { city },
  ).filter(x => x != none)

  text(size: 20pt, weight: "bold", tracking: 0.025em, name)
  if jobtitle != none {
    block(above: 5pt, below: 0pt, text(fill: ink2, jobtitle))
  }
  block(above: 5pt, below: 0pt)[
    #set text(size: 8.5pt, fill: ink2)
    #show link: set text(fill: ink2)
    #bits.join(sep)
  ]
  block(above: 8pt, below: 0pt, line(length: 100%, stroke: 0.4pt + ink3))

  body
}
