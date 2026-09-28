#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bridge_dir="$repo_root/example/web/provider_bridge"
node_modules_dir="$bridge_dir/node_modules"
staging_dir="$repo_root/.dart_tool/provider-bridge-build"

npm --prefix "$bridge_dir" run build

mkdir -p "$staging_dir"
if [[ -e "$staging_dir/node_modules" ]]; then
  echo "Cannot build Web: stale provider bridge staging directory exists." >&2
  exit 1
fi

restore_node_modules() {
  if [[ -e "$staging_dir/node_modules" ]]; then
    mv "$staging_dir/node_modules" "$node_modules_dir"
  fi
}
trap restore_node_modules EXIT INT TERM

mv "$node_modules_dir" "$staging_dir/node_modules"
(
  cd "$repo_root/example"
  flutter build web "$@"
)
