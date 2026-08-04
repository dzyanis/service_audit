# GitHub Pages Docs Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the assessment as a static, Google-indexable website at `https://srce.github.io/service_audit/`, built from the Markdown already in the repository.

**Architecture:** A bash script stages the published Markdown into a gitignored `.site-src/` directory, preserving relative paths so existing `.md` links resolve untouched. MkDocs Material builds that staging directory into `site/`. A GitHub Actions workflow runs the build on every push and pull request, and deploys to Pages from `main`.

**Tech Stack:** bash, MkDocs, mkdocs-material, GitHub Actions.

## Global Constraints

- **No tracked `.md` file may be modified by the site build.** `AGENT.md`, `scripts/build-bundle.sh`, and the documented `curl` workflow all consume these files directly. All site transformations happen on copies inside `.site-src/`.
- **Only `.gitignore` is modified.** Every other change is a new file.
- **Site URL is exactly** `https://srce.github.io/service_audit/` (trailing slash included).
- **`service-audit-full.md` is never staged or published.** It duplicates every category page and would split ranking signal.
- **Heading anchors must match GitHub's slug algorithm**, including the double dash produced by stripping `&`. Six existing cross-references depend on this.
- **Bash scripts follow the existing convention** in `scripts/build-bundle.sh`: `#!/usr/bin/env bash`, `set -euo pipefail`, `cd "$(dirname "$0")/.."`, a leading comment block explaining the file's purpose.
- **Prose in new files avoids em dashes.**

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/build-site.sh` | Stage Markdown into `.site-src/`, apply the three link rewrites, invoke MkDocs. |
| `scripts/test-site.sh` | Verify staging, rewrites, strict build, and SEO artefacts. |
| `mkdocs.yml` | Nav, theme, GitHub-compatible slugifier, link validation, SEO metadata. |
| `requirements-docs.txt` | Exact pins for the build toolchain. |
| `site-assets/robots.txt` | Crawler policy and sitemap location, copied to the site root. |
| `.github/workflows/site.yml` | Build on push and PR, deploy to Pages from `main`. |
| `.gitignore` | Ignore `.site-src/` and `site/`. |

---

### Task 1: Staging script and link rewrites

Produces the staged content tree. No MkDocs involved yet, so this task is testable on its own.

**Files:**
- Create: `scripts/build-site.sh`
- Create: `scripts/test-site.sh`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: `scripts/build-site.sh --stage-only` populates `.site-src/` and exits 0 without running MkDocs. Task 2 relies on this flag and on `.site-src/` being the MkDocs `docs_dir`. `scripts/test-site.sh` defines shell helpers `assert_file`, `assert_missing`, `assert_grep`, `assert_not_grep`, which Task 2 extends.

- [ ] **Step 1: Write the failing test**

Create `scripts/test-site.sh`:

```bash
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
  '](https://raw.githubusercontent.com/srce/service_audit/main/service-audit-full.md)' \
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
```

Make it executable:

```bash
chmod +x scripts/test-site.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./scripts/test-site.sh`

Expected: FAIL. The script aborts on `./scripts/build-site.sh --stage-only` with `No such file or directory`, because `build-site.sh` does not exist yet.

- [ ] **Step 3: Write the staging script**

Create `scripts/build-site.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x scripts/build-site.sh
```

- [ ] **Step 4: Add the build outputs to .gitignore**

Append to `.gitignore`, after the existing "AI-agent scratch directories" block:

```
# Website build
.site-src/
site/
```

- [ ] **Step 5: Create the robots.txt that staging copies**

The staging script copies `site-assets/robots.txt`, so it must exist for Step 6 to pass. Create `site-assets/robots.txt`:

```
User-agent: *
Allow: /

Sitemap: https://srce.github.io/service_audit/sitemap.xml
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `./scripts/test-site.sh`

Expected: PASS. Every line prefixed `ok`, ending with `site verification passed`. The MkDocs build is not reached because the test uses `--stage-only`.

- [ ] **Step 7: Commit**

```bash
git add scripts/build-site.sh scripts/test-site.sh site-assets/robots.txt .gitignore
git commit -m "Stage site content without touching tracked files

README.md becomes the homepage and the generated bundle stays out of the
site, which breaks three links. Rewrite exactly those on the staged copies.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: MkDocs configuration and strict build

Turns the staged tree into a built site with correct anchors, nav, and SEO artefacts.

**Files:**
- Create: `mkdocs.yml`
- Create: `requirements-docs.txt`
- Modify: `scripts/test-site.sh` (append build assertions before the final `fail` check)

**Interfaces:**
- Consumes: `.site-src/` from Task 1, and `scripts/build-site.sh` without `--stage-only`.
- Produces: `site/` containing `index.html`, `sitemap.xml`, `robots.txt`, and per-page directories such as `site/assessment/04-code-quality/index.html`. Task 3 uploads `site/` as the Pages artifact.

- [ ] **Step 1: Install the toolchain and pin it**

Local Python is 3.9. Use a virtual environment so nothing global changes:

```bash
python3 -m venv .venv
.venv/bin/pip install --quiet --upgrade pip
.venv/bin/pip install --quiet mkdocs-material
.venv/bin/pip freeze | grep -Ei '^(mkdocs|mkdocs-material|pymdown-extensions)==' > requirements-docs.txt
cat requirements-docs.txt
```

This writes exact pins rather than guessed version numbers, satisfying the spec's requirement that a Material release cannot break a deploy unannounced.

Add `.venv/` to `.gitignore` under the existing "Website build" block.

For the rest of this task, run MkDocs as `.venv/bin/mkdocs`. To let `build-site.sh` find it, prepend the venv to `PATH` in your shell: `export PATH="$PWD/.venv/bin:$PATH"`.

- [ ] **Step 2: Write the failing test**

In `scripts/test-site.sh`, insert the following immediately **before** the final `if [[ $fail -ne 0 ]]` block:

```bash
echo "== strict build =="
./scripts/build-site.sh

