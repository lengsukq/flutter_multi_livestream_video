# dev.8 后续：Web 入会、页面准备与桥协议保护

## 对最新报告的核对

- 本轮不重做 dev.8 已解决的摄像头黑屏和 LiveKit 处理轨发布问题。
- `Realtime.open()` / Web `join()` 已有抛错路径；第三方的入口也有 catch 与 SnackBar。
  仅凭按钮恢复不能认定 SDK 吞错。本轮用公开 `Realtime.open()` 回归确认宿主能收到
  `network`、可恢复标记与原始 cause。
- 实际存在的缺口是：Web join 的网络错误通常折叠成 providerError；异步错误事件的
  原因被丢弃；先收到错误事件、再完成 join Promise 时，旧流程可能清错后返回成功。
- Meeting 的 `sharedContent.start()` 没有等待上限，且内部会把失败保存在 status 中；
  页面原先未检查该错误。Live 的错误页“重试”还存在 setState 回调返回 Future 的断言问题。
- dev.8 保留了 `attachVideo(..., elementId)`，它先查出 DOM 元素，再委派给 element
  接口。因此“旧 Dart 传字符串给新 driver”不是已证实的故障。旧的 web_resources.d
  文件也不能单独证明浏览器正在执行旧 Dart。该兼容入口已加入实际 JS 回归。

## 修改

1. Web join 分类 network/timeout，保留 cause、details、stackTrace 与 retry 建议；
   join 等待上限 20 秒，失败清理仍受 Cleanup 的 10 秒上限约束。脚本加载和后端请求
   各有自己的超时，20 秒不是整个 open() 的总时间。
2. 失败后释放部分入会会话；销毁时同步移除 JS 注册、停止统计定时器并屏蔽事件；
   晚到连接再次离开，不得复活旧会话或删除同 ID 的新会话。
3. join 期间收到的错误会保留到 Promise 完成，不能再被连接状态事件清成成功。
4. Meeting/Live 的媒体准备共 15 秒上限，Meeting 的共享内容启动另有 15 秒上限。
   超时或共享内容启动失败进入原有错误页；准备保持摄像头关闭，只有有效的设置应用步骤才能发布。
   重试有代次保护，过期准备不能继续应用后续设置。
   修复 Live 重试的 setState/Future 断言；共享内容重新启动会清除旧失败状态。
5. Room UI 订阅后台和媒体故障，沿用宿主的 onActionError 呈现机制；关闭 UI 时取消
   订阅，UI 仍不拥有借入的房间。成品页使用现有错误提示，自绘宿主自行决定呈现方式。
6. 网络、超时与资源不兼容有中英文可读提示；公开 message 不拼接原始厂商载荷。
7. media/effects JS 分别声明 bridgeVersion，Dart 在调用前检查协议。缺失或不匹配
   返回 webBridge.versionMismatch 与 reload-web-runtime。协议号独立于 pub 发行号；
   不要求所有补丁版本的资源一律互斥。旧已编译 Dart 无法通过热重载获得新检查。
8. 重新生成 Web 资产，并在发行校验器中解析 media/effects 两个 JS 文件，拒绝语法损坏。
   本轮起点仓库里的 effects 生成资产存在重复外层函数；本机 pub-cache 的 dev.8 文件
   语法正常，不能把仓库问题推断为已发布 dev.8 的同类缺陷。

## 宿主接入边界

`open()` 返回房间之前没有挂载 SDK 房间页。宿主必须 await 并 catch，将异常保留在
页面状态里显示，并提供再次调用原请求的按钮。可用
`RealtimeStrings.of(context).displayRealtimeError(error)` 获取可读提示；短暂
SnackBar 不能替代持续可见的连接失败状态。单包的中英文 README 已补充这条约定。

此次没有修改第三方原应用、其后端或本机代理。测试使用隔离副本与故障注入。
代理拦截 Agora 端点仍需网络侧处理；SDK 的错误呈现和重试不会使被拦截的端点可达。

## 验证

- 44 包离线依赖解析、analyze、默认平台测试通过；新增公开 open() 用例另行复核。
- 故障注入：Promise 拒绝、Promise 不完成、错误事件先于 Promise 完成、失败后重试、
  销毁后的晚连接、同 ID 会话替换、旧字符串挂载、桥协议缺失/不匹配。
- Widget：Meeting/Live 超时与可见错误、Live 重试、共享内容挂起及失败、过期准备失效。
- Room UI：运行错误转交宿主、关闭订阅后不再通知、借入房间不被 UI 清理。
- 对生成单包重复浏览器回归，并用第三方原 lib/web/assets 的隔离副本构建 Web。
- 架构、格式、能力声明、单包资源/JS 语法与本地资产完整性检查。

上述是本地自动化与构建证据，不是实际 Agora 受阻网络、真实双端通话或设备验收。
未创建厂商房间，未修改代理规则。

## 本地交付

未发布候选：`build/pub_release/0.1.0-dev.9/flutter_realtime_sdk`。
手动发布入口：`scripts/publish_single_sdk_dev9.command`。
旧 dev.8 候选保持原样；更新版本、解析依赖后须完整重启 Web。
