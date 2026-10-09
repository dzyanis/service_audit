# Software Project Maturity Assessment

**Spec version: 0.1.1**

A structured framework for auditing the maturity of a software project. The team first sets its own bar: how important each engineering practice is for this project. Then it measures where it currently stands against that bar. The gap between the two becomes a scored, prioritized improvement roadmap. The audit can be conducted manually by an assessor, or an LLM agent can take the assessor's role: it interviews the team and produces the report.

## Quick start

**With a coding agent (Claude Code, Cursor, etc.):**

```bash
git clone https://github.com/dzyanis/service_audit.git
cd service_audit
claude "Read AGENT.md and run the assessment interview with me"
```

To assess a different repository, run the same `claude` command from that
repository and point it at this checkout's `AGENT.md`.

**With a web chat (claude.ai, ChatGPT, etc.):** attach [service-audit-full.md](service-audit-full.md), the whole assessment in one file, to a conversation and say "Run this assessment with me." To download it directly:

```bash
curl -O https://raw.githubusercontent.com/dzyanis/service_audit/main/service-audit-full.md
```

The agent interviews your team one question at a time and produces a report you can keep next to your repo and compare against future runs.

## Philosophy

Engineering leaders and the people writing the code rarely have a shared way to talk about the state of a project. One side asks about dates and risk, the other answers in tech debt and missing tests, and neither has evidence the other can act on. This assessment is meant to be that shared interface: one artifact both sides can point at.

That works because the team sets its own bar before it measures anything.

**For engineers**, the bar is theirs. A low score on something the team deliberately deprioritized is a decision, not a failure. What remains is a structured case for work they already know is needed, plus the blind spots a checklist surfaces that nobody thought to ask about. It also forces the team to agree on what "good" means here, instead of everyone carrying a private standard.

**For engineering leaders**, it is a read on the project that does not require sitting in every standup or pulling it out of people one by one. Re-run it with the same spec version and progress becomes visible rather than inferred.

This is a self-assessment, not a grade. It measures a project against the bar that project's own team set, and nothing else.

## How to use it

1. Read [ASSESSMENT.md](ASSESSMENT.md): the index, scoring scales, and links to the seven category files in [assessment/](assessment/).
2. Run the assessment:
   - **Manually:** walk the categories with your team and fill in [templates/report.md](templates/report.md).
   - **With an LLM:** give your AI assistant [AGENT.md](AGENT.md) and the `assessment/` files; it interviews the team one question at a time and produces the report.
3. Re-run it periodically (e.g. every 6–12 months) with the same spec version to track progress.

## Versioning

The spec follows [SemVer](https://semver.org/): MAJOR versions change or remove items (reports stop being comparable), MINOR versions add items or questions, PATCH versions fix wording. See [CHANGELOG.md](CHANGELOG.md). Reports record the spec version they were produced with.

After changing any assessment content, regenerate the single-file bundle with `./scripts/build-bundle.sh`.

## Related frameworks

How this assessment covers each framework is documented point-by-point in [coverage/](coverage/).

- [The Joel Test: 12 Steps to Better Code](https://www.joelonsoftware.com/2000/08/09/the-joel-test-12-steps-to-better-code/) ([coverage](coverage/joel-test.md))
- [The Agile Manifesto](https://agilemanifesto.org/) ([coverage](coverage/agile-manifesto.md))
- [The Twelve-Factor Methodology](https://www.12factor.net/) ([coverage](coverage/twelve-factor.md))
- [OWASP SAMM (OpenSAMM)](https://owaspsamm.org/) ([coverage](coverage/opensamm.md))
- [ISO 25010 Software Quality Model](https://iso25000.com/en/iso-25000-standards/iso-25010) ([coverage](coverage/iso-25010.md))

Planned mappings (DORA/Accelerate, AWS Well-Architected, CMMI, SPACE) are tracked in [the `area:coverage` issues](https://github.com/dzyanis/service_audit/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acoverage).

## Roadmap

Planned work lives in [GitHub issues](https://github.com/dzyanis/service_audit/issues),
grouped by area label and by release milestone:

- [`area:adoption`](https://github.com/dzyanis/service_audit/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aadoption): worked examples, a lite profile, scoring tools
- [`area:content`](https://github.com/dzyanis/service_audit/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acontent): item wording and overlap, plus new items and questions for the next release
- [`area:coverage`](https://github.com/dzyanis/service_audit/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acoverage): mappings to other frameworks
- [`area:tooling`](https://github.com/dzyanis/service_audit/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Atooling): scripts, CI, releases, repo admin

Issues labelled `spec-change` alter the assessment items themselves and ship as a
MINOR or MAJOR release. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to propose
one.

## License

[Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/legalcode). See [LICENSE](LICENSE).