assert_file site/index.html
assert_file site/sitemap.xml
assert_file site/robots.txt
assert_file site/assessment/04-code-quality/index.html
assert_file site/coverage/agile-manifesto/index.html

echo "== search engine artefacts =="
assert_grep site/sitemap.xml 'https://srce.github.io/service_audit/' \
  'sitemap uses the canonical site URL'
assert_grep site/index.html \
  '<link rel="canonical" href="https://srce.github.io/service_audit/"' \
  'homepage declares a canonical URL'
assert_grep site/index.html 'name="description"' \
  'homepage carries a meta description'
assert_grep site/robots.txt 'Sitemap: https://srce.github.io/service_audit/sitemap.xml' \
  'robots.txt advertises the sitemap'
assert_grep site/assessment/01-product-vision/index.html \
  '<title>1. Product &amp; Vision' \
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
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `./scripts/test-site.sh`

Expected: FAIL. Staging assertions pass, then `./scripts/build-site.sh` aborts because `mkdocs build --strict` cannot find `mkdocs.yml`: `Config file 'mkdocs.yml' does not exist.`

- [ ] **Step 4: Write the MkDocs configuration**

Create `mkdocs.yml`:

```yaml
site_name: Software Project Maturity Assessment
site_url: https://srce.github.io/service_audit/
site_description: >-
  A structured framework for auditing the maturity of a software project. The
  team sets its own bar for each engineering practice, measures where it stands
  today, and turns the gap between the two into a scored improvement roadmap.
site_author: srce
repo_url: https://github.com/srce/service_audit
repo_name: srce/service_audit
edit_uri: ""
copyright: Licensed CC BY 4.0

docs_dir: .site-src
site_dir: site

theme:
  name: material
  features:
    - navigation.sections
    - navigation.top
    - toc.follow
    - search.suggest
    - search.highlight
    - content.code.copy
  palette:
    - media: "(prefers-color-scheme: light)"
      scheme: default
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      toggle:
        icon: material/brightness-4
        name: Switch to light mode

plugins:
  - search

markdown_extensions:
  - tables
  - attr_list
  - admonition
  # GitHub's slug algorithm, not Python-Markdown's. Six existing
  # cross-references use anchors such as #414-dependency-security--updates,
  # where the double dash is what GitHub leaves behind after stripping the "&".
  # The default slugifier collapses that to one dash and silently breaks them.
  # case: lower is required; without it the original capitalisation survives.
  - toc:
      permalink: true
      slugify: !!python/object/apply:pymdownx.slugs.slugify {kwds: {case: lower}}

validation:
  links:
    anchors: warn
    unrecognized_links: warn
  nav:
    omitted_files: warn

nav:
  - Home: index.md
  - The Assessment:
      - Overview and scoring: ASSESSMENT.md
      - 1. Product & Vision: assessment/01-product-vision.md
      - 2. Processes & Collaboration: assessment/02-processes-collaboration.md
      - 3. Architecture & Systems Design: assessment/03-architecture-design.md
      - 4. Code & Quality: assessment/04-code-quality.md
      - 5. Engineering Practices & Delivery: assessment/05-practices-delivery.md
      - 6. Security & Compliance: assessment/06-security-compliance.md
      - 7. Culture & External Factors: assessment/07-culture.md
  - Framework coverage:
      - Overview: coverage/README.md
      - The Joel Test: coverage/joel-test.md
      - The Agile Manifesto: coverage/agile-manifesto.md
      - The Twelve-Factor Methodology: coverage/twelve-factor.md
      - OWASP SAMM: coverage/opensamm.md
      - ISO 25010: coverage/iso-25010.md
  - Running it:
      - With an LLM agent: AGENT.md
      - Report template: templates/report.md
  - Project:
      - Contributing: CONTRIBUTING.md
      - Changelog: CHANGELOG.md
```

`validation` settings combined with `--strict` are what make a broken link or a
broken anchor fail the build instead of shipping a 404.

- [ ] **Step 5: Run the test to verify it passes**

Run: `./scripts/test-site.sh`

Expected: PASS, ending with `site verification passed`.

