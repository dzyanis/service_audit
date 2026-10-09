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
  # A missing file is a failure here, not a pass: the literal is absent, but
  # not for the reason the assertion is checking for.
  if [[ ! -f "$1" ]]; then echo "FAIL - $3 ($1 is missing)"; fail=1
  elif grep -Fq -- "$2" "$1"; then echo "FAIL - $3"; fail=1
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

echo "== strict build =="
./scripts/build-site.sh

assert_file site/index.html
assert_file site/sitemap.xml
assert_file site/robots.txt
assert_file site/assessment/04-code-quality/index.html
assert_file site/coverage/agile-manifesto/index.html

echo "== search engine artefacts =="
assert_grep site/sitemap.xml 'https://dzyanis.github.io/service_audit/' \
  'sitemap uses the canonical site URL'
assert_grep site/index.html \
  '<link rel="canonical" href="https://dzyanis.github.io/service_audit/"' \
  'homepage declares a canonical URL'
assert_grep site/index.html 'name="description"' \
  'homepage carries a meta description'
assert_grep site/robots.txt 'Sitemap: https://dzyanis.github.io/service_audit/sitemap.xml' \
  'robots.txt advertises the sitemap'
assert_grep site/assessment/01-product-vision/index.html \
  '<title>1. Product & Vision' \
  'category page has a descriptive title'

echo "== content is in the served HTML, not rendered by JavaScript =="
assert_grep site/assessment/01-product-vision/index.html \
  'could they describe the product and its core users in two sentences' \
  'assessment prose is present in the static markup'

echo "== GitHub-compatible heading anchors =="
assert_grep site/assessment/04-code-quality/index.html \
  'id="414-dependency-security--updates"' \
  '4.14 anchor keeps the double dash GitHub produces'
assert_grep site/assessment/06-security-compliance/index.html \
  'id="610-compliance--data-retention-policies"' \
  '6.10 anchor keeps the double dash GitHub produces'
assert_grep site/assessment/01-product-vision/index.html \
  'id="18-compliance--legal-requirements"' \
  '1.8 anchor keeps the double dash GitHub produces'

if [[ $fail -ne 0 ]]; then
  echo; echo "site verification FAILED"; exit 1
fi
echo; echo "site verification passed"
