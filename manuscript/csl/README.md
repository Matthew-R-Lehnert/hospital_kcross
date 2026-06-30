# Citation styles (CSL)

Citation Style Language files that control how citations and the reference list
are formatted. The manuscript's prose and `references.bib` never change — only
the CSL chosen at build time does.

These files are **not committed** (fetch them on demand):

```bash
cd ..            # manuscript/
make styles      # downloads apa, chicago-author-date, chicago-note-bibliography,
                 # vancouver, ieee, elsevier-harvard into this folder
```

Then build in any style: `make STYLE=apa`, `make STYLE=vancouver`, etc.

Need a journal-specific style? Find it in the official repository
<https://github.com/citation-style-language/styles>, drop the `<style>.csl`
here, and run `make STYLE=<style>`.
