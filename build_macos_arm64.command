#!/bin/zsh
# Double-click on macOS to build the Apple Silicon Demo, install, and launch.

set -euo pipefail

on_exit() {
  local exit_code=$?
  trap - EXIT
  if (( exit_code != 0 )); then
    printf '\n构建或安装失败（退出码：%s）。请查看上方错误信息。\n' "$exit_code" >&2
    if [[ -t 0 ]]; then
      printf '按回车键关闭窗口...'
      read -r || true
    fi
  fi
}
trap on_exit EXIT

cd "${0:A:h}"

if ! command -v python3 >/dev/null 2>&1; then
  print -u2 '未找到 python3。请先安装 Python 3。'
  exit 1
fi

print '正在构建 macOS arm64 Demo，生成 DMG，并安装到「应用程序」...'
python3 scripts/package_macos_arm64.py --install --replace --open "$@"
if [[ " ${*:-} " != *' --help '* && " ${*:-} " != *' -h '* ]]; then
  print '\n完成：DMG 已输出到 dist/macos，应用已安装并启动。'
fi
