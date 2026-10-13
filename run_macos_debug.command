#!/bin/zsh
# Double-click or run from Terminal. In the terminal, r = hot reload, R = restart, q = quit.
set -euo pipefail
cd "${0:A:h}"
python3 scripts/run_flutter_macos.py --debug "$@"
