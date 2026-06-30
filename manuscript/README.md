# Manuscript

The paper, one Markdown file per section, built to PDF/DOCX/HTML with Pandoc.
**This directory is what gets submitted** (rendered to the journal's format);
`../code/` is not.

## Sections (build order)

| File | Section |
|------|---------|
| `00_abstract.md`      | Abstract |
| `01_introduction.md`  | Introduction |
| `02_related_work.md`  | Related Work (literature review) |
| `03_data.md`          | Data |
| `04_methods.md`       | Methods |
| `05_results.md`       | Results |
| `06_conclusion.md`    | Conclusion |

`metadata.yaml` carries title/authors/keywords. `references.bib` is the single
bibliography. `figures/` holds generated figures.

## Citations and reference style

Citations use Pandoc syntax (`[@key]` parenthetical, `@key` narrative) and
resolve from `references.bib`. **The reference style is chosen at build time by
swapping a CSL file**, so APA, Chicago, or Vancouver requires no edits to the
prose or the bib:

```bash
make styles                       # download common CSL styles into csl/
make STYLE=apa                    # APA (default)
make STYLE=chicago-author-date
make STYLE=vancouver
make docx STYLE=apa               # Word, for co-authors / journal upload
```

## Reference integrity (do this before submitting)

Every entry in `references.bib` must resolve to a real work. The checker
confirms each against Crossref (by DOI) or a live URL and fails on anything it
can't verify, guarding against hallucinated or mis-keyed citations:

```bash
python ../code/scripts/verify_references.py references.bib
```

## Requirements

Pandoc ≥ 3 with `--citeproc` (bundled in recent Pandoc), a LaTeX engine for PDF
(e.g. TinyTeX / MacTeX), and `curl` for `make styles`.
