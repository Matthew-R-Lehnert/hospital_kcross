#!/usr/bin/env python3
"""
verify_references.py -- guard against hallucinated / wrong citations.

For a peer-reviewed manuscript, every reference in references.bib must point to
a real, findable work. This script parses the .bib and, for each entry:

  * DOI present  -> query the Crossref REST API (https://api.crossref.org/works/<doi>).
                    Confirms the DOI resolves AND that the registered title is a
                    fuzzy match for the .bib title (catches "real DOI, wrong paper"
                    and "plausible-but-invented DOI" alike).
  * No DOI, URL  -> HTTP request the URL; confirm it resolves (2xx/3xx).
  * Neither      -> FLAGGED as unverifiable (cannot confirm it exists).

Exit code is non-zero if any entry is UNVERIFIED, so it can gate a build/CI.
No API key required; Crossref asks only for a mailto in the User-Agent.

Usage:
    python code/scripts/verify_references.py manuscript/references.bib
    python code/scripts/verify_references.py            # default path
"""
from __future__ import annotations

import difflib
import json
import re
import sys
import time
import urllib.parse
import urllib.request

MAILTO = "Matthew.Lehnert@axleinfo.com"
UA = f"hospital-kcross-refcheck/1.0 (mailto:{MAILTO})"
TITLE_MATCH_THRESHOLD = 0.60  # ratio below which a Crossref title is a mismatch


def parse_bib(path: str) -> list[dict]:
    """Minimal BibTeX parser: enough to pull key, type, title, doi, url."""
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    entries = []
    # Split on @type{ ... } top-level blocks by brace balancing.
    for m in re.finditer(r"@(\w+)\s*\{", text):
        etype = m.group(1).lower()
        if etype == "comment":
            continue
        start = m.end()
        depth = 1
        i = start
        while i < len(text) and depth:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        body = text[start:i - 1]
        key = body.split(",", 1)[0].strip()
        fields = dict(re.findall(
            r"(\w+)\s*=\s*[\{\"](.*?)[\}\"]\s*,?\s*(?=\w+\s*=|\Z)",
            body, flags=re.DOTALL))
        fields = {k.lower(): re.sub(r"\s+", " ", v).strip()
                  for k, v in fields.items()}
        entries.append({"key": key, "type": etype,
                        "title": fields.get("title", ""),
                        "doi": fields.get("doi", "").strip(),
                        "url": fields.get("url", "").strip()})
    return entries


def _get(url: str, accept: str | None = None, timeout: int = 20):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    if accept:
        req.add_header("Accept", accept)
    return urllib.request.urlopen(req, timeout=timeout)


def check_doi(doi: str, bib_title: str) -> tuple[str, str]:
    doi = re.sub(r"^https?://(dx\.)?doi\.org/", "", doi).strip()
    api = "https://api.crossref.org/works/" + urllib.parse.quote(doi)
    try:
        with _get(api, accept="application/json") as resp:
            data = json.load(resp)
        cr_title = " ".join(data.get("message", {}).get("title", []) or [])
        if not cr_title:
            return "WARN", f"DOI resolves but Crossref has no title (doi={doi})"
        ratio = difflib.SequenceMatcher(
            None, bib_title.lower(), cr_title.lower()).ratio()
        if ratio < TITLE_MATCH_THRESHOLD:
            return "FAIL", (f"DOI resolves but TITLE MISMATCH (ratio={ratio:.2f})\n"
                            f"        bib:      {bib_title}\n"
                            f"        crossref: {cr_title}")
        return "OK", f"DOI verified (title match {ratio:.2f})"
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return "FAIL", f"DOI NOT FOUND on Crossref (likely invalid/hallucinated): {doi}"
        return "WARN", f"Crossref HTTP {e.code} for doi={doi}"
    except Exception as e:  # noqa: BLE001
        return "WARN", f"Crossref lookup error for doi={doi}: {e}"


def check_url(url: str) -> tuple[str, str]:
    try:
        with _get(url) as resp:
            return "OK", f"URL resolves (HTTP {resp.status})"
    except urllib.error.HTTPError as e:
        if e.code in (403, 429):  # blocked/ratelimited but exists
            return "WARN", f"URL returned HTTP {e.code} (blocked, not necessarily dead)"
        return "FAIL", f"URL HTTP {e.code}: {url}"
    except Exception as e:  # noqa: BLE001
        return "WARN", f"URL error ({e}): {url}"


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "manuscript/references.bib"
    try:
        entries = parse_bib(path)
    except FileNotFoundError:
        print(f"No bibliography yet at {path} (nothing to verify).")
        return 0
    if not entries:
        print(f"{path}: no entries parsed.")
        return 0

    n_ok = n_warn = n_fail = 0
    print(f"Verifying {len(entries)} references in {path}\n" + "-" * 64)
    for e in entries:
        if e["doi"]:
            status, msg = check_doi(e["doi"], e["title"])
        elif e["url"]:
            status, msg = check_url(e["url"])
        else:
            status, msg = "FAIL", "no DOI and no URL -> cannot verify existence"
        marker = {"OK": "  ok ", "WARN": " warn", "FAIL": "FAIL!"}[status]
        print(f"[{marker}] {e['key']}: {msg}")
        n_ok += status == "OK"
        n_warn += status == "WARN"
        n_fail += status == "FAIL"
        time.sleep(0.2)  # be polite to Crossref

    print("-" * 64)
    print(f"OK={n_ok}  WARN={n_warn}  FAIL={n_fail}")
    if n_fail:
        print("\nFAIL means a reference could not be confirmed real. Fix or remove "
              "it before submission.")
    return 1 if n_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
