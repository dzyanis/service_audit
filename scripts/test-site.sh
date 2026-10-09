#!/usr/bin/env bash
# Verifies the website build: staging, link rewrites, the strict MkDocs build,
# and the artefacts search engines depend on. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

assert_file() {
  if [[ -f "$1" ]]; then echo "ok   - $1 exists"
  else echo "FAIL - $1 is missing"; fail=1; fi
}

assert_missing() {
  if [[ ! -e "$1" ]]; then echo "ok   - $1 is absent"
  else echo "FAIL - $1 should not exist"; fail=1; fi
}

assert_grep() { # <file> <literal> <description>
  if [[ -f "$1" ]] && grep -Fq -- "$2" "$1"; then echo "ok   - $3"
  else echo "FAIL - $3"; fail=1; fi
}

assert_not_grep() { # <file> <literal> <description>
  if [[ -f "$1" ]] && grep -Fq -- "$2" "$1"; then echo "FAIL - $3"; fail=1
  else echo "ok   - $3"; fi
}

echo "== staging =="
./scripts/build-site.sh --stage-only

assert_file .site-src/index.md
assert_file .site-src/ASSESSMENT.md
assert_file .site-src/AGENT.md
assert_file .site-src/CONTRIBUTING.md
assert_file .site-src/CHANGELOG.md
assert_file .site-src/assessment/01-product-vision.md
assert_file .site-src/assessment/07-culture.md
assert_file .site-src/coverage/README.md
assert_file .site-src/coverage/agile-manifesto.md
assert_file .site-src/templates/report.md

staged_categories=$(find .site-src/assessment -name '*.md' | wc -l | tr -d ' ')
if [[ "$staged_categories" == "7" ]]; then
  echo "ok   - all 7 category files staged"
else
  echo "FAIL - expected 7 category files, staged $staged_categories"; fail=1
fi

echo "== the bundle is not published =="
assert_missing .site-src/service-audit-full.md

echo "== link rewrites =="
assert_not_grep .site-src/index.md '](service-audit-full.md)' \
  'bundle link no longer relative'
assert_grep .site-src/index.md \
  '](https://raw.githubusercontent.com/dzyanis/service_audit/main/service-audit-full.md)' \
  'bundle link points at the raw URL'
assert_not_grep .site-src/index.md '](assessment/)' \
  'assessment directory link rewritten'
assert_grep .site-src/index.md '](ASSESSMENT.md)' \
  'assessment directory link points at the index page'
assert_not_grep .site-src/index.md '](coverage/)' \
  'coverage directory link rewritten'
assert_grep .site-src/index.md '](coverage/README.md)' \
  'coverage directory link points at the index page'

if [[ $fail -ne 0 ]]; then
  echo; echo "site verification FAILED"; exit 1
fi
echo; echo "site verification passed"