If the anchor assertions fail, the slugifier line is wrong: confirm it is
`!!python/object/apply:pymdownx.slugs.slugify {kwds: {case: lower}}` and not the
`!!python/name:` form, which takes no arguments and therefore preserves case.

If `nav.omitted_files` reports a file, it was staged but left out of `nav`. Add
it to `nav` rather than removing it from staging.

- [ ] **Step 6: Look at the site**

```bash
.venv/bin/mkdocs serve
```

Open `http://127.0.0.1:8000/`, confirm the homepage renders, the nav shows all
four sections, search returns results for "dependency", and dark mode toggles.
Stop the server with Ctrl-C.

- [ ] **Step 7: Commit**

```bash
git add mkdocs.yml requirements-docs.txt scripts/test-site.sh .gitignore
git commit -m "Build the staged content into an indexable site

Uses GitHub's slug algorithm so the six existing cross-references that rely
on double-dash anchors keep resolving, and so anchors stay identical between
github.com and the website.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Continuous deployment to GitHub Pages

**Files:**
- Create: `.github/workflows/site.yml`

**Interfaces:**
- Consumes: `requirements-docs.txt`, `scripts/test-site.sh`, and the `site/` directory produced by Task 2.
- Produces: a published site at `https://srce.github.io/service_audit/`.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/site.yml`:

```yaml
name: Site

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: requirements-docs.txt

      - name: Install the build toolchain
        run: pip install -r requirements-docs.txt

      - name: Build and verify the site
        run: ./scripts/test-site.sh

      # The Markdown files are consumed directly by AGENT.md, build-bundle.sh
      # and the documented curl command, so the site build must never rewrite
      # them in place. This check lives here rather than in the script so that
      # running the build locally with work in progress does not fail.
      - name: Verify no tracked file was modified
        run: git diff --exit-code

      - uses: actions/upload-pages-artifact@v3
        with:
          path: site

  deploy:
    needs: build
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: Verify the workflow parses**

```bash
python3 -c "import sys,yaml; yaml.safe_load(open('.github/workflows/site.yml')); print('workflow YAML is valid')"
```

Expected: `workflow YAML is valid`. If PyYAML is missing, use `.venv/bin/python` instead.

- [ ] **Step 3: Confirm the build is reproducible from a clean tree**

```bash
rm -rf .site-src site
./scripts/test-site.sh
```

Expected: PASS. This is the same sequence CI runs.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/site.yml
git commit -m "Build the site on every change and deploy from main

Pull requests build without deploying, so a broken link fails review rather
than reaching the published site.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Hand the manual steps to the repository owner**

These cannot be done from the workflow and must be reported, not silently skipped:

1. Push the branch and merge to `main`.
2. GitHub: Settings > Pages > Build and deployment > Source: **GitHub Actions**. Without this the deploy job fails.
3. Confirm the site loads at `https://srce.github.io/service_audit/`.
4. Google Search Console: add `https://srce.github.io/service_audit/` as a URL-prefix property, verify it, and submit `sitemap.xml`. Indexing takes days to weeks.

---

### Task 4: Point the README at the website

Readers arriving from GitHub should find the site, and the site should be the URL people share.

**Files:**
- Modify: `README.md:1-5` (add one line after the spec version)

**Interfaces:**
- Consumes: the deployed site from Task 3.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Confirm the change is safe for the bundle**

`scripts/build-bundle.sh` reads the spec version out of `README.md` with
`sed -n 's/.*Spec version: \([0-9.]*\).*/\1/p'` and does not otherwise include
README content. Adding a line below that one cannot affect the bundle. Verify:

```bash
./scripts/build-bundle.sh && git diff --stat service-audit-full.md
```

Expected: the script reports the spec version, and `git diff --stat` prints
nothing, meaning the regenerated bundle is byte-identical.

- [ ] **Step 2: Add the link**

In `README.md`, immediately after the `**Spec version: 0.1.1**` line, insert a
blank line and:

```markdown
Read it on the web: **<https://srce.github.io/service_audit/>**
```

- [ ] **Step 3: Verify the site still builds**

Run: `./scripts/test-site.sh`

Expected: PASS. The new line contains an absolute link, which the staging
rewrites do not touch.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Link the README at the published site

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Self-review notes

Checked against the spec:

- Hard constraint (no tracked file modified): enforced by `git diff
  --exit-code` in CI only, deliberately not in `test-site.sh`. Putting it in
  the script would make a local run fail whenever the tree has unrelated work
  in progress, including Task 4's own README edit.
- Staging table, exclusions, and the three link rewrites: Task 1.
- GitHub-compatible slugifier and the six anchor-dependent links: Task 2, with
  three anchors asserted directly.
- SEO artefacts (`site_url`, sitemap, canonical, robots.txt, per-page titles,
  static markup): Task 2 assertions.
- Nav structure: Task 2 `mkdocs.yml`.
- Deployment, PR-only builds, pinned dependencies: Task 3.
- Manual owner steps (Pages source, Search Console): Task 3 Step 5.
