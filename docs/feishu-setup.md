# 飞书 Bot 配置指南

## Step 1: 创建自建应用

1. 打开 [飞书开放平台](https://open.feishu.cn/app)
2. 点击「创建企业自建应用」
3. 填写应用名称（如 "DevOps Agent Alert Bot"）和描述
4. 创建完成后记录：
   - **App ID** (`cli_xxx`)
   - **App Secret**

## Step 2: 配置权限

进入应用 → 权限管理 → API 权限，搜索并开通以下权限：

| 权限 | 权限标识 | 用途 |
|------|---------|------|
| 获取与发送单聊、群组消息 | `im:message:send_as_bot` | 发送告警卡片到群 |
| 获取群组信息 | `im:chat:readonly` | 验证 Bot 是否在群内（可选） |

> 只需要 `im:message:send_as_bot` 这一个权限即可正常工作。

## Step 3: 发布应用

1. 进入应用 → 版本管理与发布
2. 创建版本 → 填写版本号和更新说明
3. 提交审核（企业管理员审批）
4. 审批通过后应用生效

> 如果是测试环境，可以在「应用发布」中选择「仅对部分人可用」加速审批。

## Step 4: 将 Bot 加入群

1. 打开目标飞书群
2. 群设置 → 群机器人 → 添加机器人
3. 搜索你创建的应用名称，添加到群

## Step 5: 获取群 ID

1. 打开群 → 点击群名称 → 群设置
2. 滑到底部，找到「群号」（`oc_` 开头的字符串）
3. 这就是 `FEISHU_CHAT_ID`

## 配置汇总

将以下信息填入 `terraform.tfvars`：

```hcl
feishu_app_id     = "cli_xxxxxxxxxx"      # Step 1 获取
feishu_app_secret = "xxxxxxxxxxxxxxxx"     # Step 1 获取
feishu_chat_id    = "oc_xxxxxxxxxx"        # Step 5 获取
```

## 验证 Bot 是否正常

在群里 @Bot 发一条消息：
- 如果 Bot 有回复能力（配置了事件订阅），会收到回复
- 如果没有，至少不会报错

告警集成只需要 Bot 能**主动发消息到群**，不需要 Bot 能接收消息。

## 常见问题

### Bot 发送失败：230002

```
Bot/User can NOT be out of the chat
```

**原因**：Bot 不在群里，或 `FEISHU_CHAT_ID` 填错了。

**解决**：确认 Bot 已加入群，且群 ID 正确。

### Bot 发送失败：99991

```
tenant_access_token invalid
```

**原因**：App ID 或 App Secret 填错了。

**解决**：重新检查飞书开放平台上的凭证。

### Bot 发送失败：11232

```
app not activated
```

**原因**：应用未发布或未通过审批。

**解决**：在飞书开放平台提交发布并等待审批通过。
