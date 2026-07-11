# AGENTS.md

本文是 WWIIHexV0 / Steam & Empire Agent 迁移项目的入口记忆、总览、基本规则和多 Agent 工作流。当前仓库仍以 WWIIHexV0 二战 hex 战棋工程为代码基线，v5.0 起按 `蒸汽帝国 Agent` / `Steam & Empire Agent Strategy` 维多利亚时代历史策略方向规划迁移。任何 Agent 接手任务时，先读本文，再读任务所需文档和源码；不要凭旧 prompt、旧记忆或猜测修改项目。

## 1. 必读文件

每轮任务按需阅读，但不得跳过与任务相关的入口文档：

1. `AGENTS.md`：当前工作流、基本规则、项目总览。
2. `update_log.md`：版本历史、已完成事项、遗留问题；用于把上一轮结果传给下一轮 Agent A。
3. `md/flow/flow.md`：项目当前核心逻辑，是架构和运行链路的主要依据。
4. `md/flow/flowchart.md`：核心逻辑和云端协作闭环的 mermaid/流程图说明。
5. `md/test/test.md`：本地轻量检查、云端重验证、结果包和禁止执行项。
6. `md/prompt/README.md`：阶段 prompt、Agent A/B/C 召唤和云端提示词要求。
7. 当前目标对应的 prompt / 阶段文档。
8. 相关源码、配置和必要时的测试文件：优先用 `rg` / `rg --files` 定位；测试文件默认只作语义参考，不默认本机执行。

若文档、源码、轻量检查结果和云端结果包冲突，以当前源码、真实本地检查和 `origin/main` 对应 GitHub Actions 结果包为准，并在本轮结束时同步修正文档。

## 2. 项目基本规则

- 本项目是 Swift + SwiftUI + SpriteKit 的 iOS / macOS AI 战略战棋工程。
- 当前可运行代码基线仍是 WWIIHexV0 二战阿登测试板及其多层扩展；默认数据、源码兼容名和部分 UI 仍可能保留 Germany / Allies、Ardennes、Bastogne、Panzer、Division 等二战语义。
- v5.0-v5.9 路线目标是迁移为维多利亚时代 AI Agent 历史策略题材：多国家势力、黑海危机、工业预算、铁路补给、港口远征、围城、外交危机、战争目标、舆论压力和可审计内阁/军令 Agent 决策链。
- 后续维多利亚迁移必须提高经济工业和科技变迁的优先级：国库、工业产能、铁路运输力、船运量、建设能力、科技/改革修正都要形成可玩的规则取舍，而不是只作为叙事字段。
- 可参考《维多利亚 3》的经济、工业化、科技扩散、外交博弈和社会压力设计，但本项目是手机游戏，首版必须控制操作密度、回合结算成本、界面信息量和 AI 计算复杂度；不得照搬 PC 级完整全球市场、人口模拟或多层商品链。
- 不得把 v5 规划文档误写成已完成业务实现；任何维多利亚迁移功能是否落地，以当前源码、数据和真实检查结果为准。
- Hex 是战术权威：单位位置、移动、攻击、真实占领、视野、补给落点以 hex 为准。
- Region 是战略聚合层：资源、人力、补给、胜利点、控制比例从 hex 状态聚合，不替代 hex。
- `regionToTheater` 是初始/基础战区归属和地图编辑器种子，不是运行时推进层。
- `hexToTheater` 是运行时动态战区权威；突破一个 hex 只能推进该 hex 的动态归属。
- `hexToFrontZone` 是部署层动态归属权威；`regionToFrontZone` 只能作 dominant / fallback。
- 前线来自双方动态战区的真实 hex 邻接，不等于 region 边界或静态 theater 边界。
- 玩家、AI、聊天命令和 MockAI 都必须落到 `Command` / `ZoneDirective`，再经 `WarCommandExecutor`、`CommandValidator`、`RuleEngine` 执行；禁止绕过规则系统直接改 `GameState`。
- Legacy Agent D 管线保留作回归参考，默认战争 AI 主路径不得退回旧管线。
- 不恢复 organization；当前战斗核心是 strength、retreat、supply、encirclement。
- 维多利亚迁移时，多国家外交、铁路/港口补给、海权封锁、工业预算、动员、围城、报纸舆论和内阁 Agent 都只能作为规则状态、派生层或命令任务进入系统，不能替代 hex 权威或绕过 `RuleEngine`。
- 首发维多利亚剧本推荐使用 `black_sea_crisis_1853` / `黑海危机 1853`；第一版不做完整全球七十年沙盒、完整全球市场、完整海军战术或无成本殖民扩张叙事。
- 严守用户给定范围。不要擅自扩展功能、重构架构、删除旧实现或回滚其他人改动。

## 3. Agent 召唤与身份

- 用户消息以 `agenta`、`a:` 或 `A:` 开头，表示召唤 Agent A。
- 用户消息以 `agentb`、`b:` 或 `B:` 开头，表示召唤 Agent B。
- 用户消息以 `agentc`、`c:` 或 `C:` 开头，表示召唤 Agent C。
- 没有这些前缀时，按普通 Codex 任务处理；若任务需要 A/B/C 边界，提醒用户指定角色或说明本轮按普通任务执行。
- Agent A 最终回复第一行必须写：`我是 Agent A。`
- Agent B 最终回复第一行必须写：`我是 Agent B。`
- Agent C 最终回复第一行必须写：`我是 Agent C。`

## 4. main 直推云端流程

本项目默认协作流程升级为 `main` 直推 + GitHub Actions 结果包验收：

