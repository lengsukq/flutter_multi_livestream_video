# Flutter Realtime SDK 发布准备（pub.dev）

> 截至 2026-10-14：**仅准备文档，尚未发布**。不能把仓库已经能编译/运行解释为满足 pub.dev 的发布条件。这个文件是维护者的发布清单，不是自动发布脚本。

## 1. 对外产品与包边界

本仓库有 **45 个 Flutter/Dart package**：44 个项目 package（以 `scripts/sdk_packages.json` 为准）及 1 个单独管理的 vendored `flutter_webrtc`。仓库根目录 `flutter_realtime_workspace`、`example/`、`demo-server/` 都**不是**要上传的主 SDK。

| 使用者需求 | 公开依赖入口 | 备注 |
| --- | --- | --- |
| 仅用功能，独立控制 UI | `flutter_realtime_sdk` + 所选 `flutter_realtime_provider_*` | facade 只导出 Runtime，不自动引入任何媒体/IM 厂商 |
| 自己装配会议/直播控件 | 上述包 + `flutter_realtime_sdk_ui` | UI 独立；业务会话不随 Widget 卸载而释放 |
| 只要设计系统 | `flutter_realtime_design_ui` | 独立 Flutter 组件，不依赖会议、IM、云服务 |
| 教学业务 / 直播互动 | `flutter_realtime_classroom_preset` / `flutter_realtime_live_preset` | `featurePlugins` 显式注册，权威服务端必需 |
| 仅使用底层合同 | `flutter_realtime_media_core` / `flutter_realtime_chat_core` 等 | 不是一键接入；由宿主注册 Adapter |

供应商显式注册入口：`createLivekitProvider()`、`createAgoraProvider()`、`createTrtcProvider()`、`createArtcProvider()`、`createAwsProvider()`，以及对应的 Agora / IVS / Tencent Chat bundle。AWS 对外供应商 ID 为 `aws`，在 Meeting 使用 Chime，在 Live 使用 IVS。

**当前不允许**在 README 使用 `flutter pub add flutter_realtime_sdk` 作为已经可执行的安装步骤；这些包还未上架。单仓开发的可靠用法请看 [根 README](../README.md) 的本地 path 示例。

## 2. 仓库审计发现的发布阻断项

1. **全项目使用 `publish_to: none`**（不包括 vendored `flutter_webrtc`）。这是防止误发布的保护，首发前只应在受控 release 分支针对目标包移除。
2. **依赖仍为本地 `path:`**。pub.dev 不接收包含 path 依赖的 package（包括 `dev_dependencies`）。发布前必须把目标包依赖图中的内部包按顺序发布、再替换为匹配的 hosted version constraints。不要直接一次性批量改成本地路径失效的版本。
3. **包文档尚未齐备**。部分包缺 README，大多数缺各自版本的 `CHANGELOG.md`；版本历史不应复用根目录旧 Chime plugin 的 CHANGELOG。每个拟发布包均需独立 `README.md`、`CHANGELOG.md` 和 `LICENSE`。
4. **许可证 / 再分发检查**。仓库根 MIT 文件的版权标记为原始 Chime 作者 OnePlusDream；新增代码、第三方 Flutter WebRTC fork、内嵌 JS SDK、官方原生依赖与 assets 各自的再分发授权必须逐一核对。不能仅凭项目根 MIT 推断全部第三方二进制可上传 pub.dev。
5. **平台承诺需实测**。目前有 SDK driver 声明、自动化测试和部分平台构建，但不代表所有 Provider、所有平台真实音视频/屏幕共享/录制 E2E 均通过。尤其 ARTC macOS 官方 framework 未随库发放；Windows native 需要 Windows runner；Web JS 可构建不等于 Wasm-ready。
6. **实际交付文档与截图**。新包的 pub.dev 页面只能保证展示其自身上传的文件。package README 尽量使用 **GitHub 绝对 URL** 指向根仓库的 `doc/`、`example/`；验证图片、链接与示例代码在 GitHub、pub.dev 两处均可访问。
7. **版本与命名核验**。首发前检查 pub.dev 同名 package 是否已有所有者，并决定一个统一的 0.x 版本策略；不得尝试覆盖别人拥有的 package 名称。

