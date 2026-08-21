# Typst build. No TeX distribution required.
#
#   make            build both PDFs
#   make watch      live rebuild on save (~5ms per keystroke)
#   make clean
#
# Libertinus Serif ships inside the typst binary, so `editorial` has no
# font dependency. `gutter` uses the OFL fonts vendored in fonts/.

TYPST   := typst
FONTS   := --font-path fonts
TARGETS := editorial.pdf gutter.pdf resume_brief.pdf

.PHONY: all watch clean
all: $(TARGETS)

editorial.pdf: editorial.typ lib/editorial.typ content.typ
	$(TYPST) compile $<

gutter.pdf: gutter.typ lib/gutter.typ content.typ
	$(TYPST) compile $(FONTS) $<

resume_brief.pdf: resume_brief.typ lib/resume-brief.typ content-brief.typ
	$(TYPST) compile $(FONTS) $<

# usage: make watch V=gutter
V ?= editorial
watch:
	$(TYPST) watch $(FONTS) $(V).typ

clean:
	rm -f $(TARGETS)
