#!/bin/sh
# 打印用于文档同步的 diff 基线；无可比较基线时打印空行（调用方回退工作区）。
set -eu

head_sha=$(git rev-parse HEAD)

for base in origin/HEAD origin/main origin/master main master; do
  git rev-parse --verify --quiet "$base" >/dev/null 2>&1 || continue
  base_sha=$(git rev-parse "$base")
  [ "$base_sha" = "$head_sha" ] && continue   # 当前就在基线上，无差异可比
  echo "$base...HEAD"
  exit 0
done

echo ""
