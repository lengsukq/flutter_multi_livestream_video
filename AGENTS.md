# AGENTS.md — flutter_multi_livestream_video 项目级规范

> 本文件随 git 跟踪，是通用 agent 的项目级提示词注入。
> 本地私有的 prompts / skills 一律不进 git（见 `.gitignore`）。

## 1. AWS 凭证规范（强制）

### 1.1 可用 profile（只认名字，不碰明文 Key）

| profile | 账号 ID | 身份 | 用途 |
|---|---|---|---|
| `chime-demo` | `990176353930` | IAM user `chime-demo`（最小权限） | **默认**：日常 Demo / CLI / 后端调用全用它 |
| `lengxiaoying599` | `990176353930` | root | **封存**：只用来建/删 IAM 用户，平时不用 |
| `oxpecker` | `716145798188` | IAM user `leo` | Oxpecker 业务账号，与本项目 Demo 无关，不要混用 |
| `self` / `rechic` / `build-surety` | 各自账号 | — | 其他业务，不要用于本项目 Demo |

已清理：`oxpecker-old`（Key 早已在云端失效，本地已删除）。
勿用账号：`739280997854`（已收到永久关闭通知，剩余 ~15 天，不要在其上建任何资源）。

### 1.2 调用铁律

1. 默认 profile 就是 `chime-demo`：
   ```bash
   export AWS_PROFILE=chime-demo
   # 或每条命令显式加 --profile chime-demo
   ```
2. Chime 控制面固定 `us-east-1`，媒体面用 `ap-southeast-1`：
   ```bash
   aws chime-sdk-meetings create-meeting \
     --region us-east-1 --profile chime-demo \
     --client-request-token "demo-$(date +%s)" \
     --media-region ap-southeast-1 \
     --external-meeting-id <demo-id>
   ```
3. `chime-demo` 只有 Chime 会议最小权限（`chime:*` + `chime-sdk-meetings:*` 的
   Create/Get/List/Delete Meeting/Attendee），**没有** `iam:*` / `s3:*` 等。
   `aws iam list-users --profile chime-demo` 报 `AccessDenied` 是**预期正确**，不是故障。
4. root（`lengxiaoying599`）只做 IAM 管理（建用户、挂策略、发 Key、删 Key），
   不直接 `create-meeting` 跑 Demo。
5. AK/SK 永不进 Flutter 包、永不进 git、永不贴到聊天记录。
   新 Key 的 Secret 只出现一次，丢了就删了重建，不找回。

### 1.3 计费红线

- `CreateMeeting / CreateAttendee` 本身不计费，**真人进会**才按 `attendee-minute` 计费。
- Demo 验证完立即删会：
  ```bash
  aws chime-sdk-meetings delete-meeting \
    --meeting-id <MeetingId> --region us-east-1 --profile chime-demo
  ```
- 探路会议必须清零，`get-meeting` 返回 `NotFoundException` 才算删干净。

### 1.4 出问题先查这三条

1. `InvalidClientTokenId` = AK 在云端已不存在（轮换/删除/账号关闭），不是本地格式问题；
   `SignatureDoesNotMatch` 才怀疑 Secret 写错。
2. 新建 IAM Key 有数秒传播延迟，刚建完 `sts` 失败等 10 秒再试。
3. 策略要写 `chime:*` + `chime-sdk-meetings:*` 双命名空间，只写一边会放行失败。
