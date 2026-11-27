# baseline.yml — L1 scanners

Reusable workflow implementing L1 of [PLAN.md](PLAN.md) §7.1.

## Use

```yaml
# .github/workflows/security.yml in the consumer repo
name: security
on:
  pull_request:
  push:
    branches: [main, develop]
  schedule:
    - cron: "0 3 * * *"      # nightly: full-history secret scan, fresh advisories
  workflow_dispatch:
permissions: {}
jobs:
  baseline:
    uses: expertni-sluzby/security-baseline/.github/workflows/baseline.yml@v1  # major tag: every v1.x release (see Versions)
    permissions:
      contents: read
    with:
      defectdojo-url: ${{ vars.DEFECTDOJO_URL }}
      # enforce: true          # once the backlog is triaged
      # baseline-rules: enforce  # once the baseline's own rules find nothing (see Baseline rules)
    secrets:                   # explicit, never `secrets: inherit`
      DEFECTDOJO_TOKEN: ${{ secrets.DEFECTDOJO_TOKEN }}
```

`DEFECTDOJO_URL` (variable) and `DEFECTDOJO_TOKEN` (secret) are set once per organization.
Make the `baseline / gate` check required with a branch ruleset.

## Consumers

The repositories that use this workflow and the ref each one calls: [consumers.md](consumers.md). Adopting the
baseline, changing the ref or dropping it means updating that list too.

## Versions

Consumers call the baseline through its major tag, `@v1`. Every v1.x.y release moves `v1` to the release commit, so a
release reaches every consumer at its next run (pull request, push or the nightly run), with no change and no CI run in
the consumer. The release tags `v1.x.y` never move (ruleset `release-tags-immutable`); only an admin moves `v1`
(ruleset `major-tags`). A consumer that has to stay on one release pins its commit SHA with the release in a comment,
as all consumers did before v1.3.0, and moves the pin in a pull request.

Because a v1 release reaches everyone at once, it may:

- fix, speed up or extend what is reported;
- add inputs whose defaults keep the current behaviour or make it less strict;
- add something that can newly **block** a consumer (a new rule, a stricter threshold, a new blocking scanner) only in
  a reporting mode first (as `baseline-rules: report`), and make it blocking in a later release announced in advance.

It never removes or renames an input, an output or the check `baseline / gate`: that is v2, a new tag that consumers
move to in a pull request.

**Releasing** is `scripts/release.sh release <x.y.z> <notes.md> "<title>"` (an admin; `--dry-run` shows what it would
do): it checks that the self-test gate of `origin/main` passed and that the version is newer, creates the release,
moves `v1`, opens the pull request for *Current release* in [consumers.md](consumers.md) and lists the ref every
consumer calls. `scripts/release.sh status` shows the same without changing anything.

**Rollback:** `scripts/release.sh rollback <x.y.z>` moves `v1` back to that release; consumers get it at their next
run.

