// One-page brief, gutter layout. Same design as gutter.typ; the
// content file underneath is the condensed prose used by resume-brief.qmd.
#import "lib/resume-brief.typ" as design
#import "content-brief.typ": body

#show: design.resume.with(
  name: "Mike Konczal",
  email: "konczal@gmail.com",
  web: "mikekonczal.com",
  github: "mtkonczal",
  twitter: "mtkonczal",
  city: "Takoma Park, MD",
)

#body(design.job, design.edu, design.skills)
