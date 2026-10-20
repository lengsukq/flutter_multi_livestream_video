# Realtime 前端视觉系统

本项目统一采用单一浅色、冷灰蓝工作区外观：`#E9EDF2` 页面底、白色内容卡、琥珀色操作、青绿色状态、玫红色危险/直播。视频与直播舞台允许局部深色遮罩，它们不构成应用暗色模式。Demo 不读取外观偏好，也不提供外观切换。

自 2026-10-19 起，视觉基准改为三套参考模板（Green room / Live classroom / Screen share and recording）。所有 `*_ui` 包、内置页面与共享组件都必须遵循本文件的色板、几何、字体与响应式契约。

## 接入与边界

通用包为 `flutter_realtime_design_ui`，只依赖 Flutter。主题、颜色、几何、字体与通用组件通过 `flutter_realtime_design_ui.dart` 公开提供。宿主使用 `RealtimeUiTheme.light()`；自定义配置使用 `RealtimeUiThemeExtension` 与 `RealtimeStyle.copyWith`。

所有 UI 包可以依赖该通用包；core、runtime 和 SDK facade 不依赖 UI。房间、权限、设备采集、聊天和控制面行为继续由原有 SDK 契约承载。白板绘图颜色与媒体内容不属于界面主题色。

## 字体

| 用途 | 字体 | 字重 |
| --- | --- | --- |
| 正文、控件、表格 | Onest | 400 / 500 / 600 / 700 |
| 页面标题、卡片标题、计时 | Bricolage Grotesque | 500 / 700 |

- 字体文件随 `flutter_realtime_design_ui/fonts/` 打包，不联网加载。
- Flutter 包字体的 family 名为 `packages/flutter_realtime_design_ui/Onest` 与 `packages/flutter_realtime_design_ui/BricolageGrotesque`。
- 单包发布时，`scripts/assemble_single_sdk_candidate.py` 会把 family 前缀改写为 `packages/flutter_realtime_sdk/...`，并在生成的 pubspec 中写入 `fonts:` 段。
- 宿主可通过 `RealtimeUiThemeExtension(bodyFontFamily:, displayFontFamily:)` 覆盖；传空字符串则退回平台默认字体。

## 色板

| 语义 | Token | 值 |
| --- | --- | --- |
| 页面背景 | `background` | `#E9EDF2` |
| 卡片 / 面板 | `surface` | `#FFFFFF` |
| 次级块 / 输入 | `surfaceSubtle` | `#F4F6F9` |
| 分隔线 | `border` | `#DAE0E8` |
| 强分隔线 | `borderStrong` | `#C4CDDA` |
| 主文字 | `text` | `#18202E` |
| 次文字 | `textSecondary` | `#3D4A5C` |
| 说明文字 | `textMuted` | `#5B6678` |
| 主操作 / 选中 | `accent` | `#F5C518` |
| 黄底文字 | `onAccent` | `#2A2100` |
| 高亮块 | `accentSoft` | `rgba(245,197,24,.35)` |
| 发言描边 / 状态点 | `speak` | `#0E9E8E` |
| 青绿文字 / 白字按钮 | `speakStrong` / `success` | `#0B7F72` |
| 直播 / 录制 / 危险 | `live` | `#D93A3F` |
| 白板纸 | `board` / `boardGrid` / `boardInk` | `#FCFDFE` / `#E7ECF2` / `#1F2A3C` |
| 视频占位 | `tile` / `tileStrong` | `#D5DCE6` / `#C4CDDA` |

**关键对比度规则：** 琥珀色只作为填充色（按钮底、选中块、徽标底），其上的文字必须使用 `onAccent`。白色或浅色底上的文字、图标一律使用 `text` / `textSecondary` / `textMuted` / `speak` / `live`，不得使用琥珀色文字。

## 几何与层次

| 项 | 值 |
| --- | --- |
| 卡片圆角 | 22 |
| 控件 / 小按钮圆角 | 12 |
| 舞台 / 视频圆角 | 18 |
| 弹层顶部圆角 | 24 |
| 紧凑圆角 | 10 |
| 胶囊圆角 | 999 |
| 间距 | 4 / 8 / 12 / 16 / 24 / 32 |
| 玻璃模糊 | 16（次级 10） |
| 动效 | 160 / 240 / 340ms |

