#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
skill_dir="$repo_root/skills/update-docs-from-diff"
script="$skill_dir/scripts/resolve-base.sh"
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/agent-skills-check.XXXXXX")
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_eq() {
    expected=$1
    actual=$2
    label=$3
    [ "$expected" = "$actual" ] || fail "$label: expected '$expected', got '$actual'"
    printf 'ok - %s\n' "$label"
}

new_repo() {
    repo=$1
    branch=$2
    git init -q "$repo"
    git -C "$repo" config user.name test
    git -C "$repo" config user.email test@example.invalid
    git -C "$repo" checkout -q -b "$branch"
    git -C "$repo" commit -q --allow-empty -m base
}

printf '%s\n' '== Agent Skills validation =='
npx -y skills-ref@0.1.5 validate "$skill_dir"

printf '%s\n' '== SKILL.md contract =='
for required in \
    '当前会话上下文' \
    'conversation context' \
    '项目规则未加载' \
    '无 diff 模式' \
    'user-approved' \
    '隐私硬边界'
do
    grep -q "$required" "$skill_dir/SKILL.md" || fail "SKILL.md is missing: $required"
    printf 'ok - SKILL.md contains %s\n' "$required"
done

printf '%s\n' '== Shell syntax =='
sh -n "$script"
printf '%s\n' 'ok - resolve-base.sh'

printf '%s\n' '== resolve-base.sh =='

# origin/HEAD has priority over other candidates.
repo="$tmp_root/origin-head"
new_repo "$repo" main
git -C "$repo" branch -q feature
git -C "$repo" checkout -q feature
git -C "$repo" commit -q --allow-empty -m feature
git -C "$repo" update-ref refs/remotes/origin/main main
git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
assert_eq 'origin/HEAD...HEAD' "$(cd "$repo" && sh "$script")" 'origin/HEAD candidate'

# Removing origin/HEAD falls back to origin/main.
git -C "$repo" symbolic-ref -d refs/remotes/origin/HEAD
assert_eq 'origin/main...HEAD' "$(cd "$repo" && sh "$script")" 'origin/main fallback'

# origin/master is used when origin/main and origin/HEAD are absent.
repo="$tmp_root/origin-master"
new_repo "$repo" master
git -C "$repo" checkout -q -b feature
git -C "$repo" commit -q --allow-empty -m feature
git -C "$repo" update-ref refs/remotes/origin/master master
assert_eq 'origin/master...HEAD' "$(cd "$repo" && sh "$script")" 'origin/master candidate'

# Local main is used when no remote candidate exists.
repo="$tmp_root/local-main"
new_repo "$repo" main
git -C "$repo" checkout -q -b feature
git -C "$repo" commit -q --allow-empty -m feature
assert_eq 'main...HEAD' "$(cd "$repo" && sh "$script")" 'local main candidate'

# Local master is used when local main is absent.
repo="$tmp_root/local-master"
new_repo "$repo" master
git -C "$repo" checkout -q -b feature
git -C "$repo" commit -q --allow-empty -m feature
assert_eq 'master...HEAD' "$(cd "$repo" && sh "$script")" 'local master candidate'

# A candidate equal to HEAD is skipped.
repo="$tmp_root/same-head"
new_repo "$repo" feature
git -C "$repo" branch main
git -C "$repo" branch master
assert_eq '' "$(cd "$repo" && sh "$script")" 'same-HEAD candidates skipped'

# No candidate prints an empty line.
repo="$tmp_root/no-candidate"
new_repo "$repo" feature
assert_eq '' "$(cd "$repo" && sh "$script")" 'empty fallback'

printf '%s\n' '== npx skills discovery =='
discovery=$(npx -y skills@1.7.0 add "$repo_root" --list)
printf '%s\n' "$discovery" | grep -q 'update-docs-from-diff' || fail 'skill was not discovered'
printf '%s\n' 'ok - update-docs-from-diff discovered'

printf '%s\n' 'All checks passed.'
