#!/usr/bin/env python3
"""
collate.py -- roll per-run *_meta.json files into one tidy summary CSV (stdout).

Usage:
    python code/scripts/collate.py output/**/*_meta.json > output/summary.csv
    python code/scripts/collate.py *_meta.json            # (inside a Nextflow task)
"""
import csv
import json
import sys

FIELDS = ["window", "pop_kind", "subset", "weight_by", "n_hospitals", "nsim",
          "r_max", "r_step", "r_capped", "frac_r_overconc", "frac_r_dispersed",
          "r_first_overconc", "lambda_floor", "runtime_sec", "epsg"]


def main(paths: list[str]) -> int:
    w = csv.DictWriter(sys.stdout, fieldnames=FIELDS, extrasaction="ignore")
    w.writeheader()
    n = 0
    for p in paths:
        try:
            w.writerow(json.load(open(p)))
            n += 1
        except Exception as e:  # noqa: BLE001
            print(f"# skip {p}: {e}", file=sys.stderr)
    print(f"# collated {n} runs", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
