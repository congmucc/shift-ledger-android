#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'USAGE'
Usage:
  make release VERSION=1.2.3
  make release-dry-run VERSION=1.2.3

VERSION may optionally include the leading "v". The release command is a
manual, explicit action: it does not run from a hook and it does not tag every
commit. It validates, creates an annotated tag, and pushes main plus the tag in
one git push.
USAGE
}

fail() {
  echo "release: $*" >&2
  exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

VERSION_INPUT="${1:-${VERSION:-}}"
[[ -n "$VERSION_INPUT" ]] || { usage >&2; exit 2; }

VERSION="${VERSION_INPUT#v}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
  fail "VERSION must be a semantic version such as 1.2.3 (received: $VERSION_INPUT)"

TAG="v$VERSION"
DRY_RUN="${DRY_RUN:-0}"

command -v git >/dev/null || fail "git is required"
command -v flutter >/dev/null || fail "flutter is required"
git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"

[[ "$(git branch --show-current)" == "main" ]] || \
  fail "release must be started from the main branch"
[[ -z "$(git status --porcelain)" ]] || \
  fail "working tree is not clean; commit or stash changes before releasing"

echo "Release target: $TAG"
echo "Current commit: $(git rev-parse --short HEAD)"

# Refresh the remote view before deciding whether the tag is safe to create.
git fetch --quiet origin main --tags

HEAD_SHA="$(git rev-parse HEAD)"
ORIGIN_MAIN_SHA="$(git rev-parse refs/remotes/origin/main 2>/dev/null || true)"
if [[ -n "$ORIGIN_MAIN_SHA" ]] && ! git merge-base --is-ancestor "$ORIGIN_MAIN_SHA" HEAD; then
  fail "local main is behind or has diverged from origin/main; pull/reconcile before releasing"
fi

remote_tag_lines="$(git ls-remote origin "refs/tags/$TAG" "refs/tags/$TAG^{}")"
REMOTE_TAG_SHA="$(printf '%s\n' "$remote_tag_lines" | awk -v ref="refs/tags/$TAG" '
  $2 == ref "^{}" { annotated = $1 }
  $2 == ref { lightweight = $1 }
  END {
    if (annotated != "") print annotated
    else if (lightweight != "") print lightweight
  }
')"

LOCAL_TAG_SHA="$(git rev-list -n 1 "$TAG^{commit}" 2>/dev/null || true)"
if [[ -n "$LOCAL_TAG_SHA" && "$LOCAL_TAG_SHA" != "$HEAD_SHA" ]]; then
  fail "local tag $TAG already points to $LOCAL_TAG_SHA, not HEAD $HEAD_SHA"
fi
if [[ -n "$LOCAL_TAG_SHA" ]] && [[ "$(git cat-file -t "$TAG")" != "tag" ]]; then
  fail "local tag $TAG is lightweight; refusing to rewrite it"
fi
if [[ -n "$REMOTE_TAG_SHA" && "$REMOTE_TAG_SHA" != "$HEAD_SHA" ]]; then
  fail "remote tag $TAG already points to $REMOTE_TAG_SHA, not HEAD $HEAD_SHA"
fi

# A new release must move forward. Re-running an already published release is
# still allowed so a failed network push can be retried safely.
if [[ -z "$LOCAL_TAG_SHA" && -z "$REMOTE_TAG_SHA" ]]; then
  LATEST_TAG="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)"
  if [[ -n "$LATEST_TAG" ]]; then
    LATEST_VERSION="${LATEST_TAG#v}"
    HIGHEST_VERSION="$(printf '%s\n%s\n' "$LATEST_VERSION" "$VERSION" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)"
    [[ "$HIGHEST_VERSION" == "$VERSION" && "$VERSION" != "$LATEST_VERSION" ]] || \
      fail "VERSION $VERSION must be newer than the latest tag $LATEST_TAG"
  fi
fi

if [[ -n "$REMOTE_TAG_SHA" ]]; then
  echo "Remote tag $TAG already points to this commit."
elif [[ -n "$LOCAL_TAG_SHA" ]]; then
  echo "Local annotated tag $TAG is ready to push."
else
  echo "No existing $TAG tag found."
fi

echo "Running flutter analyze..."
flutter analyze

echo "Running flutter test..."
flutter test --reporter compact

echo "Checks passed."

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run: no tag created and nothing pushed."
  if [[ -z "$REMOTE_TAG_SHA" ]]; then
    echo "Would create annotated tag $TAG and push main plus $TAG."
  else
    echo "Would verify the already-published tag $TAG; no push needed."
  fi
  exit 0
fi

if [[ -n "$REMOTE_TAG_SHA" ]]; then
  echo "Release $TAG is already published on origin; nothing to push."
  exit 0
fi

if [[ -z "$LOCAL_TAG_SHA" ]]; then
  PREVIOUS_TAG="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)"
  NOTES_FILE="$(mktemp "${TMPDIR:-/tmp}/shift-ledger-release.XXXXXX")"
  trap 'rm -f "$NOTES_FILE"' EXIT
  {
    echo "Release $TAG"
    echo
    if [[ -n "$PREVIOUS_TAG" ]]; then
      echo "Changes since $PREVIOUS_TAG:"
      git log --format='- %s (%h)' "$PREVIOUS_TAG..HEAD"
    else
      echo "Initial release."
    fi
  } > "$NOTES_FILE"
  git tag --annotate "$TAG" --file "$NOTES_FILE"
  echo "Created annotated tag $TAG."
else
  echo "Reusing existing local annotated tag $TAG."
fi

# Push the branch and tag together so a release cannot silently omit the tag.
git push origin HEAD:main "refs/tags/$TAG"
echo "Release $TAG pushed. GitHub Actions will build and publish the APK."
