# AGENTS.md — flutter_multi_livestream_video

> 随 git 跟踪的项目级提示词。本地私有 prompts / skills 不进 git（见 `.gitignore`）。

## 1. AWS 凭证（强制）

只认 profile 名字，不碰明文 Key。

| profile | 用途 |
|---|---|
| `chime-demo` | **默认**，日常 Demo / CLI / 后端调用 |
| `lengxiaoying599` | root，仅用于建删 IAM 用户，不跑 Demo |
| `oxpecker` | 与本项目无关，不要混用 |

- Chime 控制面 `us-east-1`、媒体面 `ap-southeast-1`，命令带 `--profile chime-demo`。
- `chime-demo` 只有录制相关最小权限，`iam:*` 报 `AccessDenied` 是预期结果，不是故障。
- 真人进会才计费；验证完 `delete-meeting` 清干净，`get-meeting` 返回 `NotFoundException` 才算删掉。
- AK/SK 永不进 Flutter 包、永不进 git、永不贴到聊天记录。
- 排障：`InvalidClientTokenId` = Key 在云端已不存在；`SignatureDoesNotMatch` 才是 Secret 错。

## 2. 项目约定

- `packages/` 是产品（provider-neutral SDK），`example/` + `demo-server/` 只是展示场：
  不在 Demo 沉淀业务逻辑，Demo 只用公开 API。
- 内部分包全部 `publish_to: none`，唯一对外发布包是 `flutter_realtime_sdk`。
- 包清单以 `scripts/sdk_packages.json` 为准，新增包必须登记。
- 依赖方向由 `scripts/check_sdk_architecture.py` 强制：core 不 import 厂商 SDK，
  runtime 零 UI、零厂商依赖，`flutter_realtime_sdk` 只依赖 runtime，
  provider 与 UI 由宿主显式注册，不跨包 import 别人的 `src/`。
- 交互语义：Transient event 走 RTC Data、best-effort、`sender` 不可信；
  需要授权/计费/持久化的动作必须走注入的 `controlPlane`；
  Snapshot 的 revision 只是失效通知，倒计时用服务端 `endsAt`。
- `demo-server` 是唯一后端入口，provider 由后端选择，Flutter 永不指定。
- 验收边界：本地 analyze / 单测通过不等于真机、多端、云端验收；没实际跑过的不标完成。

## 3. 工作方式

- 小改动直接做：不写调研报告、不列长篇方案，需要的信息边做边查。
- 只有发布、删数据、跨多包重构这类不可逆或影响面大的事，才先讲清方案再动手。
- analyze 报错就是红线；改完在受影响包内跑 analyze + test，合入前再跑根目录门禁脚本。
