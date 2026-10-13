# SDK Clean Code governance

The migration permits public API changes and migrates every repository caller.
It preserves provider versions and HTTP contracts. No commit, push, tag or
publication is part of this work. Third-party code and generated artifacts are
not responsibility-refactor targets.

## Evidence and progress

| Stage | Status | Evidence |
| --- | --- | --- |
| A: baseline and quality rules | in progress | Pre-change 40-package analysis, architecture and declarations passed; Runtime 53 tests passed; backend typecheck passed. Full tests running. |
| B: lifecycle and recording contracts | pending | |
| C: optional composition and typed extensions | pending | |
| D: domain and UI responsibilities | pending | |
| E: providers, Web and native bridges | pending | |
| F: Demo, backend and Dashboard | pending | |
| G: documentation and Git distribution | pending | |

Implementation, tests, platform builds, real-provider calls, remote pixels and
cloud cleanup are separate evidence categories. Never infer resource release
from a timeout or a successfully completed local dispose operation.

## Responsibility review

Length triggers inspection, not a pass/fail rule. Review complete Dart
libraries including `part` files, not only their entry files. Every owned
module must name its public contract, mutable state owner, resource owner,
failure channel and independent reason to change. Refactor UI that owns domain
lifecycles, routing that executes business policy, adapters that mix protocol
decoding with capture, and shared private state concealed by `part` extraction.

The priority inventory is the approved plan: room and classroom libraries,
classroom tools, meeting dock, Pre-Join, Demo entry, Chat/Live components,
provider sessions, Web factories and bridge, AWS desktop/IVS iOS plugins,
Android effects source, Live contracts, backend application/routes and Dashboard.
