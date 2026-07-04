# 测试与云端验证规范

> 当前规则：默认云端重验证，本机只跑轻量语法、格式和配置文件检查。历史 Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full 记录只作回归参考，不再是每轮任务的本机默认要求。

## 0. 总原则

- 每轮实现或验收前仍要读本文件，确认哪些检查允许本机执行、哪些检查交给云端。
- 默认不在本机跑耗费性能的测试、构建、模拟器启动或 app 启动。
- Swift / Xcode / 业务逻辑相关改动完成后，默认 commit 并 push 到 `origin/main`，由 GitHub Actions 运行重验证并上传未加密 CI 结果包。
- Agent C 验收时必须下载并核对 `origin/main` 最新 run 的结果包；不能只看 Agent B 文字汇报。
- 若某风险必须依靠重测试确认，只在交付中明确记录云端 run id / artifact 结论；没有云端或本机结果时，不得写“已验证”。

## 1. 禁止本机默认执行

除非人工在当前任务中明确授权“本机测试”“本地 build”“本地跑探针”“本地 xcodebuild”，否则 Agent 不得在本机主动执行：

- `xcodebuild test`
- `xcodebuild build`
- `xcodebuild build-for-testing`
- `xcrun simctl ...`
- Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full
- XCTest、UI test、性能测试、快照测试
- 启动 iOS Simulator
- 启动 app 做人工烟测
- 全项目 Swift 编译、全量 lint、全量格式化
- 会长时间占用 CPU、内存、磁盘或 DerivedData 的命令

这些重验证默认由 `.github/workflows/ci-results.yml` 在 GitHub Actions 上执行或标记 skipped / failure。

## 2. 本机默认允许的轻量检查

### 2.1 Markdown / 文本

检查改动文档是否存在尾随空白：

```sh
rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/README.md
```

检查当前规范中是否仍残留旧默认测试口径：

```sh
rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md
```

### 2.2 Xcode project / plist / XML

仅当修改了 `WWIIHexV0.xcodeproj/project.pbxproj` 时运行：

```sh
plutil -lint WWIIHexV0.xcodeproj/project.pbxproj
```

仅当修改了 scheme 或 XML 文件时运行：

```sh
xmllint --noout WWIIHexV0.xcodeproj/xcshareddata/xcschemes/WWIIHexV0.xcscheme
xmllint --noout WWIIHexV0.xcodeproj/xcshareddata/xcschemes/WWIIHexV0Probes.xcscheme
```

### 2.3 YAML / GitHub Actions

仅当修改 workflow 时运行：

```sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'
```

### 2.4 JSON

仅当修改了 JSON 数据时运行对应文件的解析检查，优先只查改动文件：

```sh
jq empty WWIIHexV0/Data/ardennes_v0_scenario.json
jq empty WWIIHexV0/Data/ardennes_v02_regions.json
jq empty WWIIHexV0/Data/general_agents.json
jq empty WWIIHexV0/Data/generals.json
jq empty WWIIHexV0/Data/terrain_rules.json
jq empty WWIIHexV0/Data/unit_templates.json
```

### 2.5 Swift 单文件语法

默认不做全项目编译。若只改了少量纯 Swift 文件，并且单文件语法检查不会触发项目构建，可以只针对改动文件做轻量 parse；如果命令需要 SDK、SwiftUI/SpriteKit 依赖或变慢，立即停止并记录未检查。

示例：

```sh
swiftc -parse path/to/ChangedFile.swift
```

## 3. 云端重验证

默认 workflow：`.github/workflows/ci-results.yml`

触发条件：

- push 到 `main`
- `workflow_dispatch`

当前云端验证内容：