- 卡片阴影：`0 8 24 rgba(16,24,40,.06)` + `0 1 2 rgba(16,24,40,.04)`。
- 默认主题使用不透明表面；宿主可以显式开启玻璃（`glassOpacity .94`）。高对比度或关闭玻璃时强制不透明。
- 页面底色平铺，内容卡默认不带阴影；浮动 Dock 与画中画保留轻阴影。
- `speakStrong` 对白色为 4.89:1，对次级表面为 4.52:1；成功提示浅底使用 `#EFFAF8`，对比度 4.59:1。
- 分段控件继续遵守「外层半径 ≥ 高度/2，滑块半径 = 外层 − 内边距」；选中块使用琥珀色。

## 响应式契约

公共断点位于 `RealtimeBreakpoints`，页面不得再散落 600/1000/1280 字面量。

| 宽度 | 会议 | 直播 | Pre-Join | 聊天 / 课堂 / 白板 |
| --- | --- | --- | --- | --- |
| `< 600` 手机 | 56pt 常显顶栏；舞台 + 底部浮动 Dock；无左侧栏；面板走右侧抽屉 | 全屏视频 + 移动 HUD；面板走右侧抽屉 | 单列滚动；预览 16:10；底部粘性单一 CTA | 单列；工具栏横向滚动 |
| `600–999` 平板 | 顶栏 + 横向工具条 + 舞台栏 + Dock；面板走右侧抽屉 | 移动 HUD + 右侧抽屉 | 单列；设备选择器两列 | 侧栏自适应 |
| `>= 1000` 桌面 | 56pt 顶栏 + 60pt 竖向工具栏 + 舞台栏 + 340pt 常驻侧栏 | 视频舞台（左）+ 360pt 互动栏（右） | 两栏（预览 6 : 会话/设备 4），最大宽 1240 | 最大宽 900–1100 |
| `>= 1280` | Dock 显示文字标签 | 右栏留白增大 | 预览更大 | 更宽留白 |
| 200% 文字 | 降级一档；隐藏标签；所有行可换行或滚动 | 同左 | 选择器纵向堆叠 | 分段控件退化为列表 |

验收宽度：320、390、600、768、1024、1280、1440，另加 320×640、740×390 与 200% 文字。硬性要求：无 `RenderFlex overflow`，加入、离开、静音、摄像头、聊天发送始终可点到。

## 页面结构

### 首页与顶层导航

- `RealtimeWorkspaceShell` 新增可选 `header` 与 `compactNavigation`，旧调用保持兼容。Demo 使用固定 56pt 品牌栏；桌面为 60pt 全高工具轨，手机和平板为平整底部导航。
- 首页标题直接排在灰蓝背景上，减少重复卡片。桌面为左侧房间目录、右侧深色加入卡（约 1.35:1）；窄屏加入卡在前、目录在后。创建会议、开播、加入、聊天与设置入口保留。
- 工具轨提供标签提示、键盘焦点与稳定的 destination key。切换布局或导航不销毁已挂载的聊天宿主。
- 普通 Demo 入口只使用真实房间身份；课程、等待名单、倒计时等样例只出现在明确标识的测试/样例展示中。


### 会议

```
顶栏 (56pt, 常显)
└─ 工作区
   ├─ 工具栏 (>=1000, 60pt；白板共享时由白板自带工具轨接管)
   ├─ 舞台栏 → 舞台 → Dock（常显，不自动渐隐）
   └─ 侧栏 (>=1000 且打开, 340pt)
```

