# AWS S3 云录制权限配置：Chime / IVS / MediaConvert

本文是 [云端录制总览](CLOUD_RECORDING.md) 的 AWS 权限配置操作说明。适用于
`demo-server` 调用 AWS Chime SDK 会议录制及 IVS Real-Time 直播录制，然后从私有
S3 Bucket 导出 MP4 的流程；Flutter SDK / Demo **不保存 AWS AK/SK**。

> 最近核对：2026-10-13。以下记录的是已配置的资源类型与权限范围；
> **只读权限验证通过不代表真实双人录制、合成、转码和下载 E2E 已通过**。
> JSON 中的 `<ACCOUNT_ID>`、`<BUCKET>` 必须替换为实际值，不能原样应用。
> 不要将私有 `.env`、凭证文件、IAM 密钥或云端录制对象提交到 git。

## 1. 现有资源与配置位置

| 项目 | 当前 Demo 约定 | 用途 |
| --- | --- | --- |
| AWS Profile | `chime-demo` | `demo-server` 使用的最小权限 IAM 用户；不使用 root 执行业务 |
| 区域 | `us-east-1` | 当前 Chime 控制面、IVS 录制、MediaConvert、S3 Bucket |
| 存储桶 | `demo-server/.env` 中的 `CHIME_RECORDING_S3_BUCKET` / `IVS_RECORDING_S3_BUCKET` | 当前两个录制执行器复用同一私有 Bucket |
| Chime 调用策略 | `FlutterRealtimeDemoChimeRecordingRuntime` | Chime Media Pipelines API、指定 Bucket 的 `s3:GetBucketPolicy` |
| IVS 调用策略 | `FlutterRealtimeDemoIvsRecordingPolicy` | IVS Composition、MediaConvert 创建/查询、受限 S3 读取/清理、`iam:PassRole` |
| Chime 服务关联角色 | `AWSServiceRoleForAmazonChimeSDKMediaPipelines` | Chime Media Pipelines 服务代表账号访问会议 |
| MediaConvert 服务角色 | `FlutterRealtimeDemoMediaConvertRole` | MediaConvert 读取 HLS 并在 S3 写回 MP4 |
| IVS 存储配置 | `IVS_RECORDING_STORAGE_CONFIGURATION_ARN` | IVS Composition 输出 HLS 至 S3 |
| IVS 编码配置 | `IVS_RECORDING_ENCODER_CONFIGURATION_ARN` 和 `_1080P` | 720p / 1080p 各自独立的编码器 |

对应环境变量（仅存储在 `demo-server/.env`，请填写当前账号的实际值）：

```dotenv
AWS_PROFILE=chime-demo
AWS_REGION=us-east-1
CHIME_RECORDING_S3_REGION=us-east-1
CHIME_RECORDING_S3_BUCKET=<BUCKET>
IVS_REALTIME_REGION=us-east-1
IVS_RECORDING_AWS_REGION=us-east-1
IVS_RECORDING_S3_BUCKET=<BUCKET>
IVS_RECORDING_STORAGE_CONFIGURATION_ARN=<STORAGE_CONFIGURATION_ARN>
IVS_RECORDING_ENCODER_CONFIGURATION_ARN=<720P_ENCODER_ARN>
IVS_RECORDING_ENCODER_CONFIGURATION_ARN_1080P=<1080P_ENCODER_ARN>
IVS_RECORDING_MEDIACONVERT_ROLE_ARN=<MEDIACONVERT_ROLE_ARN>
```

Chime **会议的媒体区域**另由 `CHIME_MEDIA_REGION` 决定（当前项目约定
`ap-southeast-1`），不要把它与录制 API 使用的控制面区域混淆；
Bucket/录制资源的实际区域必须符合 AWS Media Pipelines/IVS 的要求。

## 2. 三种权限不要混淆

