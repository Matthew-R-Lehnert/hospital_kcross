# Manuscript build: Pandoc + Citation Style Language (CSL)
# -----------------------------------------------------------------------------
# The bibliography (references.bib) is the single, style-AGNOSTIC source of
# truth. Citation style (APA, Chicago, Vancouver, …) is chosen at BUILD time by
# swapping a CSL file; the prose never changes. In-text citations use Pandoc
# syntax: [@key] parenthetical, @key narrative, [@a; @b] multiple.
#
# Usage:
#   make                       # PDF in the default style (APA)
#   make STYLE=chicago-author-date
#   make STYLE=vancouver
#   make docx                  # Word output (for co-authors / journal upload)
#   make html
#   make styles                # download the common CSL files into csl/
#   make clean
# -----------------------------------------------------------------------------

STYLE   ?= apa
SECTIONS = 00_abstract.md 01_introduction.md 02_related_work.md \
           03_data.md 04_methods.md 05_results.md 06_conclusion.md
BIB      = references.bib
CSL      = csl/$(STYLE).csl
OUT      = manuscript
TITLE    = metadata.yaml

PANDOC_FLAGS = --citeproc --bibliography=$(BIB) --csl=$(CSL) \
               --metadata-file=$(TITLE) \
               --resource-path=.:figures

.PHONY: all pdf docx html styles clean

all: pdf

pdf: $(CSL)
	pandoc $(TITLE) $(SECTIONS) $(PANDOC_FLAGS) -o $(OUT).pdf

docx: $(CSL)
	pandoc $(TITLE) $(SECTIONS) $(PANDOC_FLAGS) -o $(OUT).docx

html: $(CSL)
	pandoc $(TITLE) $(SECTIONS) $(PANDOC_FLAGS) --standalone --toc -o $(OUT).html

# Fetch common citation styles from the official CSL repository.
CSL_BASE = https://raw.githubusercontent.com/citation-style-language/styles/master
styles:
	mkdir -p csl
	curl -fsSL $(CSL_BASE)/apa.csl                 -o csl/apa.csl
	curl -fsSL $(CSL_BASE)/chicago-author-date.csl -o csl/chicago-author-date.csl
	curl -fsSL $(CSL_BASE)/chicago-note-bibliography.csl -o csl/chicago-note-bibliography.csl
	curl -fsSL $(CSL_BASE)/vancouver.csl           -o csl/vancouver.csl
	curl -fsSL $(CSL_BASE)/ieee.csl                -o csl/ieee.csl
	curl -fsSL $(CSL_BASE)/elsevier-harvard.csl    -o csl/elsevier-harvard.csl
	@echo "Installed CSL styles into csl/. Build with: make STYLE=<name>"

$(CSL):
	@echo "Missing $(CSL). Run 'make styles' to download citation styles, or"
	@echo "place a <style>.csl in csl/ and build with STYLE=<style>."
	@exit 1

clean:
	rm -f $(OUT).pdf $(OUT).docx $(OUT).html
