#!/usr/bin/env bash
# Releases normally happen on GitHub: a pull request changes releases/next.md and release.yml releases the merge
# (docs/baseline.md, Versions). This script shows the state (status) and is an admin's fallback for release and
# rollback when Actions cannot do it (only admins and the release App create v* tags and move v1). Needs gh, git, jq.
#
#   scripts/release.sh status
#       releases, where the major tag points, the ref every consumer calls
#   scripts/release.sh release <x.y.z> <notes.md> "<title>" [--dry-run] [--yes]
#       release the head of origin/main as vX.Y.Z (notes in Czech, title without the version), move vX to it
#   scripts/release.sh rollback <x.y.z> [--dry-run] [--yes]
#       move the major tag back to an existing release
#
# Nothing is changed with --dry-run. Without --yes the script asks before it creates or moves a tag.
set -euo pipefail

REPO=expertni-sluzby/security-baseline
WORKFLOW=.github/workflows/baseline.yml
GATE_CHECK="baseline / gate"

die() { echo "release.sh: $*" >&2; exit 1; }
say() { echo "== $*"; }

DRY=false
YES=false
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=true ;;
    --yes) YES=true ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

for t in gh git jq; do command -v "$t" >/dev/null || die "missing $t"; done
cd "$(git rev-parse --show-toplevel)"
origin=$(git remote get-url origin)
case "$origin" in
  *"$REPO"|*"$REPO".git) ;;
  *) die "origin is $origin, not $REPO" ;;
esac

confirm() {
  $DRY && { echo "(dry run: not done)"; return 1; }
  $YES && return 0
  read -r -p "$1 [y/N] " answer
  [ "$answer" = y ] || [ "$answer" = Y ]
}

fetch() { git fetch -q --force --tags origin; }

commit_of() { git rev-parse -q --verify "refs/tags/$1^{commit}" 2>/dev/null || true; }

# The commit a remote tag points at (the peeled ^{} line of an annotated tag comes last).
remote_tag() { git ls-remote origin "refs/tags/$1" "refs/tags/$1^{}" | awk 'END { print $1 }'; }

# The ref every consumer calls: code search (as docs/consumers.md describes), then the workflow file of each hit.
consumers() {
  local hits repo path ref
  hits=$(gh search code "security-baseline/$WORKFLOW" --json repository,path \
    --jq '.[] | "\(.repository.nameWithOwner) \(.path)"' | sort -u | grep -v "^$REPO " | grep '\.github/workflows/' || true)
  [ -n "$hits" ] || { echo "  (code search found no consumer)"; return 0; }
  while read -r repo path; do
    ref=$(gh api "repos/$repo/contents/$path" --jq .content 2>/dev/null | base64 -d 2>/dev/null \
      | grep -o "security-baseline/$WORKFLOW@[^ ]*" | head -1 | sed 's/.*@//' || true)
    printf '  %-55s %s\n' "$repo" "${ref:-?}"
  done <<<"$hits"
}

latest_release() { git tag -l 'v*.*.*' | sort -V | tail -1; }

status() {
  fetch
  say "releases (newest first)"
  git tag -l 'v*.*.*' | sort -V | tail -5 | tac | while read -r t; do echo "  $t $(commit_of "$t" | cut -c1-7)"; done
  say "major tags"
  for m in $(git tag -l 'v[0-9]*' | grep -E '^v[0-9]+$'); do
    local c rel
    c=$(remote_tag "$m")
    rel=$(git tag --points-at "$c" -l 'v*.*.*' | sort -V | tail -1)
    echo "  $m -> ${c:0:7} (${rel:-no release at this commit})"
  done
  say "consumers (ref they call)"
  consumers
}

gate_passed() { # <sha>: the self-test gate of this commit succeeded
  gh api "repos/$REPO/commits/$1/check-runs?per_page=100" \
    --jq "[.check_runs[] | select(.name == \"$GATE_CHECK\" and .conclusion == \"success\")] | length > 0" | grep -qx true
}

move_major() { # <major> <sha>
  local major=$1 sha=$2
  if ! gh api "repos/$REPO/rulesets" --jq '.[].name' | grep -qx major-tags; then
    die "ruleset major-tags is missing; it must protect refs/tags/$major before the tag moves"
  fi
  local covered
  covered=$(gh api "repos/$REPO/rulesets/$(gh api "repos/$REPO/rulesets" --jq '.[] | select(.name == "major-tags") | .id')" \
    --jq '.conditions.ref_name.include | index("refs/tags/'"$major"'") != null')
  [ "$covered" = true ] || die "ruleset major-tags does not include refs/tags/$major; add it first (a new major is v2: docs/baseline.md, Versions)"
  git push -q --force origin "$sha:refs/tags/$major"
  [ "$(remote_tag "$major")" = "$sha" ] || die "$major did not move to $sha"
  echo "  $major -> ${sha:0:7}"
}

release() {
  local ver=${1:-} notes=${2:-} title=${3:-}
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version x.y.z expected, got '$ver'"
  [ -s "$notes" ] || die "notes file '$notes' is missing or empty"
  [ -n "$title" ] || die "title expected"
  local tag="v$ver" major="v${ver%%.*}" sha latest
  if ! git diff --quiet || ! git diff --cached --quiet; then die "the working tree has changes; run it from a clean checkout"; fi
  fetch
  sha=$(git rev-parse origin/main)
  [ -z "$(commit_of "$tag")" ] || die "$tag exists already"
  latest=$(latest_release)
  if [ -n "$latest" ] && [ "$(printf '%s\n%s\n' "$latest" "$tag" | sort -V | tail -1)" != "$tag" ]; then
    die "$tag is not newer than $latest"
  fi
  gate_passed "$sha" || die "the self-test gate of origin/main ${sha:0:7} has not passed (yet); wait for it or fix main"
  say "release $tag at origin/main ${sha:0:7} (previous release $latest), then move $major"
  git log --oneline "${latest:+$latest..}$sha" | sed 's/^/  /' | head -20
  confirm "create $tag and move $major to ${sha:0:7}?" || exit 0
  gh release create "$tag" --repo "$REPO" --target "$sha" --title "$tag — $title" --notes-file "$notes" >/dev/null
  fetch
  [ "$(commit_of "$tag")" = "$sha" ] || die "$tag was not created at $sha"
  echo "  $tag -> ${sha:0:7} ($(gh release view "$tag" --repo "$REPO" --json url --jq .url))"
  move_major "$major" "$sha"
  say "consumers (ref they call); a consumer that pins a SHA does not get $tag until it moves its pin"
  consumers
}

rollback() {
  local ver=${1:-}
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version x.y.z expected, got '$ver'"
  local tag="v$ver" major="v${ver%%.*}" sha
  fetch
  sha=$(commit_of "$tag")
  [ -n "$sha" ] || die "$tag does not exist"
  say "move $major from $(remote_tag "$major" | cut -c1-7) back to $tag ${sha:0:7}"
  confirm "move $major to $tag?" || exit 0
  move_major "$major" "$sha"
}

case "${1:-}" in
  status) status ;;
  release) shift; release "$@" ;;
  rollback) shift; rollback "$@" ;;
  *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