| 位置 / 身份 | 所需权限 | 作用 |
| --- | --- | --- |
| `chime-demo` 的 IAM 身份策略 | `s3:GetBucketPolicy`，Resource 为指定 **Bucket ARN**（无 `/*`） | Chime 创建管线前读取、检查 Bucket Policy；**这是之前出现 AccessDenied 的权限** |
| `chime-demo` 的 IAM 身份策略 | `chime:CreateMediaCapturePipeline`、`CreateMediaConcatenationPipeline`、`DeleteMediaCapturePipeline`、`GetMediaPipeline` | 启停和查询 Chime 录制管线 |
| S3 Bucket **资源策略** | 授予 `mediapipelines.chime.amazonaws.com` 写入、读取对象及列出 Bucket | **由 Chime 服务**向 Bucket 上传捕获文件、读取源片段并写入合成结果 |
| S3 Bucket **资源策略** | 授予 `ivs-composite.<region>.amazonaws.com` `PutObject` / `PutObjectAcl` | **由 IVS 服务**上传 HLS |
| `chime-demo` 的 IAM 身份策略 | `ivs:StartComposition`、`GetComposition`、`StopComposition`、`mediaconvert:CreateJob` / `GetJob`、指定角色的 `iam:PassRole` | 启停 IVS，调度云端 MP4 转码 |
| `FlutterRealtimeDemoMediaConvertRole` | S3 输入 `GetObject`、输出 `PutObject` / `AbortMultipartUpload`、`ListBucket` / `GetBucketLocation` | **由 MediaConvert 服务**读取 HLS 并上传 MP4 |
| `chime-demo` 的 IAM 身份策略 | S3 `GetObject`、`ListBucket`、限前缀 `DeleteObject` | 后端核对 MP4、流式下载并清理导出文件 |

**关键区别：** `s3:GetBucketPolicy` 是授予 API 调用者 `chime-demo` 的
**IAM 身份权限**；`s3:PutObject` 是通过 Bucket Policy 授予
Chime / IVS 服务主体的**资源权限**。仅设置其中一个不能替代另一个。
正常运行不需要给 `chime-demo` 开放 `s3:*`、`iam:*` 或
`AdministratorAccess`。

## 3. Chime 调用身份策略（包含 s3:GetBucketPolicy）

现有账号为 `chime-demo` 附加 IAM **托管策略**
`FlutterRealtimeDemoChimeRecordingRuntime`。关键语句示例：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ChimeCaptureAndConcatenate",
      "Effect": "Allow",
      "Action": [
        "chime:CreateMediaCapturePipeline",
        "chime:CreateMediaConcatenationPipeline",
        "chime:DeleteMediaCapturePipeline",
        "chime:GetMediaPipeline",
        "chime:ListMediaCapturePipelines"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ReadRecordingBucketPolicy",
      "Effect": "Allow",
      "Action": "s3:GetBucketPolicy",
      "Resource": "arn:aws:s3:::<BUCKET>"
    }
  ]
}
```

这是**关键权限示例**，不是现有托管策略的逐字导出；实际部署策略还有诊断查询权限与条件约束。
Chime 部分 `Create*` 操作需要在 IAM 适用的资源范围上授权，
其他权限应按服务支持情况进一步约束。管理策略时应**增量修改已有策略**，
不要用这段示例覆盖原策略，否则可能移除 IVS、读写或诊断权限。

若提示 Chime Service-Linked Role 不存在，由授权的 **IAM 管理员**执行一次：

```bash
aws iam create-service-linked-role \
  --aws-service-name mediapipelines.chime.amazonaws.com \
  --profile <IAM_ADMIN_PROFILE>
