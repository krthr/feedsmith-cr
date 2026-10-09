# Domain Docs

This repo uses a single-context layout: `GLOSSARY.md` at the repo root and ADRs under `docs/adr/`.

## Before exploring the codebase

- Read the root `GLOSSARY.md` for domain vocabulary.
- Read ADRs under `docs/adr/` that touch the area you are about to work in.

If these files do not exist, proceed silently. The `/domain-modeling` skill creates them lazily when terms or decisions are resolved.

## File structure

```text
/
├── GLOSSARY.md
├── docs/
│   └── adr/
│       └── 0001-<decision-slug>.md
└── src/
```

## Use the glossary's vocabulary

When naming a domain concept in an issue title, refactor proposal, hypothesis, or test name, use the term defined in `GLOSSARY.md`.

If a concept is missing, check whether an existing term already covers it. Note a real vocabulary gap for `/domain-modeling`.

## Flag ADR conflicts

If a proposal contradicts an existing ADR, identify the ADR and explain why the decision should be reconsidered.
