#!/usr/bin/env bash
# Builds the public website from the Markdown in this repository. Content is
# staged into .site-src/ and built from there, so no tracked file is ever
# modified. Pass --stage-only to stage without running MkDocs.
# Run from anywhere; output lands in site/.
set -euo pipefail
cd "$(dirname "$0")/.."

stage=".site-src"
raw_base="https://raw.githubusercontent.com/srce/service_audit/main"

rm -rf "$stage"
mkdir -p "$stage/assessment" "$stage/coverage" "$stage/templates"

# Relative paths are preserved so that every existing link between these files
# keeps resolving with no rewriting. MkDocs turns a .md link target into that
# page's URL by itself.
cp ASSESSMENT.md AGENT.md CONTRIBUTING.md CHANGELOG.md "$stage/"
cp assessment/*.md "$stage/assessment/"
cp coverage/*.md "$stage/coverage/"
cp templates/report.md "$stage/templates/"
cp site-assets/robots.txt "$stage/"

# README.md becomes the homepage. That rename, plus leaving the generated
# single-file bundle out of the site, breaks exactly three links. Rewrite only
# those:
#   1. service-audit-full.md duplicates every category page, so it is not
#      published. Point at its raw URL, which is what the curl command
#      immediately below that link already uses.
#   2. and 3. directory listings render on github.com but have no static-site
#      equivalent, so point at each section's index page instead.
sed -e "s#](service-audit-full.md)#](${raw_base}/service-audit-full.md)#" \
    -e 's#](assessment/)#](ASSESSMENT.md)#' \
    -e 's#](coverage/)#](coverage/README.md)#' \
    README.md > "$stage/index.md"

echo "staged $(find "$stage" -name '*.md' | wc -l | tr -d ' ') pages into $stage/"

if [[ "${1:-}" == "--stage-only" ]]; then
  exit 0
fi

mkdocs build --strict
echo "built site/"