```

已有角色无需重复创建，也不应通过向 `chime-demo` 授予 `iam:*` 绕过。

## 4. S3 Bucket Policy：同时保留 Chime 与 IVS

在 S3 → 目标 Bucket → **Permissions → Bucket policy** 编辑。
以下是与当前项目匹配的**结构示例**，在原策略上合并对应 Statement；
切勿直接覆盖已有声明（尤其是 IVS StorageConfiguration 自动创建的授权）。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowIVSCompositeWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "ivs-composite.us-east-1.amazonaws.com"
      },
      "Action": ["s3:PutObject", "s3:PutObjectAcl"],
      "Resource": "arn:aws:s3:::<BUCKET>/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        },
        "Bool": {
          "aws:SecureTransport": "true"
        }
      }
    },
    {
      "Sid": "AllowChimeBucketListing",
      "Effect": "Allow",
      "Principal": {
        "Service": "mediapipelines.chime.amazonaws.com"
      },
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::<BUCKET>",
      "Condition": {
        "StringEquals": {"aws:SourceAccount": "<ACCOUNT_ID>"},
        "ArnLike": {
          "aws:SourceArn": "arn:aws:chime:us-east-1:<ACCOUNT_ID>:*"
        }
      }
    },
    {
      "Sid": "AllowChimeCaptureAndConcatObjects",
      "Effect": "Allow",
      "Principal": {
        "Service": "mediapipelines.chime.amazonaws.com"
      },
      "Action": ["s3:PutObject", "s3:PutObjectAcl", "s3:GetObject"],
      "Resource": "arn:aws:s3:::<BUCKET>/*",
      "Condition": {
        "StringEquals": {"aws:SourceAccount": "<ACCOUNT_ID>"},
        "ArnLike": {
          "aws:SourceArn": "arn:aws:chime:us-east-1:<ACCOUNT_ID>:*"
        }
      }
    }
  ]
}
```

**ARN 差异：** `s3:ListBucket` 使用 `arn:aws:s3:::<BUCKET>`，
`GetObject` / `PutObject` / `PutObjectAcl` 使用
`arn:aws:s3:::<BUCKET>/*`。Chime 合成读取捕获文件，因此不能只保留
`PutObject`；IVS 的 `s3:x-amz-acl=bucket-owner-full-control` 条件也不能随意删除。
仅在 AWS 官方支持的区域和服务主体上使用对应前缀。

**注意：** Bucket Policy 更新必须由拥有 `s3:PutBucketPolicy` 的授权管理员执行，
不要给日常 Demo 账户长期保留该权限。此项目完成配置后已撤销临时授权。
若使用 SSE-KMS（客户管理的 KMS Key），还需要分别为相关服务授予
`kms:GenerateDataKey`，合成读取可能还需 `kms:Decrypt`；不能只修改 S3。

## 5. IVS 与 MediaConvert IAM 权限

现有 `FlutterRealtimeDemoIvsRecordingPolicy` 包含这些动作：

- `ivs:StartComposition`、`ivs:GetComposition`、`ivs:StopComposition`
  （限制实际使用区域）
- `mediaconvert:CreateJob`、`mediaconvert:GetJob`
- `iam:PassRole` **只针对**
  `arn:aws:iam::<ACCOUNT_ID>:role/FlutterRealtimeDemoMediaConvertRole`，
  并限制 `iam:PassedToService=mediaconvert.amazonaws.com`
- 对录制 Bucket 的 `s3:GetObject`、`s3:GetBucketLocation`、
  `s3:ListBucket`，以及对 `flutter-realtime-demo/*` 导出前缀的
  `s3:DeleteObject`（录制完成下载后清理）

