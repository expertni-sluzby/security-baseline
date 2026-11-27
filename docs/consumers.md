# Consumers

Every repository that calls `baseline.yml`, with the version it pins. **This list is maintained by hand and must stay
current** (see [CLAUDE.md](../CLAUDE.md)): it is how a release is rolled out and how a fix reaches every consumer.

Last checked: **2026-11-27** (code search, see below). Current release: **v1.2.0**.

| Repository | Workflow | Pin | Runner (`runs-on`) | DefectDojo product |
|---|---|---|---|---|
| `expertni-sluzby/municipality-database` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/svethrist` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/svethrist-premium-profil-baseline` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | `premium-profil` |
| `expertni-sluzby/es-cluster-dashboard` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/svethrist-database-toolkit` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | `svethrist-database-toolkit` |
| `expertni-sluzby/es-libraries` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/orion-roadmap` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/gitops-clusters` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/owl-deployment-platform` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | repository name |
| `expertni-sluzby/owl-management-portal` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | repository name |
| `letco-ai/letco-monorepo` | `.github/workflows/security-baseline.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | `letco-monorepo` (type `letco-ai`) |
| `letco-ai/letco-security` | `.github/workflows/security.yml` | v1.2.0 (`a662442`) | ARC `["self-hosted", "linux"]` | `letco-security` (type `letco-ai`) |

All twelve are private repositories, run on the ARC runners and pin v1.2.0 since 2026-11-27: es-libraries#273 and orion-roadmap#4 (both moved from GitHub-hosted to ARC), gitops-clusters#39, es-cluster-dashboard#54, svethrist-database-toolkit#166, svethrist-premium-profil-baseline#362, municipality-database#87, owl-deployment-platform#348, owl-management-portal#57 (both also keep `.github/workflows/security.yml` out of the image build's paths), svethrist#752, letco-ai/letco-security#204 and letco-ai/letco-monorepo `fbc54b0` (a direct push to `develop`, approved by the owner). Before that, all twelve pinned v1.1.1. Eight of them since 2026-11-13: svethrist adopted the baseline at v1.1.1 (#9 here); the others moved in premium-profil #276, es-cluster-dashboard #22, svethrist-database-toolkit #16, es-libraries #265, orion-roadmap #3, letco-monorepo #1369 and municipality-database #17. `letco-ai/letco-security` adopted it on 2026-11-16 in letco-ai/letco-security#1. `expertni-sluzby/gitops-clusters` adopted it at v1.1.1 on 2026-11-20. `expertni-sluzby/owl-deployment-platform` and `expertni-sluzby/owl-management-portal` adopted it at v1.1.1 on 2026-11-21 (owl-deployment-platform#332, owl-management-portal#43), both with `enforce: true`.

## Checking the list

The search covers every repository the signed-in account can read, in any organization:

```bash
gh search code "security-baseline/.github/workflows/baseline.yml" --json repository,path \
  --jq '.[] | "\(.repository.nameWithOwner) \(.path)"' | sort -u | grep -v '^expertni-sluzby/security-baseline '
```

Code search can lag behind a fresh push and misses repositories the account cannot read, so a new consumer is added
here when it adopts the baseline, not only when the search finds it. The pin of each consumer is the `@<sha> # v<x.y.z>` of
its workflow file.