- 顶栏：品牌插槽（与标题之间留 1pt 分隔线）、房间/课程标题、副标题、角色胶囊、在线人数、时长胶囊（课堂模式为红色 LIVE 胶囊）、录制胶囊、连接状态、头像堆叠、Invite 按钮、离开。离开按钮是唯一退出入口，顶栏常显。录制胶囊只显示 `Recording` / `录制中`，具体时长放在 tooltip，避免和时长胶囊重复。
- 课堂工作区（`showClassroom && room.classroom != null`）：使用与参考稿一致的课堂布局。通用工具轨让位给白板自带的 60pt 教学工具轨；侧栏改为 Chat / People / Hands / Q&A 下划线 Tabs（Hands 仅教师可见）；Dock 协作组出现真实的 Poll / Timer 按钮。
- 白板共享：普通会议共享白板时同样不再叠加通用工具轨，画面左侧只保留白板自己的工具列。
- 共享内容激活时，舞台栏整行隐藏：屏幕共享的共享条、白板的页签栏已经是这一区域的标题，再叠一行只会压小核心画面。缩略图开关此时移到 Dock 协作组，保证入口仍只有一处。
- 非课堂会议：沿用通用工具栏 + 胶囊 Tabs 侧栏；两者共用同一 56pt 顶栏、340pt 侧栏、Dock 分组与舞台几何。
- 工具栏：聊天 / 成员 / 课堂、互动（挥手）。工具栏只负责面板与宿主自定义互动，不承载举手、背景或布局。
- Dock：白色圆角胶囊分组，组内按钮为「图标 + 文字」单行 40pt 控件（手机仅图标方块）。空闲态透明、文字 `textSecondary`；共享 / 录制等激活态使用 teal 实底白字。**Dock 常显，不随空闲计时渐隐**，课堂中随时可点到静音、摄像头、共享与离开之外的全部操作。**每个动作只有一个入口**：举手只在 Dock（学生为「举手」，教师为带人数的「举手队列」）；虚拟背景在 Dock（平板/桌面）或 More（手机）；离开只在顶栏。
- 舞台栏：未共享时为发言人 / 宫格切换与隐藏缩略图；共享时为空白行（不渲染）。布局切换是唯一入口，顶栏、工具栏与 More 不再重复。
- 舞台：18pt 圆角、1pt 描边；说话人 2pt teal 描边；关闭摄像头使用 `tile` 底 + 饱和色头像；右上角本地画中画（共享/白板期间同样保留；窄小窗口避免遮挡）。缩略图始终独占舞台下方一行。
- 侧栏：课堂工作区为下划线 Tabs（Chat / People / Hands / Q&A），非课堂为胶囊 Tabs（聊天 / 成员）；置顶消息用 `accentSoft`；成员列表带头像、麦克风与摄像头状态；举手成员单独分组。
- 手机/平板：面板通过右侧全高抽屉打开，不再使用底部弹层。

#### 宿主插槽（会议）

| 参数 | 类型 | 语义 |
| --- | --- | --- |
| `sessionInfo` | `RealtimeMeetingSessionInfo` | 课程/房间标题与副标题；缺省回退到房间号 |
| `brand` | `Widget?` | 顶栏产品标识 |
| `pinnedMessage` | `String?` | Chat 面板顶部置顶消息 |
| `initialSharedContentMode` | `SharedContentMode?` | 入会后请求的共享内容模式（如“共享屏幕开始”） |

课堂标题、等待室、议程、倒计时、材料、置顶消息在 SDK 中都没有权威状态，必须由宿主通过上述插槽提供；SDK 不会伪造这些内容。

### 直播

- 桌面：左侧视频舞台 + 右侧 360pt 互动栏（主播卡、聊天流、输入、礼物/点赞）。
- 移动：全屏视频 + HUD（主播胶囊、时长、观众头像、显示选项、离开）+ 浮动聊天条与操作条。
- 主播工具是直播间唯一的设置面板：摄像头切换、屏幕共享、虚拟背景、音频与设备都在其中。顶栏与移动端「显示选项」只保留进入主播工具的动作，不重复背景入口。
- 礼物横幅、爱心浮层、录制徽标统一使用新色板；清屏模式保留。

### Pre-Join / Green room