MediaConvert 服务角色的信任策略必须允许：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "mediaconvert.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
```

其 S3 权限应分开授予：录制 Bucket 内 HLS 文件
`s3:GetObject`，`flutter-realtime-demo/*` MP4 目标前缀
`s3:PutObject`、`s3:AbortMultipartUpload`，以及 Bucket 元信息
`s3:ListBucket`、`s3:GetBucketLocation`。IVS 上传与转码上传的服务主体不同，
不要直接让 `chime-demo` 的客户端凭证代替 MediaConvert 服务角色。

## 6. 只读验证命令（不会创建录制任务）

以下命令从本仓库运行，用 **`chime-demo`** 验证已配置资源。
输出 ARN/策略内容可能包含账号与资源名称，请勿把完整输出贴到公开讨论区。

```bash
export AWS_PROFILE=chime-demo
export AWS_REGION=us-east-1
export RECORDING_BUCKET="<BUCKET>"
export IVS_STORAGE_ARN="<STORAGE_CONFIGURATION_ARN>"
export IVS_ENCODER_720P_ARN="<720P_ENCODER_ARN>"
export IVS_ENCODER_1080P_ARN="<1080P_ENCODER_ARN>"

# IAM 用户凭证是否有效，Bucket 是否存在
aws sts get-caller-identity
aws s3api head-bucket --bucket "$RECORDING_BUCKET" --region "$AWS_REGION"

# 检查 chime-demo 是否有 s3:GetBucketPolicy；这里不涉及写入权限
aws s3api get-bucket-policy \
  --bucket "$RECORDING_BUCKET" --region "$AWS_REGION" \
  --query Policy --output text

# Chime 管线只读列表（新账号为空数组也表示接口权限正常）
aws chime-sdk-media-pipelines list-media-capture-pipelines --region "$AWS_REGION"

# IVS 的现有 Storage / Encoder 对象是否可读取
aws ivs-realtime get-storage-configuration \
  --arn "$IVS_STORAGE_ARN" --region "$AWS_REGION"
aws ivs-realtime get-encoder-configuration \
  --arn "$IVS_ENCODER_720P_ARN" --region "$AWS_REGION"
aws ivs-realtime get-encoder-configuration \
  --arn "$IVS_ENCODER_1080P_ARN" --region "$AWS_REGION"

# MediaConvert API 只读查询
aws mediaconvert list-jobs --region "$AWS_REGION"
```

进一步检查 IAM 策略是否已**附加到用户**，应使用有权限的 IAM
管理员身份查看 `chime-demo` 的 Attached/Inline Policies；
`chime-demo` 本身没有 `iam:List*` / `iam:Get*` 权限，这是预期的最小授权。

## 7. 常见报错与排查

| 现象 | 排查位置 |
| --- | --- |
| `s3:GetBucketPolicy AccessDenied` | `chime-demo` 的 **IAM 身份策略**，Action 为 `s3:GetBucketPolicy`，Resource 是 Bucket ARN；再检查 Permission Boundary、SCP、显式 Deny |
| Chime `CreateMediaCapturePipeline AccessDenied` | Chime Media Pipelines API 权限、对应 Region、Service-Linked Role |
| Chime 录制已开始但 S3 没有文件 | Bucket Policy 的 Chime 服务主体、`PutObject` / `PutObjectAcl`、区域与 SourceAccount/SourceArn、加密配置 |
| Chime 合成失败 / MP4 不生成 | Bucket Policy 的 `GetObject` + `ListBucket`、Concat Pipeline 状态、捕获对象是否存在 |
| IVS `StartComposition` 失败 / 无 HLS | IVS StorageConfiguration 是否指向本 Bucket，以及 IVS 服务主体 `PutObject` / `PutObjectAcl` 条件 |
| MediaConvert `AccessDenied` / `PassRole` 失败 | 调用用户的 `mediaconvert:CreateJob` 与 `iam:PassRole`；MediaConvert 角色的信任策略与 S3 输入/输出权限 |
| 已生成 MP4，但 Demo 下载失败 | `chime-demo` 对对象 `s3:GetObject` / `HeadObject` 的权限、MP4 Key、处理完成状态与 60 秒单次下载票据 |

**验收边界：** 上述权限与只读资源检查通过后，还必须分别进行
Chime 和 IVS 的真实 `创建房间 → 双端入会 → 开始录制 → 停止 →
处理完成 → 下载 MP4 → 检查音视频 → 清理临时文件` 测试，
才能标记 AWS 云录制为完成。真实录制与转码会产生费用。

AWS 官方文档：
[Chime 创建媒体管线的前置条件](https://docs.aws.amazon.com/chime-sdk/latest/dg/create-pipeline.html)、
[Chime Capture S3 Policy](https://docs.aws.amazon.com/chime-sdk/latest/dg/create-s3-bucket.html)、
[Chime Concatenation S3 Policy](https://docs.aws.amazon.com/chime-sdk/latest/dg/create-concat-pipe-steps.html)、
[IVS Composite Recording Bucket Policy](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/rt-composite-recording.html)、
[MediaConvert IAM Service Role](https://docs.aws.amazon.com/mediaconvert/latest/ug/iam-role.html)。
