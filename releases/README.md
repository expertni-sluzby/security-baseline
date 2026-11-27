# Releases

A pull request that adds `releases/vX.Y.Z.md` releases its merge commit as vX.Y.Z and moves the major tag vX to it
(`.github/workflows/release.yml`, called by `self-test.yml` once the baseline passed on main). Every consumer on
`@vX` runs the release at its next run, with no change and no CI run in the consumer (docs/baseline.md, *Versions*).

The file: the first line is the title (Czech, without the version; a leading `#` is dropped), the rest are the
release notes (Czech, like the existing releases). The version is newer than the latest release; one release per
pull request. A pull request without such a file releases nothing.

Rollback: Actions → release → Run workflow with `rollback: x.y.z` (`gh workflow run release.yml -f rollback=1.3.0`)
moves the major tag back to that release. `scripts/release.sh status` shows the releases, where the major tag points
and the ref every consumer calls.
