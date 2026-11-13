# Consumers

Every repository that calls `baseline.yml`, with the version it pins. **This list is maintained by hand and must stay
current** (see [CLAUDE.md](../CLAUDE.md)): it is how a release is rolled out and how a fix reaches every consumer.

Last checked: **2026-11-13** (code search, see below). Current release: **v1.1.1**.

| Repository | Workflow | Pin | Runner (`runs-on`) | DefectDojo product |
|---|---|---|---|---|
| `expertni-sluzby/municipality-database` | `.github/workflows/security.yml` | v1.1.1 (`79ef441`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/svethrist` | `.github/workflows/security.yml` | v1.1.1 (`79ef441`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/svethrist-premium-profil-baseline` | `.github/workflows/security.yml` | v1.1.1 (`79ef441`) | ARC `["self-hosted", "linux"]` | `premium-profil` |
| `expertni-sluzby/es-cluster-dashboard` | `.github/workflows/security.yml` | v1.1.1 (`79ef441`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/svethrist-database-toolkit` | `.github/workflows/security.yml` | v1.1.1 (`79ef441`) | ARC `["self-hosted", "linux"]` | `svethrist-database-toolkit` |
| `expertni-sluzby/es-libraries` | `.github/workflows/security.yml` | v1.1.1 (`79ef441`) | GitHub-hosted (default) | repository name |
| `expertni-sluzby/orion-roadmap` | `.github/workflows/security.yml` | v1.1.1 (`79ef441`) | GitHub-hosted (default) | repository name |
| `letco-ai/letco-monorepo` | `.github/workflows/security-baseline.yml` | v1.1.1 (`79ef441`) | ARC `["self-hosted", "linux"]` | `letco-monorepo` (type `letco-ai`) |

All eight are private repositories, and all eight pin v1.1.1 since 2026-11-13: svethrist adopted the baseline at v1.1.1 (#9 here); the others moved in premium-profil #276, es-cluster-dashboard #22, svethrist-database-toolkit #16, es-libraries #265, orion-roadmap #3, letco-monorepo #1369 and municipality-database #17.

## Checking the list

The search covers every repository the signed-in account can read, in any organization:

```bash
gh search code "security-baseline/.github/workflows/baseline.yml" --json repository,path \
  --jq '.[] | "\(.repository.nameWithOwner) \(.path)"' | sort -u | grep -v '^expertni-sluzby/security-baseline '
```

Code search can lag behind a fresh push and misses repositories the account cannot read, so a new consumer is added
here when it adopts the baseline, not only when the search finds it. The pin of each consumer is the `@<sha> # v<x.y.z>` of
its workflow file.