- 桌面（>=1000 且高度 >=420）：`maxWidth 1240`，左右约 1.35 : 1、间距 24。
  - 左栏：38pt 标题 + 说明 → 16:10 预览卡（左上真实分辨率/网络胶囊，底部 mic / camera 圆形快捷开关）→ 单一的「设备与效果」卡（Camera / Microphone / Speaker 同排下拉 → 真实麦克风/摄像头开关与电平 → 画面效果 → 就绪检查 → Run again）。预览卡不再重复背景与设置入口。
  - 右栏：深色课程卡（subject 琥珀胶囊、课程标题、日期/时段/报名人数、真实倒计时、琥珀主 CTA、Audio only / Start with screen share）→ 隐私说明 → 等待室 → 课程议程 → 课堂材料。后四块只在宿主传入数据时出现；`Run again` 不在深色卡内，避免主操作区拥挤。
- 平板/手机：单列滚动，顺序为预览 → 设备与效果 → 课程卡 → 宿主插槽；底部粘性栏只保留一个主 CTA，避免重复主操作。
- 顶栏只渲染品牌、标题和宿主传入的 `headerActions`，不放没有行为的主题或帮助按钮。
- 默认关闭麦克风与摄像头；观众不渲染本地预览与设备选择。
- 噪声抑制、静音电平表、试音、自动录制、实时字幕没有底层能力，不渲染假控件。开关激活色使用 teal `speak`。

#### 宿主插槽（Pre-Join）

| 参数 | 类型 | 语义 |
| --- | --- | --- |
| `sessionInfo` | `RealtimePreJoinSessionInfo` | 课程标题、学科、日期/时段、`startsAt` 倒计时、报名人数 |
| `waitingGuests` / `onAdmitGuest` / `onAdmitAll` | 列表与回调 | 等待室名单与准入请求；准入结果由宿主更新名单状态 |
| `agenda` | `List<RealtimePreJoinAgendaItem>` | 编号课程议程 |
| `materials` / `onOpenMaterial` | 列表与回调 | 课堂材料 |
| `brand` / `headerActions` | `Widget?` / `List<Widget>` | 顶栏品牌与额外操作 |
| `onEnterWithIntent` | `RealtimePreJoinEnterWithIntent` | 接收 `standard / audioOnly / screenShare` 意图；`audioOnly` 会强制麦克风开、摄像头关 |

### 聊天、课堂、白板

- 聊天：扁平行（头像、姓名、时间、正文），自己的消息右对齐并使用 `surfaceSubtle`；输入框为方框 + 图标行 + 深色圆形发送，房间面板在输入框上方显示 `To Everyone` / `发送给所有人`。
- 课堂：56pt 单行头部（可换行/省略）；课堂面板内 TabBar 选中块为琥珀色胶囊；会议工作区侧栏使用下划线 Tabs（340pt 下五个标签收紧内边距，保证完整可读）；举手 / Q&A / 花名册 / 工具统一头像与小按钮。
- 白板：`RealtimeBoardSurface`（白纸 + 细网格 + 18pt 圆角）。宽屏为 60pt 竖向教学工具轨 + 顶部页签条 + 16:9 白板；工具轨只包含真实能力（选择/画笔/高亮/圆/箭头/文字/颜色/撤销/清空），选中态琥珀色；页签读取 `WhiteboardState.pages`，右侧提供缩放（100%–300%）与停止共享；窄屏页签横向滚动，缩放/删除/停止固定在尾部，停止共享收缩为图标按钮。屏幕标注工具条浮动在画面底部，并约束在实际共享画面内，不覆盖聊天或录制侧栏。
- 屏幕共享 / 录制：会议舞台内的共享条由 Dock 的共享入口承担；独立共享舞台仍保留深青 `#0B7F72` 实底白字条与白色 `Stop Sharing` 按钮。`RealtimeRecordingPanel` 只展示权威录制状态、真实时长、已请求的布局/媒体/输出选项与结果入口，不含聊天/字幕/章节/存储额度等假开关。
- 所有弹层：24pt 顶部圆角、拖拽条、56pt 标题行、白色表面。

## 可访问性

- 玻璃、阴影与选中态在 `glassEnabled: false` 或高对比度时退化为不透明表面与实线描边。
- 减少动态效果时移除缩放、位移与渐隐动画；状态点不使用无限循环动画。
- 触控目标：图标按钮 ≥ 44pt，可点击胶囊 ≥ 48pt，列表行 ≥ 44pt。
- 文字遵循系统缩放；组件使用滚动或弹性布局，不用裁切掩盖溢出。

