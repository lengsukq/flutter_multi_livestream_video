#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bridge_dir="$repo_root/tool/provider_web_assets"

npm --prefix "$bridge_dir" ci
npm --prefix "$bridge_dir" run build
