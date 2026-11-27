# Releases

`releases/next.md` is the next release. A pull request that adds or changes it releases its merge commit: the push to
main starts `.github/workflows/release.yml`, which waits until the self-test gate passed on that commit, creates the
release and moves the major tag. Every consumer on `@v1` runs the release at its next run, with no change and no CI
run in the consumer (docs/baseline.md, *Versions*). A pull request that does not touch the file releases nothing;
changing it (even only a typo) is a release.

The file: the first line is the title (Czech, without the version; a leading `#` is dropped), the rest are the
release notes (Czech, like the existing releases).

**The version is counted**, from the latest release `v*.*.*`:

- the commits since that release decide (conventional commits, merge commits not counted): any `feat…:` is a minor
  release (1.3.1 → 1.4.0), otherwise a patch release (→ 1.3.2);
- the first line may start with `patch:` or `minor:` to decide it instead, e.g. `patch: Oprava výpisu nálezů`;
- a breaking change (`…!:` or `BREAKING CHANGE`, or `major:`) is never released automatically: it is v2, a new major
  tag that consumers move to in a pull request.

By hand (Actions → release → Run workflow): `release` releases the current `releases/next.md` at the head of main (when
the automatic run could not), `rollback: x.y.z` moves the major tag back to that release
(`gh workflow run release.yml -f release=true`, `gh workflow run release.yml -f rollback=1.3.0`). The notes of past
releases are on GitHub (Releases). `scripts/release.sh status` shows the releases, where the major tag points and the
ref every consumer calls.
