// ============================================================
//  resume-brief.typ — one-page compression of gutter.typ.
//  Same sidenote-grid design; margins, type size, and spacing
//  tightened to hold the condensed prose content to one page,
//  the way brief.tex compresses gutter.tex.
// ============================================================

#import "@preview/fontawesome:0.5.0": fa-icon

#let ink    = rgb("#15181C")
#let ink2   = rgb("#4A5057")
#let ink3   = rgb("#9AA0A8")
#let accent = rgb("#7A2E2E")   // oxblood

#let serif = "Cochineal"
#let sans  = "Source Sans Pro"

// ---- the grid ----------------------------------------------
#let gut-w = 1.08in     // label column: sized to fit "github.com/handle" at 8pt
#let gut-s = 0.15in     // gap to the content column

// hang content in the left column; takes no space, so no reflow
#let gutter(content) = place(
  dx: -(gut-w + gut-s), dy: 0pt,
  box(width: gut-w, content),
)

#let datestyle(d) = text(font: sans, size: 8.5pt, fill: ink2, d)

// small muted glyph ahead of a contact-line entry
#let cicon(name, solid: true) = fa-icon(name, solid: solid, size: 0.85em, fill: ink3)

// title, org, and location on one line — org carries the same weight
// as the reader's eye needs it (where he worked matters as much as
// what his title was), not demoted to a small grey caption line.
#let job(title, org, loc, dates) = block(above: 14pt, below: 7pt, sticky: true, width: 100%)[
  #gutter(datestyle(dates))
  #text(weight: "bold", title)#[, ]#org#text(fill: ink2)[, #loc]
]

#let edu(degree, school, dates) = block(above: 14pt, below: 7pt, sticky: true, width: 100%)[
  #gutter(datestyle(dates))
   #text(weight: "bold", degree)#[, ]#school
]

#let skills(list) = block(above: 2pt, text(font: sans, size: 9.5pt, list))

#let resume(
  name: none, email: none, web: none,
  github: none, twitter: none, city: none, phone: none,
  body,
) = {
  set document(title: name + " — Resume", author: name)

  set page(
    paper: "us-letter",
    margin: (top: 0.75in, bottom: 0.65in, left: gut-w + gut-s + 0.8in, right: 0.8in),
  )

  set text(font: serif, size: 10pt, fill: ink, lang: "en",
           number-type: "lining", hyphenate: false)
  set par(justify: false, leading: 0.58em, spacing: 0.58em, linebreaks: "optimized")

  set list(marker: box(width: 0.5em, baseline: -0.28em,
                       line(length: 100%, stroke: 0.4pt + ink3)),
           indent: 0.5em, body-indent: 0.55em, spacing: 0.62em)

  show link: set text(fill: accent)

  // section: label at the far left of the grid, hairline across the
  // whole width. Negative left padding breaks out of the column.
  show heading.where(level: 1): it => block(above: 15pt, below: 6.5pt)[
    #pad(left: -(gut-w + gut-s))[
      #text(font: sans, size: 8pt, weight: "bold", fill: accent, tracking: 0.13em,
            upper(it.body))
      #v(2.5pt, weak: true)
      #line(length: 100%, stroke: 0.4pt + ink3)
    ]
  ]

  // ---- masthead: name flush with the true left margin (breaking out
  // of the gutter indent, same as section headings), contact info as
  // a one-line banner underneath rather than stacked in the gutter ----
  let contact = (
    if email != none { [#cicon("envelope") #h(2.5pt) #link("mailto:" + email)[#email]] },
    if web != none { [#cicon("globe") #h(2.5pt) #link("https://" + web)[#web]] },
    if github != none { [#cicon("github", solid: false) #h(2.5pt) #link("https://github.com/" + github)[github.com/#github]] },
    if twitter != none { [#cicon("x-twitter", solid: false) #h(2.5pt) #link("https://twitter.com/" + twitter)[@#twitter]] },
    if phone != none { [#cicon("phone") #h(2.5pt) #phone] },
    if city != none { [#cicon("location-dot") #h(2.5pt) #city] },
  ).filter(x => x != none)

  block(below: 0pt)[
    #pad(left: -(gut-w + gut-s))[
      #text(size: 21pt, weight: "bold", tracking: 0.015em, name)
      #v(4pt)
      #block(width: 100%)[
        #set text(font: sans, size: 8.5pt, fill: ink2)
        #show link: set text(fill: ink2)
        #align(center)[#contact.join([ #text(fill: ink3)[·] ])]
      ]
    ]
  ]

  body
}
