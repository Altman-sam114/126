# Prompt 目录规则

本目录保存每轮 Agent A 写给 Agent B 的版本化提示词、实现记录和历史迁移资料。新任务必须优先引用当前 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 `md/test/test.md`，不要只凭旧 prompt 修改项目。

## Agent 召唤

- `agenta`、`a:` 或 `A:`：召唤 Agent A。
- `agentb`、`b:` 或 `B:`：召唤 Agent B。
- `agentc`、`c:` 或 `C:`：召唤 Agent C。
- 没有这些前缀时，按普通 Codex 任务处理；若任务需要 A/B/C 边界，应提醒用户指定角色或说明本轮按普通任务执行。

身份输出要求：

- Agent A 最终回复第一行必须写：`我是 Agent A。`
- Agent B 最终回复第一行必须写：`我是 Agent B。`
- Agent C 最终回复第一行必须写：`我是 Agent C。`

## main 直推云端阶段

当前默认协作流程固定为：

```text
Agent A 写提示词
  -> Agent B 在 main 实现
  -> 本机轻量检查
  -> commit
  -> push origin main
  -> GitHub Actions 生成未加密 CI 结果包
  -> Agent C 下载结果包核对
  -> 失败则 Agent B 在 main 追加修复 commit
```

本轮不默认使用 `smalldata_test`、`develop`、`codeb/...`、候选分支或 PR 合并流。历史分支只作为记录和打捞参考。

## Agent A 提示词必须包含

Agent A 给 Agent B 的提示词必须写清：

- 目标和非目标。
- 当前架构依据，尤其是 hex / region / theater / front / deploy / command 权威边界。
- 需要修改的模块和禁止改动的业务逻辑。
- 当前分支要求：基于最新 `origin/main`，在 `main` 上提交。
- 本机轻量检查要求，引用 `md/test/test.md` 的具体命令。
- GitHub Actions 要求：push 到 `origin/main` 后等待 `WWIIHexV0 CI Results`。
- artifact 要求：必须让 Agent C 能下载未加密结果包，核对 manifest、JUnit、主构建日志和 failure summary。
- 文档更新要求：是否需要更新 `README.md`、`md/flow/*`、`md/test/test.md`、`update_log.md`。
- 验收标准：包括 commit SHA、run id、run attempt、artifact 名称和 Agent C 核对项。
- 风险提示：本机未跑重测试、云端 skipped 项、需要人工授权或外部依赖的事项。

## Agent B 实现记录建议

Agent B 若新增实现记录，建议放在对应版本目录，例如：

```text
md/prompt/anti生成/vX.Y/anti/X.YY_implementation_record.md
```

记录至少包含：

- 分支 / commit。
- 目标和范围。
- 关键文件。
- 本机轻量检查命令与结果。
- `origin/main` push 状态。
- GitHub Actions run id / run attempt / artifact 名称。
- 未跑本机重测试和原因。
- 待 Agent C 核对的风险。

## Agent C 验收记录建议

Agent C 验收记录应写清：

- `origin/main` 最新 commit。
- workflow 名称、run id、run attempt、结论。
- 下载缓存路径：`/private/tmp/wwiihexv0-c-review-<run_id>/`。
- `ci-artifact-manifest.json` 核对结果。
- `junit.xml`、`xcodebuild.log`、`ci-failure-summary.md` 核对结果。
- 通过 / 不通过结论。
- 需要 Agent B 追加修复的清单。

## 历史资料边界

历史 prompt、旧 jsonl、旧测试记录和迁移总提示词保留作参考，不代表当前默认流程。若历史资料要求本机 Probe、Smoke、Stage Regression、Full 或模拟器运行，以当前 `AGENTS.md` 和 `md/test/test.md` 为准。