详情见官方 [pub.dev 发布要求](https://dart.dev/tools/pub/publishing)、[path 依赖限制](https://dart.dev/tools/pub/dependencies) 和 [dry-run 命令](https://dart.dev/tools/pub/cmd/pub-lish)。

## 3. 推荐分阶段发布（按实际依赖拓扑调整）

**第一阶段：可独立拆出的公共合同/设计层。** 从 `flutter_realtime_foundation`、`flutter_realtime_interaction_core`、`flutter_realtime_design_ui` 开始；再依赖其已发布版本发布 `flutter_realtime_media_core`、`flutter_realtime_chat_core`、`flutter_realtime_live_core`、`flutter_realtime_classroom_core`、`flutter_realtime_whiteboard_core` 等。发布前验证每个包的独立导入和兼容版本约束。

**第二阶段：Runtime、具体 Provider 和 UI。** 先处理底层 Adapter、原生平台插件和 Web assets，然后 `flutter_realtime_sdk_runtime`、LiveKit/Agora/TRTC/ARTC/AWS bundles、Chat bundles，再按实际依赖关系处理 Classroom/Live presets 与 `flutter_realtime_room_ui` / `flutter_realtime_sdk_ui`。**先检查依赖闭包，不保证以上文字顺序已经严格拓扑排序。**

**第三阶段：面向宿主的 facade。** 最后发布 `flutter_realtime_sdk`。应用只添加 facade 和所需 Provider / UI / Preset，编译后的依赖树不应额外带入未选用的厂商 SDK。

**暂不自动上架：** 自带 hotfix 的 `flutter_webrtc`、`flutter_aws_chime` 以及强平台绑定的 JS/native bridge。先完成版权许可、plugin 注册声明、二进制大小、最低平台版本和三方 ABI 验证；必要时改成上游已发布的依赖或另建包名。不要把示例中的 `path:` 当作可发布的 hosted 依赖。

## 4. 每个包的发布验收清单

- [ ] 明确 **public import**（`lib/<package_name>.dart`）；README 不引用 `lib/src/` 私有实现。
- [ ] `pubspec.yaml` 包名唯一、英文描述清晰、`version` 与 CHANGELOG 一致，并填写 `repository`（指向包所在 monorepo 路径）、SDK/Flutter 最低版本、平台声明。
- [ ] 本包具有准确的 README、CHANGELOG、LICENSE；分发的图片、Web JS、二进制资源已取得许可。
- [ ] 发布分支移除本包 `publish_to: none`，内部依赖均为已发布的版本约束（**包括 dev_dependencies**）。
- [ ] 使用干净 checkout、独立 pub cache 执行 `flutter pub get`，再跑静态分析、测试和必要平台 build。
- [ ] `dart pub publish --dry-run` / `flutter pub publish --dry-run` **无 error、无未解释 warning**；检查将上传的文件列表，排除 `.env`、密钥、测试账号、生成日志、临时证书以及许可证不明的模型/二进制。
- [ ] Core/Runtime/UI/Provider 核对公开 API 的语义版本与兼容性（包括宿主 Android Gradle、iOS CocoaPods/SwiftPM、macOS Entitlement、Web CSP/HTTPS、Windows native）。
- [ ] 至少一份可以由外部宿主复制的入会示例；选用不同 Provider、Chat 组合与平台的能力差异在矩阵里记录真实验收证据。
- [ ] 账号权限/组织发布者、上传顺序、版本 tag、CI release checklist、回滚与后续修补计划审核。

建议先运行仓库已有静态与测试脚本（不会上传包）：

```sh
python3 scripts/check_pub_release_readiness.py --report-only
python3 scripts/check_pub_release_readiness.py --package flutter_realtime_design_ui
python3 scripts/check_sdk_architecture.py
python3 scripts/generate_capability_matrix.py --check
python3 scripts/format_sdk.py --check
python3 scripts/check_sdk_quality.py --resolve --analyze --test
```

**本地工具链注意**：项目要求 Dart ≥ 3.12；若操作系统的 `dart --version` 仍显示 3.11.x，不要用它判断项目不兼容。使用项目要求的 Flutter（例如 Flutter 3.47 自带 Dart 3.13），纯 Dart 子包可在其目录执行 `flutter pub run test`，以 Flutter 内置的 Dart 测试。

每个包准备好 hosted dependencies 后，再进入对应目录运行**仅校验不上传**：

```sh
cd packages/flutter_realtime_design_ui
flutter pub publish --dry-run
```

**当前预期：dry-run 不满足发布条件**，因为发布保护 `publish_to: none` 尚未移除；不要使用 `--skip-validation` 绕过阻断。本次文档工作不会修改任何发布保护字段、不会使用 `dart pub publish`、不会真实上传。

2026-10-14 在原开发工作区执行 Design UI 的 `flutter pub publish --dry-run`（**未上传**）返回 exit 65；打包校验阶段还报告 pubspec 被隐藏、未检测到根 README/CHANGELOG/LICENSE，压缩包小于 1KB。源文件实际存在，`git check-ignore` 亦未匹配这些路径，因此不能简单认定是缺文件；首发前必须**单独排查打包清单**并从干净的发布分支重新验证，直到待发布清单真实包含这些文件及 `lib/`。此项和 `publish_to: none` / path 依赖一样，是未完成的发布门槛。

## 5. 安全与云录制边界

- Flutter package 内永远不包含 API Key、App Certificate、Customer Secret、AWS access key、腾讯 SecretKey、持久 UserSig 等。应用仅向信任的后端获取短期 Token / Room Join Info。
- `demo-server` 是教学参考控制面，不是生产认证、限流、账单和高可用后端。部署前应设计用户鉴权、权限校验、持久化、审计、密钥管理。
- 云录制需要厂商服务开通、对象存储、权限、费率控制以及真实设备验收。**必须单独检查异常退出时的 Stop、服务端重启后任务恢复与费用上限**；不能把模拟通过写成“所有供应商云录制已验收”。
- SDK 的云录制接口是统一合同；真正 Acquire/Start/Stop/Query 与文件下载由宿主后端负责，参见 [云录制指南](CLOUD_RECORDING.md)。

## 6. 退出条件与当前结论

**文档完善 ≠ 具备发布资格。** 当且仅当指定首发包的 path 依赖全部迁移、许可证审计完成、独立 package 示例可编译、`--dry-run` 通过并有人确认版本与目标发布账号后，再开始实际的 pub.dev 上传。此前继续使用本地 monorepo 与 Demo 进行开发/验收。
