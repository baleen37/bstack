#!/usr/bin/env bash
# apply-patch.sh — Phase 2 git-safe 적용 헬퍼
# 사용: apply-patch.sh <target-file> <patch-file> <commit-subject> <signal-snippet> <session-id>
# 동작: 외부 캐시 차단 → patch 적용 → 단일 commit
# 종료 코드: 0=적용, 10=외부 캐시 차단, 11=patch 실패, 12=dirty tree

set -euo pipefail

target="${1:?target-file required}"
patch="${2:?patch-file required}"
subject="${3:?commit-subject required}"
snippet="${4:?signal-snippet required}"
session="${5:?session-id required}"

# 1. 외부 캐시 차단
case "$target" in
    "$HOME"/.claude/plugins/cache/*)
        echo "blocked: external plugin cache cannot be modified directly" >&2
        echo "target: $target" >&2
        exit 10
        ;;
esac

# 2. dirty tree 차단 (target과 무관하게)
if [ -n "$(git status --porcelain)" ]; then
    echo "blocked: working tree is dirty. commit or stash first." >&2
    git status --short >&2
    exit 12
fi

# 3. patch 적용
if ! git apply --check "$patch" 2>/dev/null; then
    echo "blocked: patch does not apply cleanly" >&2
    git apply --check "$patch" >&2 || true
    exit 11
fi
git apply "$patch"

# 4. commit
git add "$target"
git commit -m "$(printf 'evolve: %s\n\nSignal: %s\nSession: %s\n' "$subject" "$snippet" "$session")"

# 5. 새 commit sha 출력 (메인 에이전트가 캡처)
git rev-parse --short HEAD