zizmor reports a reusable workflow called by a tag as `unpinned-uses` (high). The baseline drops that one finding for
its own `.../baseline.yml@vN`; every other unpinned reference stays a finding.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `product` | repository name | DefectDojo product (created on first upload) |
| `product-type` | repository owner | DefectDojo product type = organization; the token can write only here |
| `defectdojo-url` | empty | empty = no upload |
| `enforce` | `false` | block on dependency / IaC / SAST / workflow findings at or above `fail-on` |
| `fail-on` | `high` | `high` or `critical` |
| `baseline-rules` | `report` | how findings of the baseline's own rules count (see *Baseline rules*): `report` lists and annotates them without blocking, `enforce` makes them block like the other findings of their scanner (Semgrep ones with `enforce` at `fail-on`, gitleaks ones on every pull request and push). Any other value fails the gate. |
| `runs-on` | `"ubuntu-24.04"` | runner of every job as JSON; `'["self-hosted", "linux"]'` runs on the organisation's ARC runners (Ubuntu 24.04, Docker in Docker) instead of paid GitHub-hosted minutes. Missing packages (python3-venv) are installed there; Harden-Runner audits only on GitHub-hosted runners. Only for private repositories: the organisation's runner group refuses public ones, which is right (a fork's pull request would run on our runner), and GitHub-hosted minutes are free for public repositories. |
| `sast-pull-request` | `diff` | what Semgrep scans on a pull request: `diff` only the files the PR changes, compared with its base, and only findings the PR introduces count; `full` the whole repository at the PR's head (see *SAST scope*) |
| `sast-push` | `off` | what Semgrep scans on a push: `off` nothing (the scheduled run scans the whole repository and is what DefectDojo records); `full` the whole repository |
| `sast-jobs` | `2` | Semgrep worker processes (`--jobs`), each about one CPU; without a limit Semgrep starts one per CPU it sees, on a shared runner node all of the node's CPUs |

## What runs

| Job | Tool | Scope | Blocks |
|---|---|---|---|
| secrets | gitleaks (the repository's `.gitleaks.toml`, then the baseline's rules), TruffleHog `--only-verified` | PR: the PR's commits · push: the pushed commits · schedule/dispatch: full history | **always** on PR/push; full-history hits are warnings; baseline-rule hits only with `baseline-rules: enforce` |
| dependencies | osv-scanner | all lockfiles, recursive; a root `osv-scanner.toml` applies to all of them | with `enforce`: CVSS ≥ 7 (≥ 9 for `critical`) |
| iac | Trivy `config` | Dockerfile, Helm, Kubernetes, Terraform | with `enforce`: HIGH/CRITICAL |
| sast | Semgrep `p/default` + the baseline's rules | PR: the changed files against the base, new findings (`sast-pull-request: diff`) · push: nothing (`sast-push: off`) · schedule/dispatch: whole repo; `.semgrepignore` respected | with `enforce`: ERROR/HIGH/CRITICAL; baseline-rule hits only with `baseline-rules: enforce` too |
| workflows | zizmor | `.github/workflows/**` | with `enforce`: high |
| defectdojo | `reimport-scan` | not on pull requests | — (fails red if DefectDojo rejects an upload) |
| gate | — | — | the one check to require; names what blocked, where the full list is and what to do (see *Reading a failed run*); a scanner job that did not finish fails it |

Each push / scheduled run updates one DefectDojo engagement per branch (`ci/<branch>`), one
test per tool; findings missing from a later run are closed. A run without a Semgrep report (a push with
`sast-push: off`) leaves the Semgrep test as it is; the scheduled run updates it. Secret findings are the exception:
a push scans only the pushed commits, so its upload adds and reopens secret findings but never
closes one; only a full-history scan (schedule, dispatch, a push without a usable base) closes
them.

A leaked secret that has been rotated stays in the git history and keeps being reported. Once it
is rotated (and only then), add its gitleaks fingerprint (`commit:file:rule:line`, in the run's
`baseline-secrets` artifact) to `.gitleaksignore` in the consumer repo; the next full-history
scan closes the finding.

A dependency advisory whose vulnerable code the consumer cannot reach is ignored in
`osv-scanner.toml` at the repository root (`[[IgnoredVulns]]` with `id`, `reason` and an
`ignoreUntil` date, after which it is reported again). osv-scanner itself reads such a file only
next to each lockfile, so the workflow passes the root one with `--config`, covering every
lockfile. An advisory that is merely inconvenient is not ignored: it is fixed, or accepted in
DefectDojo.

## Baseline rules

Rules the baseline adds to its scanners, for classes of bugs that the generic rule sets miss. They live in
[`rules/`](../rules) with their tests in [`tests/`](../tests), and the workflow checks them out from the commit of
`baseline.yml` that is running (`job.workflow_repository` at `job.workflow_sha`): a consumer that pins a commit gets
the rules of that commit, nothing newer; a consumer on `@v1` gets the rules of the release `v1` points at. If they cannot be checked out at that commit, the job fails and so does the
gate.

| Scanner | Rule ID | Severity | Finds |
|---|---|---|---|
| Semgrep (C#) | `security-baseline.framework-default-password-fallback` | ERROR | a fallback to a known framework default password: `config[...] ?? <default>`, `??=`, `GetValue(key, <default>)`, a `?:` whose condition does not name the Development environment; the default being the literal, a constant or read-only field of the same file holding it, ABP's `IdentityDataSeedContributor.AdminPasswordDefaultValue`, or a constant named as a default password (`DefaultAdminPassword`) |
| Semgrep (C#) | `security-baseline.framework-default-password-literal` | WARNING | ABP's default password as a literal in code (a constant that holds it is reported once, where it is defined; comparisons are not reported) |
| Semgrep (JSON) | `security-baseline.framework-default-password-in-appsettings` | WARNING | the default password as a value in `appsettings*.json` (not `appsettings.Development*`, `.Local*`, `.Test*`) |
| Semgrep (JSON) | `security-baseline.framework-default-password-in-production-appsettings` | ERROR | the same in `appsettings.Prod*.json` |
| gitleaks | `security-baseline-framework-default-password` | (secret) | ABP's default password anywhere in the scanned commits, except tests, the Development configuration and prose (`.md`, `.txt`, ...) |

**Known framework default passwords** are public, so no secret scanner looks for them: gitleaks and TruffleHog look for
high-entropy or verifiable secrets. The rules cover ABP Framework's default (the admin password of its identity
seeder and the client secrets of its solution templates) and ASP.NET Boilerplate's default user password; the latter
only as a fallback or an appsettings value, because it is also a common password that password dictionaries (zxcvbn)
list. The shape they catch: a seeder that takes a client secret as `configuration["...:ClientSecret"] ?? defaultPassword`, so every
environment where the key is missing gets a password anyone can look up, and keeps it.

The fix: take the secret from a managed secret (a sealed or Kubernetes Secret, a key vault); outside the Development
environment fail, or skip the client, when it is missing; keep a default only behind a Development check (inside
`if (env.IsDevelopment())`, `if (isDevelopment ...)`, or a `?:` whose condition names Development) or in
`appsettings.Development.json`. Test code is out of scope: `test/`, `tests/` and `testing/` trees, `*.Tests` (and
similar) projects, `*Tests.cs` files; so is generated C# (`*.Designer.cs`, `*ModelSnapshot.cs`, `*.g.cs`).

A spot that stays (accepted risk, a Development guard the rule does not recognise, such as an early return): a
`nosemgrep: <rule>` comment with the reason on its line (the rule name without `security-baseline.` is enough); for
gitleaks its fingerprint in `.gitleaksignore`, or `gitleaks:allow` on the line. A JSON file takes no comments: fix it,
or list the path in `.semgrepignore`.

### Rollout of a new rule

On a pull request the scanners look at the whole repository (Semgrep only with `sast-pull-request: full`), so a new
rule would block every pull request of a consumer with an old finding of its kind until that finding is fixed. Therefore:

1. A release that adds rules is a minor bump (PLAN.md §6.6). Consumers on `@v1` run the new rules at their next run
   (*Versions*), so a new rule must not block anyone at first; a consumer that pins a commit sees them in the pull
   request that moves its pin.
2. With `baseline-rules: report` (the default) the rules' findings are reported (annotations, the Summary page,
   DefectDojo) and never block. A consumer moves to the new release without fixing anything first.
3. A consumer whose run shows no baseline-rule findings, or that has fixed or accepted them, sets
   `baseline-rules: enforce`.
4. Once every consumer in [consumers.md](consumers.md) is on `enforce`, or has set `report` explicitly, a later minor
   release, announced in advance, makes `enforce` the default. From then on a new rule that can block starts as
   report-only for a release (announced), so that consumers on `@v1` see its findings before it blocks them.

### Tests

Each rule has positive and negative fixtures, run by the baseline's own workflow (self-test) with the pinned scanners:
`semgrep scan --test --config rules/semgrep/ tests/semgrep/` (annotations `ruleid:` / `ok:` in the fixtures), and
gitleaks over `tests/gitleaks/src`, whose findings must be exactly the `file:line` list in `tests/gitleaks/expected.txt`.
The self-test runs with `baseline-rules: enforce`, so this repository is held to its own rules. A rule added here
comes with its fixtures, and spells what it looks for so that its own rule file does not match it.

### SAST scope

Semgrep is the heaviest scanner: a scan of the whole repository takes minutes and one CPU per worker, and every
consumer's pull requests run it on the same shared runners. So by default:

- **Pull request** (`sast-pull-request: diff`): Semgrep scans only the files the pull request changes against its base
  (the first parent of GitHub's merge commit, `semgrep --baseline-commit`) and reports only the findings that the base
  does not have. A pull request that changes only documentation scans nothing. A finding that predates the pull request
  does not block it; the scheduled run reports it. `full` scans the whole repository at the head, as before v1.2.0.
- **Push** (`sast-push: off`): no Semgrep. `full` scans the whole repository.
- **Schedule and manual runs**: always the whole repository; these runs are what DefectDojo records. Call the baseline
  from a `schedule` trigger (as in the example above), otherwise the whole repository is never scanned.
- `sast-jobs` (2) caps Semgrep's worker processes; each takes about one CPU.

Scans of a pull request that a newer push to it has made obsolete are cancelled (`concurrency`, per job and pull
request); push, scheduled and manual runs are never cancelled.

## Reading a failed run

Only the gate turns red; the scanner jobs stay green and carry the detail. Look, in this order, at:

1. **The annotations** of the run (on a pull request also in the Checks tab). The gate names what
   blocked, with the first three findings, the threshold and the fix, e.g.
   `1 advisory at or above CVSS 7.0 in 4 lockfiles: SixLabors.ImageSharp@3.1.11 GHSA-v76p-62qx-wwq2 (CVSS 7.5, fixed in 3.2.0, 4.1.1)`.
   Each scanner job annotates its blocking findings (the first ten) on the file and line.
2. **The Summary page** of the run: a section per scanner with the full table (advisory, fixed
   version and lockfiles; check, location and resolution; rule, location and message) and the fix
   that applies, and a *Gate* section with the verdict per scanner.
3. **The artifacts** `baseline-*`: the raw reports, kept 7 days, for tooling.

On a pull request the scanners look at the whole repository at the PR's head, not only at its
changes (SAST only at the changes, unless `sast-pull-request` is `full`: *SAST scope*), so a blocking finding may
predate the PR: an advisory published yesterday blocks every branch today. Fix it in the PR, or merge the fix to the base branch and update the branch
(gating on new findings only: see *Not yet*).

| Scanner | Fix | Confirmed false positive, accepted risk |
|---|---|---|
| secrets | rotate first, then remove from the code (PLAN.md §8) | once rotated: the fingerprint in `.gitleaksignore` (above) |
| dependencies | upgrade to the fixed version the table shows | unreachable code: `osv-scanner.toml` (above); merely inconvenient: accept in DefectDojo |
| iac | as the resolution says | the check ID in `.trivyignore`, with a comment saying why |
| sast | as the rule says | `nosemgrep: <rule-id>` on the line; a path in `.semgrepignore` |
| baseline rules | as the rule says (*Baseline rules*) | `nosemgrep: <rule>` with the reason; gitleaks: the fingerprint in `.gitleaksignore` |
| workflows | as the audit says ([docs.zizmor.sh/audits](https://docs.zizmor.sh/audits/)) | `# zizmor: ignore[<audit>]` on the line |

## Supply chain

Scanners are release binaries (Semgrep: an image, pulled through the company Harbor's public proxy of Docker Hub) pinned by version and sha256 and at least
14 days old when pinned; actions are pinned by commit SHA; no third-party scanner actions;
no `${{ }}` inside `run:`. Reports are artifacts (public on a public repo): gitleaks runs with
`--redact`, TruffleHog values are replaced before upload.

## Not yet (v1.x)

More of our own rules (PLAN.md §7.1; the first ones: *Baseline rules*), Trivy image scans, SBOM, gating on *new* findings only
(today `enforce` blocks on every finding at the threshold, Semgrep on pull requests excepted (*SAST scope*) — start with
`enforce: false`),
Harden-Runner `block` mode with an egress allowlist.
