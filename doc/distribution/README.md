# Git 分发准备

四份 `*.pubspec.fragment.yaml` 展示最小媒体、独立 Chat、轻量 UI 和完整组合。发布前把所有 ref 替换为同一个已审查、已推送、不可变的 40 位 commit SHA；LiveKit 的 WebRTC hotfix 使用同一 ref。不要将占位符或浮动分支当作发布版本。

运行 `python3 scripts/prepare_sdk_distribution.py --ref <40位SHA>` 准备包版本、许可证与资源哈希清单；`--check` 检查声明资产和哈希是否与当前工作区一致。该步骤不会提交、推送、发布或验证远端可获取性。

`--host media|chat|room_ui|full --host-directory /tmp/<新目录>` 创建仓库外临时宿主。临时宿主使用本地路径，仅证明外部接入方不依赖 Demo 与仓库 tooling。之后离线解析依赖、分析并构建。公开 Git ref 的获取与原生最小组合是独立验收项。

公开 API 迁移涉及效果显式 factory、共享内容与系统批注独立注册、类型化 feature key、录制 taskState，以及独立轻量 UI 入口。以 `doc/CLEAN_CODE_GOVERNANCE.md` 的实际进度和验收记录为准，不能把分发准备当作正式发布。
