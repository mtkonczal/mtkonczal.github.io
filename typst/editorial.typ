// Entry point. Swap the first import to change the design; the
// content file below is untouched by that choice.
#import "lib/editorial.typ" as design
#import "content.typ": body

#show: design.resume.with(
  name: "Mike Konczal",
  jobtitle: "Vice President of Policy and Research, Economic Security Project",
  email: "konczal@gmail.com",
  web: "mikekonczal.com",
  github: "mtkonczal",
  twitter: "mtkonczal",
  city: "Takoma Park, MD",
)

#body(design.job, design.edu, design.skills)