- `git diff --check`
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`
- `xmllint --noout` 检查共享 scheme
- `jq empty` 检查核心 JSON 数据
- `xcodebuild build`，工程 `WWIIHexV0.xcodeproj`，scheme `WWIIHexV0`，configuration `Debug`，destination `generic/platform=iOS`，`CODE_SIGNING_ALLOWED=NO`
- XCTest / Probe 默认在 workflow manifest 中标记 `skipped`，直到项目明确选择稳定的云端模拟器矩阵

本机和云端 DerivedData 差异：

- 本机默认不写 DerivedData。
- 云端使用 `.derivedData-ci`，结果包放入 `ci-results/WWIIHexV0.xcresult`。

## 4. CI 结果包

GitHub Actions 必须上传未加密 artifact，供 Agent C 下载复判。结果包最低包含：

- `ci-artifact-manifest.json`
- `ci-failure-summary.md`
- `xcodebuild.log`
- `junit.xml`
- `WWIIHexV0.xcresult`（若 `xcodebuild` 生成成功）
- `static-checks.log`

`ci-artifact-manifest.json` 至少记录：

- `version`
- `branch`
- `commitSha`
- `shortSha`
- `runId`
- `runAttempt`
- `workflowName`
- `createdAt`
- `projectName`
- `scheme`
- `destination`
- `resultBundlePath`
- `junitPath`
- `buildLogPath`
- `failureSummaryPath`
- `staticChecksOutcome`
- `buildOutcome`
- `testOutcome`
- `projectSpecificReports`

artifact 命名：

```text
WWIIHexV0-ci-v1-main-<short_sha>-run<run_id>-attempt<run_attempt>
```

## 5. Agent C 下载与核对

Agent C 验收必须先具备 GitHub CLI 权限：

```sh
gh auth login
```

下载缓存默认放在：

```text
/private/tmp/wwiihexv0-c-review-<run_id>/
```

核对流程：

1. `git fetch origin`
2. 确认 `origin/main` 最新 commit。
3. 查找该 commit 对应的最新 `WWIIHexV0 CI Results` run。
4. `gh run download <run_id> --dir /private/tmp/wwiihexv0-c-review-<run_id>/`
5. 打开 `ci-artifact-manifest.json`，核对 `branch=main`、`commitSha`、`runId`、`runAttempt`。
6. 打开 `ci-failure-summary.md`、`junit.xml`、`xcodebuild.log` 和项目专属结果文件。
7. 若 CI 失败，退回 Agent B 在 `main` 上追加修复 commit，不默认回滚。

缓存由人工确认后删除；Agent 不自动删除人工可能还要看的结果包。

## 6. 多分支 / 并发后的整合检查

当前默认流程不使用长期候选分支，但历史分支和本地工作树可能存在。合并或打捞前仍必须做轻量整合检查：

- 同一文件是否被多个分支或子 Agent 修改。
- 同一 public API、类型名、枚举 case、JSON key 是否出现分叉。
- `WWIIHexV0.xcodeproj/project.pbxproj` 是否存在重复文件引用、缺失文件引用或 UUID 冲突。
- `Data/*.json` 与 `ScenarioDefinition` / `RegionDataSet` 是否同时变化但文档未同步。
- `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 管线是否仍保持统一入口。
- `hexToTheater`、`hexToFrontZone`、`regionToTheater` 的权威边界是否被不同分支写成不同口径。
- README、`md/flow/*`、阶段 prompt、`update_log.md` 是否描述同一版本状态。

建议命令：

```sh
rg -n "struct |enum |class |protocol |case |func " WWIIHexV0 MapEditor
rg -n "hexToTheater|hexToFrontZone|regionToTheater|ZoneDirective|WarCommandExecutor|RuleEngine" WWIIHexV0 md README.md AGENTS.md
```

这些命令只用于定位冲突线索，不等于功能测试。

## 7. 历史测试基线

以下记录只用于理解历史状态，不作为当前任务的本机默认执行要求：

- v0.37 Probe：18 tests, 0 failures。
- v0.37 CommandSystemTests：15 tests, 0 failures。
- v0.37 Stage Regression：69 tests, 0 failures。
- v0.37 Full Regression：226 tests, 0 failures。

当前交付中若没有人工授权本机重测试，统一写明：

```text
未跑本机 Xcode / XCTest / 模拟器 / 性能测试；按当前规范本机仅做轻量检查，重验证交给 GitHub Actions。
```

## 8. 交付写法

最终回复必须区分本机轻量检查、云端结果和未跑项：

- 本机已跑：写具体命令和结果。
- 云端已跑：写 workflow 名称、run id、run attempt、commit SHA、artifact 名称和结论。
- Agent C 已验收：写 manifest / JUnit / log / failure summary 的核对结果。
- 未跑：明确说明本机禁止或未授权的重测试类型，以及云端 skipped 的项目。
- 风险：说明哪些功能正确性仍未通过运行时或 UI 操作确认。
