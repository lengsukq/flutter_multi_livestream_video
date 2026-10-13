# SDK Clean Code 治理与验收记录

本文件记录已授权 A–G 计划的实际进展。公开 API 可以调整，仓库内调用方必须同步迁移；不增加旧接口包装，不提交、推送、打标签或发布。文件长度只用于提醒审查，不作为完成条件。

## 当前状态（2026-10-13）

整份计划仍在实施中。已落地的主要边界为轻量 facade/runtime、类型化插件、可信交互与录制恢复、独立 processed-video 桥接、可选效果与共享内容、轻量房间 UI。Provider 会话与部分原生实现仍需继续治理。

| 阶段 | 当前状态 | 已落地内容 | 尚需完成 |
| --- | --- | --- | --- |
| A 基线与门禁 | 持续验证 | 43 包清单、严格分析、vendor/Chime 格式排除、依赖方向与可选效果检查、检查任务超时 | 全项目职责清单、最终完整门禁（当前批次 43 包全量质量检查已通过） |
| B 行为契约 | 主体已实现，继续审查 | 清理聚合、录制 HTTP executor、任务状态与停止恢复、晚到错误诊断、Chat provisioner 所有权 | Provider/原生/领域所有晚到回调及取消路径逐项审查 |
| C SDK 与扩展 | 主体已实现 | 单一入口编排、类型化 feature key/状态、依赖验证/重试、三种新可选包、效果显式注入 | 插件慢启动与清理竞争复审、原生最小组合及 SwiftPM 复验 |
| D 领域与 UI | 主要房间/课堂部分已拆分 | 课堂工具/模型、白板模型与 owner、HTTP 参考实现移入 preset、会议/直播布局、Chat/成员/视频舞台、统一 Pre-Join | 其余领域与样式库审查、基础 dock 职责继续收敛、统一宿主错误处理 |
| E Provider/Web/native | Web 与 Android 效果部分已完成 | Web factory/协议解码/预览/角色会话分离、各厂商 JS 模块、轻量 processed bridge、CameraX/分割/预览/转换/派发 owner | 六家厂商 Dart session、Chat adapter、AWS macOS/IVS iOS 大类、原生线程和资源边界 |
| F Demo/参考后端/Dashboard | 后端主要拆分完成，Demo 继续实施 | app factory/start-stop、薄路由、按用例应用服务、Dashboard ES modules、Demo 入会协调与身份 adapter | Demo 设置/表单拆分、后台定时器与取消复审、Dashboard 浏览器操作验收 |
| G 文档与分发 | 已准备，验证仍有缺口 | 43 包许可证/资产哈希清单、同一固定 Git ref 依赖片段、仓库外四种组合验证 | 迁移文档、原生版本/资产清单扩充、最新源码的跨平台复验；发布 ref 可获取性等待授权提交/推送后验证 |

## 已验证批次

以下记录对应当时的源码批次；后续修改相关代码后必须重新验证，不能把旧构建算作最新源码的验收。

| 证据类别 | 最近已通过的批次 | 范围限制 |
| --- | --- | --- |
| 媒体 UI | 73 项测试 | 房间 Chat/成员/会议与直播舞台、主题、Pre-Join、Safe Area 等本地行为 |
| 课堂 UI | 16 项测试 | 工具/问答/反馈和卸载后错误上报；不替代真实课堂权限链路 |
| Demo | 入会协调器迁移后 18 项测试通过 | 设置组件拆分批次须继续验证 |
| 参考后端 | 106 项测试与类型检查 | 本机协议、鉴权与用例行为；未创建云资源 |
| Web 桥接 | 23 项测试 | 本地协议、处理帧 clone、默认不采集、WebKit 资源出口 |
| 工程脚本 | 26 项测试 | 构建/打包/分发资产规则 |
| Android | 效果 owner 拆分后 Release 构建和本地原生测试通过 | SDK/plugin 编译与模拟环境单测；不代表真机 CameraX 或远端像素验收 |
| 仓库外组合 | media/chat/room_ui/full 四种组合分析、Web Release 通过 | 当时的本地路径依赖；最小三种组合没有效果包/模型/业务 preset；尚未验证公开 Git ref |
| 架构与能力声明 | 43 包依赖与生成声明通过 | 静态依赖/声明，不等于厂商实际能力验收 |

最新运行日志位于 `build/quality/`，属于本机验证产物，不能当成发布资产。

## 重点模块职责状态

| 模块 | 资源/状态 owner 与边界 | 状态 |
| --- | --- | --- |
| media_room_view | 页面只组装；Chat 展示控制器持有草稿/滚动，成员展示控制器持有目录加载/批量结果，会议舞台持有焦点；布局接收 Widget 和窄回调。全部父 State part 和宽泛 Host 已移除 | 已完成主要职责拆分；弹窗与动作入口继续审查 |
| classroom_panel/tools | 宿主启动会话；问答/名单/反馈/工具独立展示；倒计时只由 timer card 更新；工具命令各自持有展示状态 | 主要拆分完成 |
| pre_join | 整页和组合式组件复用一个 controller；preview owner 独立释放订阅与采集；控制器负责阶段、权限、重试、错误诊断，页面负责导航 | 已统一；继续审查独立组件输入与权限帮助展示 |
| meeting_dock/room_live_components/chat_components | 公共组件已分文件；完整模板保留组装，基础媒体 UI 在轻量包 | 主要组件拆分完成；基础 dock 与完整入口仍需职责复审 |
| provider_web_session_factory | factory、JoinInfo decoder、browser capabilities、preview、role session、snapshot decoder 分离 | 已拆分；真实浏览器/厂商验收待验证 |
| bridge.js | 共享协议与供应商模块分离；构建在仓库 tooling，生成资产进入发布包 | 已拆分 |
| AndroidVideoEffectsSource | Source 编排；CameraX owner、Person segmenter、bitmap converter、texture preview、frame dispatcher 分离；处理线程先排空再释放预览；清理尝试全部 owner | 已拆分；真机与长时性能待验证 |
| demo_join_screen | coordinator 准备 SDK 请求与身份；凭据缓存按后端隔离；room page 独立；widget 管导航和表单展示 | 设置/表单仍需拆分 |
| app/room-routes/chat-routes | app 组装与服务生命周期分离；路由只解析/验证/委派；业务用例负责可信权限与 provider 委派 | 主要拆分完成；继续审查所有权与失败路径 |
| Dashboard | HTML 壳、CSS、API、翻译、登录、Provider、房间、日志与刷新模块 | 已拆分；浏览器操作验收待验证 |
| Agora/LiveKit/TRTC/ARTC/Chime/IVS Dart sessions | 需要把生命周期编排、映射、发布、设备、数据、统计与帧接收分离 | 尚未完成 |
| AWS macOS/IVS iOS 插件 | 需要把注册分发、WebKit/Stage owner、资源、delegate 和视图分离 | 尚未完成 |

## 验收边界

本地单测、分析、脚本与构建不能代替真实供应商、多设备、远端处理后像素、Windows runner、长时稳定性或云端清理。未实际执行的项目保持待验证。未发布正式 Git ref，因此 `gitFetchVerified` 必须保持 false。

vendored WebRTC、厂商头文件、第三方源码及生成产物不做 Clean Code 重写。Chime 的既有 lint/格式策略保留。不要用吞异常、文件级忽略或放宽测试来消除回归；错误归一化的测试迁移必须说明行为改变，并保留重试、输入、权限、资源释放等原有断言。