```text
人工提出目标
  -> Agent A 本地分析并写版本化提示词
  -> Agent B 基于最新 origin/main 在 main 上实现
  -> Agent B 本地只跑轻量检查
  -> Agent B commit 并 push 到 origin/main
  -> GitHub Actions 云端跑重验证并上传未加密 CI 结果包
  -> Agent C 下载结果包，核对 commitSha / runId / manifest / JUnit / 日志
      -> 有问题：退回 Agent B 在 main 追加修复 commit
      -> 无问题：确认 origin/main 最新 run 通过并更新文档
  -> 人工复核，进入下一轮
```

硬规则：

- 本轮固定使用 `main` 作为唯一上传、提交、推送和云端验证分支。
- 暂不设计 `smalldata_test`、`develop`、`codeb/...`、候选分支或 PR 合并流。
- Agent B 每轮开始前必须同步最新 `origin/main`，确认工作区无无关改动，再在 `main` 上实现。
- Agent B 完成后本地提交，并直接 push 到 `origin/main` 触发 GitHub Actions。
- Agent C 只验收 `origin/main` 最新 commit 对应的 `commitSha`、run id、run attempt 和 artifact，不能验收旧 run 或旧 artifact。
- Agent C 发现问题时，不做回滚式处理；默认退回 Agent B 在 `main` 上追加修复 commit，再 push 触发新 run。
- 任何 Agent 在 `git push origin main` 或改变远端 `main` 前，都必须确认当前分支是 `main`，目标远端是 `origin/main`，且提交范围只包含本轮相关文件。

推荐开始命令：

```sh
git fetch origin
git switch main
git pull --ff-only origin main
git status --short
```

## 5. Agent A / B / C 职责

### Agent A：目标分析与提示词

Agent A 负责思考目标如何实现，不默认直接写代码。

Agent A 必须：

1. 阅读入口文档、目标相关源码和阶段资料。
2. 明确本轮目标、非目标、架构边界、数据流、可能风险和验收标准。
3. 设计实现流程：涉及模块、是否需要拆分、轻量检查、云端 workflow/artifact 要求、需要更新哪些文档。
4. 写出给 Agent B 的详细实现提示词，放入 `md/prompt/` 对应路径。

### Agent B：实现、轻量检查、main push

Agent B 必须：

1. 基于最新 `origin/main` 在 `main` 工作。
2. 阅读 Agent A 提示词、入口文档和相关源码。
3. 小步实现；先定位根因，再改代码。
4. 本机只跑 `md/test/test.md` 允许的轻量检查。
5. commit 并 push 到 `origin/main`，触发 GitHub Actions 云端重验证。
6. 输出改动摘要、关键文件、本地轻量检查、commit SHA、push 状态和等待 Agent C 核对的 workflow 信息。

### Agent C：云端结果包验收

Agent C 必须：

1. 读取 Agent B 输出、实际 diff、`origin/main` 最新 commit、入口文档和 `md/test/test.md`。
2. 使用 `gh auth login` 后下载 GitHub Actions 未加密 CI 结果包；缓存默认放在 `/private/tmp/wwiihexv0-c-review-<run_id>/`。
3. 核对 `ci-artifact-manifest.json` 中的 `branch=main`、`commitSha`、`runId`、`runAttempt` 是否与 `origin/main` 最新 run 一致。
4. 核对 `ci-failure-summary.md`、`junit.xml`、主构建日志和项目专属结果文件。
5. 验收不通过时写退回清单；默认由 Agent B 在 `main` 追加修复 commit。
6. 验收通过时更新必要核心文档和 `update_log.md`。

## 6. 检查规则

- 每轮实现或验收前必须读 `md/test/test.md`。
- 默认云端重验证，本机只跑轻量检查。
- 除非人工明确说“本机测试”“本地 build”“本地跑探针”“本地 xcodebuild”，否则 Agent 不在本机运行 Xcode build/test、模拟器、UI test、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full 或性能测试。
- 文档-only 修改可本机跑 `git diff --check`、Markdown 尾随空白检查、YAML/JSON/Plist 解析等轻量检查。
- Swift / Xcode / Web / CLI / 业务探针相关改动完成后，默认 commit 并 push 到 `origin/main`，由 GitHub Actions 运行重验证。
- 不得用“已验证”代替具体命令、结果、run id 和 artifact；不得伪造本地测试或云端验收。

## 7. 文档规则

- `AGENTS.md` 只写工作流、入口规则和基本信息，保持精简，不堆阶段细节。
- `update_log.md` 记录版本历史、流程制度变更、关键文件、验证结果和遗留事项。
- `md/flow/flow.md` 与 `md/flow/flowchart.md` 记录当前核心逻辑和云端协作闭环。
- `md/test/test.md` 记录本地轻量检查、云端重验证、结果包内容、下载缓存和历史测试基线。
- 阶段 prompt 放在 `md/prompt/`；Agent A 写目标提示词，Agent B 按提示词实现，Agent C 根据结果包验收。
- 若源码行为、检查规则、核心流程、分支策略或版本状态改变，相关文档必须同步更新。

## 8. 交付格式

最终回复保持简洁，必须说明：

1. 完成了什么。
2. 改了哪些关键文件。
3. 当前分支、commit SHA、push 状态。
4. 跑了哪些本地轻量检查，具体结果是什么。
5. GitHub Actions run id、run attempt、artifact 名称和云端结论。
6. Agent C 是否下载并核对结果包。
7. 哪些本机重测试没跑，原因是什么。
8. 还剩什么风险或下一步。

若进行了 git stage / commit / push，只能在实际成功后按 Codex 桌面规范输出对应 directive。
