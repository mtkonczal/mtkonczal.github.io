// ============================================================
//  gutter.typ — sidenote grid: dates hang in a left column
//  Typst port of templates/gutter.tex.
//  Where the LaTeX version needed \llap and a negative \hspace
//  inside a titlesec argument, Typst does it with `place` (an
//  overlay that takes no space) and `pad` with a negative inset.
//  Requires the vendored fonts: compile with --font-path fonts
// ============================================================

#let ink    = rgb("#15181C")
#let ink2   = rgb("#4A5057")
#let ink3   = rgb("#9AA0A8")
#let accent = rgb("#7A2E2E")   // oxblood

#let serif = "Cochineal"
#let sans  = "Source Sans Pro"

// ---- the grid ----------------------------------------------
#let gut-w = 1.08in     // label column: sized to fit "github.com/handle" at 8pt
#let gut-s = 0.18in     // gap to the content column

// hang content in the left column; takes no space, so no reflow
#let gutter(content) = place(
  dx: -(gut-w + gut-s), dy: 0pt,
  box(width: gut-w, content),
)

#let datestyle(d) = text(font: sans, size: 8.5pt, fill: ink2, d)

#let job(title, org, loc, dates) = block(above: 13pt, below: 3pt, sticky: true, width: 100%)[
  #gutter(datestyle(dates))
  #text(weight: "bold", title)
  #linebreak()
  #text(font: sans, size: 9pt, fill: ink2)[#org #text(fill: ink3)[·] #loc]
]

#let edu(degree, school, dates) = block(above: 13pt, below: 3pt, sticky: true, width: 100%)[
  #gutter(datestyle(dates))
  #text(weight: "bold", degree)
  #linebreak()
  #text(font: sans, size: 9pt, fill: ink2, school)
]

#let skills(list) = block(above: 2pt, text(font: sans, size: 9.5pt, list))

#let resume(
  name: none, jobtitle: none, email: none, web: none,
  github: none, twitter: none, city: none, phone: none,
  body,
) = {
  set document(title: name + " — Resume", author: name)

  set page(
    paper: "us-letter",
    // page margin 0.8in + label column 1.08in + gap 0.18in on the left
    margin: (top: 0.8in, bottom: 0.7in, left: 2.06in, right: 0.8in),
    footer: context align(right, text(font: sans, size: 8pt, fill: ink3)[
      #name #h(0.4em)|#h(0.4em)
      #counter(page).display()/#counter(page).final().first()
    ]),
  )

  set text(font: serif, size: 10pt, fill: ink, lang: "en",
           number-type: "lining", hyphenate: false)
  set par(justify: false, leading: 0.58em, spacing: 0.58em, linebreaks: "optimized")

  set list(marker: box(width: 0.5em, baseline: -0.28em,
                       line(length: 100%, stroke: 0.4pt + ink3)),
           indent: 0.5em, body-indent: 0.55em, spacing: 0.68em)

  show link: set text(fill: accent)

  // section: label at the far left of the grid, hairline across the
  // whole width. Negative left padding breaks out of the column.
  show heading.where(level: 1): it => block(above: 15pt, below: 7pt)[
    #pad(left: -(gut-w + gut-s))[
      #text(font: sans, size: 8pt, weight: "bold", fill: accent, tracking: 0.14em,
            upper(it.body))
      #v(2.5pt, weak: true)
      #line(length: 100%, stroke: 0.4pt + ink3)
    ]
  ]

  // ---- masthead: contact stack in the gutter, bottom-aligned ----
  let contact = (
    if email != none { link("mailto:" + email)[#email] },
    if web != none { link("https://" + web)[#web] },
    if github != none { link("https://github.com/" + github)[github.com/#github] },
    if twitter != none { link("https://twitter.com/" + twitter)[@#twitter] },
    if phone != none { phone },
    if city != none { city },
  ).filter(x => x != none)

  block(below: 0pt)[
    #grid(
      columns: (gut-w, gut-s, 1fr),
      align: (left + bottom, auto, left + bottom),
      {
        set text(font: sans, size: 8pt, fill: ink2)
        show link: set text(fill: ink2)
        set par(leading: 0.5em)
        // each item boxed so a long handle spills into the 0.22in
        // gap rather than wrapping inside the label column
        contact.map(c => box(c)).join(linebreak())
      },
      [],
      {
        text(size: 22pt, weight: "bold", tracking: 0.015em, name)
        if jobtitle != none {
          v(3pt, weak: true)
          text(font: sans, size: 9.5pt, fill: ink2, jobtitle)
        }
      },
    )
  ]

  body
}
