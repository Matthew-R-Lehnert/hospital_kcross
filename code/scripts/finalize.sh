#!/usr/bin/env bash
# finalize.sh -- post national-run analysis: family-wise across-zone tests per
# axis and surface, then the diagnostic typology + ambient-vs-residential flips.
# Run after the Nextflow national run completes (summary.csv + *_simfuns.rds present).
#
# Usage: bash code/scripts/finalize.sh
set -euo pipefail
RS="${RS:-/Library/Frameworks/R.framework/Versions/4.4-x86_64/Resources/bin/Rscript}"
cd "$(dirname "$0")/../.."

for kind in ambient residential; do
  for layer in all beds coverage; do
    if ls "output/${kind}"/*_"${layer}"_simfuns.rds >/dev/null 2>&1; then
      echo "== family-wise: ${kind} / ${layer} =="
      "$RS" code/R/global_across_zones.R "output/${kind}" "${layer}"
    fi
  done
done

echo "== diagnostic typology =="
python3 code/scripts/typology.py
echo "done: output/typology_*.csv"