## 验收边界

质量门禁、单测、布局检查、测试数据截图、浏览器验证和真实厂商调用分别记录。测试数据与组件截图不代表真实音视频、多设备、原生平台或云资源清理完成。

必须覆盖：

```sh
python3 scripts/check_sdk_quality.py --resolve --analyze --test
python3 scripts/check_sdk_architecture.py
python3 scripts/format_sdk.py --check
python3 scripts/generate_capability_matrix.py --check
cd example && flutter test --no-pub
python3 -m unittest scripts.tests.test_assemble_single_sdk_distribution
```

截图验收使用 `example/test/support/design_capture.dart` 生成 meeting / live / prejoin / chat 在 390、768、1440 的预览，并单独检查 320×640、740×390 与 200% 文字。

## 本轮主要变更（2026-10-19）

- 色板从珍珠白 + 绿色改为冷灰蓝 + 琥珀 + teal + 玫红；`primary` 保留为 `accent` 的别名。
- 打包 Onest 与 Bricolage Grotesque，单包发布同步复制字体并改写 family 前缀。
- 会议页重做为「常显顶栏 + 竖向工具栏 + 舞台栏 + 340pt 侧栏」，手机与平板面板改为右侧抽屉。
- 直播桌面改为「左视频 + 右互动栏」，恢复被遗漏的桌面离开按钮。
- Pre-Join 重做为 Green room 两栏布局，移动端只保留一个 CTA。
- 聊天、课堂、白板、共享内容条、标注工具栏、Dock、徽标统一到新 token。
- 修复 320pt / 200% 文字下顶栏、Pre-Join 头部、效果卡与 Join 按钮的溢出。

## 本次完善与验证（2026-10-19）

- 首页按 Green room 的编辑式标题、深色操作卡和工作区工具轨重新设计。
- 白板网格不再被子层底色遮住；标注文字使用主题字体。`AnnotationPainter(fontFamily:)` 可为自定义绘制指定字体，`AnnotationSurface(constrainToolbarToCanvas:)` 支持将浮动工具限制在画面内。
- 消息列表去掉远端消息边框；不把远端普通成员标为老师。直播爱心跟随 `live` 语义色。
- 移动和桌面课堂 CTA 使用相同文案逻辑；缺省会话仍为通用加入，观众使用观看入口，课程主持人/参与者分别显示开始/加入课堂。
- 新增 `workspace_acceptance_test.dart`，覆盖白板、共享、录制及 Green room。截图工具直接加载包内字体；截图输出到 `build/design-previews/`。HTML 参考在禁用联网并移除外部资源后离线渲染，参考中的 CDN 图标和未提供的手写字体不作为逐像素比对依据。


## 二级页面与独立 SDK 接入

- `design_ui` 统一弹窗、底部面板、卡片和表单；默认使用不透明表面，`RealtimeCard` 默认无阴影，显式阴影与玻璃配置仍可使用。`RealtimeGlassDialog` 与 `showRealtimeGlassBottomSheet` 在宿主没有安装 SDK 主题扩展时局部应用 SDK 默认主题；宿主已安装扩展时保留品牌与字体覆盖。弹窗整体可滚动以适应键盘、大文字和低高度。
- `sdk_ui` 承载共享方式、更多操作、反应、主播工具、音视频设备选择、录制布局和结果、会议/直播退出及成员操作确认。更多菜单按宽度和文字大小改变列数；主播工具在窄屏上下排列说明与操作；反应按钮换行。
- `classroom_ui` 承载发布、答题、举手、问答与课堂工具；`chat_ui` 承载消息操作和成员管理；`whiteboard_ui` 承载标注文字和绘图颜色。绘图调色板与视频上的可读性渐变保留其内容语义。
- 这些改动没有下放到 Demo。新增 `sdk_ui/test/secondary_pages_test.dart` 直接通过 SDK 公开组件生成 24 张截图并测试 8 个入口。默认外观、宿主覆盖及低高度键盘回归位于 `design_ui/test/modal_defaults_test.dart`。
