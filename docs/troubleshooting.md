# 常见问题排查

## 飞书发送失败：230002 Bot/User can NOT be out of the chat

**原因**：飞书 Bot 不在目标群里，或 `FEISHU_CHAT_ID` 配置错误。

**解决**：
1. 确认 Bot 已加入群（群设置 → 群机器人）
2. 确认 `FEISHU_CHAT_ID` 与群设置中的群号一致（`oc_` 开头）

## Lambda 报错：Unknown service: 'devops-agent'

**原因**：Lambda 使用的 boto3 版本不包含 DevOps Agent service model。

**解决**：确保 `investigation-notifier` 使用的是通过 `lambda/build.sh` 打包的完整 zip（含自定义 botocore），而不是单个 .py 文件。

## GitHub Issue 创建了但 DevOps Agent 没有开始调查

**排查**：
1. 检查 GitHub Actions 是否触发：仓库 → Actions 页面
2. 检查 Actions secrets 是否配置：`DEVOPS_AGENT_WEBHOOK_URL` 和 `DEVOPS_AGENT_WEBHOOK_SECRET`
3. 检查 Webhook URL 是否正确（从 Agent Space 控制台获取）

## CloudWatch Alarm 触发了但飞书没收到

**排查**：
1. 检查 SNS 订阅：`aws sns list-subscriptions-by-topic --topic-arn <arn>`
2. 检查 Lambda 日志：`aws logs tail /aws/lambda/<function-name> --since 5m`
3. 确认 Alarm 的 `AlarmActions` 包含正确的 SNS Topic ARN

## 调查完成但飞书没收到结果

**排查**：
1. 检查 EventBridge Rule 状态：应为 ENABLED
2. 检查 `investigation-notifier` Lambda 日志
3. 确认 Lambda 环境变量 `FEISHU_CHAT_ID` 和 `FEISHU_BOT_SECRET` 已配置

## 如何查看飞书群 ID

1. 打开飞书群 → 点击群名称 → 群设置
2. 滑到底部找到"群号"（`oc_` 开头的字符串）
