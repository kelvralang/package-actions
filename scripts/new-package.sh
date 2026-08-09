#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
usage: new-package.sh [options] NAME

Create and customize an independent Mog package repository, validate it, and
open the initial setup pull request.

Options:
  --native                 Use moglang/native-package-template.
  --org ORG                Destination GitHub organization (default: moglang).
  --runtime-ref REF        Runtime ref placed in workflow callers (default: main).
  --visibility VALUE       public or private (default: public).
  --mog PATH               Existing Mog interpreter used for validation.
  -h, --help               Show this help.
USAGE
}

KIND=source
ORG=moglang
RUNTIME_REF=main
VISIBILITY=public
MOG_RUNTIME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --native) KIND=native; shift ;;
        --org) ORG="${2:?--org requires a value}"; shift 2 ;;
        --runtime-ref) RUNTIME_REF="${2:?--runtime-ref requires a value}"; shift 2 ;;
        --visibility) VISIBILITY="${2:?--visibility requires a value}"; shift 2 ;;
        --mog) MOG_RUNTIME="${2:?--mog requires a value}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
        *)
            if [[ -n "${NAME:-}" ]]; then
                echo "only one package name is allowed" >&2
                exit 2
            fi
            NAME="$1"
            shift
            ;;
    esac
done

NAME="${NAME:-}"
if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
    echo "NAME must match ^[a-z][a-z0-9-]*$" >&2
    exit 2
fi
if [[ ! "$ORG" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
    echo "invalid GitHub organization: $ORG" >&2
    exit 2
fi
if [[ "$VISIBILITY" != public && "$VISIBILITY" != private ]]; then
    echo "--visibility must be public or private" >&2
    exit 2
fi

command -v gh >/dev/null || { echo "gh is required" >&2; exit 1; }
command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
command -v cmake >/dev/null || { echo "cmake is required" >&2; exit 1; }
if [[ -n "$MOG_RUNTIME" ]]; then
    MOG_RUNTIME="$(cd "$(dirname "$MOG_RUNTIME")" && pwd)/$(basename "$MOG_RUNTIME")"
    [[ -x "$MOG_RUNTIME" ]] || { echo "Mog interpreter is not executable: $MOG_RUNTIME" >&2; exit 1; }
fi

if [[ "$KIND" == native ]]; then
    TEMPLATE=moglang/native-package-template
    TEMPLATE_NAME=native-package-template
    TEMPLATE_IDENTIFIER=native_package_template
else
    TEMPLATE=moglang/package-template
    TEMPLATE_NAME=package-template
    TEMPLATE_IDENTIFIER=package_template
fi

IDENTIFIER="${NAME//-/_}"
REPOSITORY="$ORG/$NAME"
SETUP_BRANCH="setup/$NAME"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Creating $REPOSITORY from $TEMPLATE"
gh repo create "$REPOSITORY" --template "$TEMPLATE" "--$VISIBILITY"
gh repo clone "$REPOSITORY" "$WORK/package"
cd "$WORK/package"
git switch -c "$SETUP_BRANCH"

export BOOTSTRAP_OLD_NAME="$TEMPLATE_NAME"
export BOOTSTRAP_NEW_NAME="$NAME"
export BOOTSTRAP_OLD_IDENTIFIER="$TEMPLATE_IDENTIFIER"
export BOOTSTRAP_NEW_IDENTIFIER="$IDENTIFIER"
export BOOTSTRAP_ORG="$ORG"
export BOOTSTRAP_RUNTIME_REF="$RUNTIME_REF"
export BOOTSTRAP_NEW_VARIABLE="$IDENTIFIER"

while IFS= read -r -d '' file; do
    perl -0pi -e '
      s/\Q$ENV{BOOTSTRAP_OLD_IDENTIFIER}\E/$ENV{BOOTSTRAP_NEW_IDENTIFIER}/g;
      s/\Q$ENV{BOOTSTRAP_OLD_NAME}\E/$ENV{BOOTSTRAP_NEW_NAME}/g;
      s/\bpackageTemplate\b/$ENV{BOOTSTRAP_NEW_VARIABLE}/g;
      s{github\.com/moglang/\Q$ENV{BOOTSTRAP_NEW_NAME}\E}{github.com/$ENV{BOOTSTRAP_ORG}/$ENV{BOOTSTRAP_NEW_NAME}}g;
      s{runtime_ref: main}{runtime_ref: $ENV{BOOTSTRAP_RUNTIME_REF}}g;
      s{repository: moglang/mog\n          ref: main}{repository: moglang/mog\n          ref: $ENV{BOOTSTRAP_RUNTIME_REF}}g;
    ' "$file"
done < <(git grep -Ilz -e "$TEMPLATE_NAME" -e "$TEMPLATE_IDENTIFIER" -e 'ref: main')

if [[ -z "$MOG_RUNTIME" ]]; then
    if command -v mog >/dev/null 2>&1; then
        MOG_RUNTIME="$(command -v mog)"
    else
        echo "Building Mog main for local validation"
        gh repo clone moglang/mog "$WORK/mog"
        cmake -S "$WORK/mog" -B "$WORK/mog/build" -DCMAKE_BUILD_TYPE=Release
        cmake --build "$WORK/mog/build" --parallel
        MOG_RUNTIME="$WORK/mog/build/interpreter"
    fi
fi
MOG_RUNTIME="$(cd "$(dirname "$MOG_RUNTIME")" && pwd)/$(basename "$MOG_RUNTIME")"

if [[ "$KIND" == native ]]; then
    ./tests/test_native_package.sh "$MOG_RUNTIME" .
else
    STAGE="$WORK/stage/github.com/$ORG/$NAME"
    PROJECT="$WORK/project"
    mkdir -p "$STAGE" "$PROJECT"
    rsync -a --exclude .git ./ "$STAGE/"
    "$MOG_RUNTIME" validate-package "$STAGE"
    VERSION="$(sed -n 's/^version = "\([^"]*\)"/\1/p' mog.toml | head -n 1)"
    sed -e "s|__PACKAGE_NAME__|$NAME|g" \
        -e "s|__PACKAGE_MODULE__|github.com/$ORG/$NAME|g" \
        -e "s|__PACKAGE_VERSION__|$VERSION|g" \
        -e "s|__PACKAGE_PATH__|$STAGE|g" \
        .github/package-test.toml.in > "$PROJECT/mog.toml"
    (
        cd "$PROJECT"
        MOG_CACHE_DIR="$WORK/cache" "$MOG_RUNTIME" run "$STAGE/tests/main.mog"
    )
fi

gh repo edit "$REPOSITORY" \
    --enable-issues --enable-projects --enable-wiki \
    --enable-discussions=false --delete-branch-on-merge \
    --enable-merge-commit --enable-rebase-merge --enable-squash-merge

printf '%s\n' '{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}' | gh api --method PUT "repos/$REPOSITORY/branches/main/protection" --input - >/dev/null

git add --all
git commit -m "Customize $NAME package template"
git push --set-upstream origin "$SETUP_BRANCH"
gh pr create --repo "$REPOSITORY" --base main --head "$SETUP_BRANCH" \
    --title "Customize $NAME package template" \
    --body "Initial package identity and workflow configuration generated from \`$TEMPLATE\`. Local template validation passed."
