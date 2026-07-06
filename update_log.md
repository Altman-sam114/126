# WWIIHexV0 v 版本更新记录

本文档记录项目从 v0 到 v0.37 的正式 v 版本演进。资料来源包括 `git log`、`README.md`、阶段文档与测试/验收报告。

维护规则：

- 每完成一个新的 v 版本任务后，必须在本文档追加对应版本记录。
- 记录应包含：版本号、完成日期、核心变更、关键文件/系统、验证结果、遗留事项。
- 若本轮只是文档整理、目录迁移、回滚或打捞，不应伪装成新 v 版本；可写入“历史维护记录”。
- 若 README、测试规范或源码语义发生变化，应同步更新本日志。

## v5.2 - 黑海危机默认数据入口切片

完成日期：2026-07-05

核心更新：

- 新增 `black_sea_crisis_1853` / `黑海危机 1853` 首版可加载数据：120 个 hex、40 个 region、6 个参战行动势力、17 个初始单位。
- 新增维多利亚数据草案：`victorian_powers.json`、`victorian_unit_templates.json`、`victorian_personas.json`、`victorian_terrain_rules.json`。
- `DataLoader.loadInitialGameState()` 默认优先加载黑海危机 scenario / regions，阿登资源保留为 legacy fallback。
- `DataLoader` 按 `scenario.id` 选择 unit templates 和 general registry：黑海危机使用 `victorian_*`，legacy 阿登继续使用旧资源。
- `MapEditorGameResourceBridge` 默认读写黑海危机资源，同时保留 legacy 阿登资源常量。
- Xcode project 已把新增 JSON 加入 iOS / macOS app 资源阶段。

关键文件：

- `WWIIHexV0/Data/black_sea_crisis_1853_scenario.json`
- `WWIIHexV0/Data/black_sea_crisis_1853_regions.json`
- `WWIIHexV0/Data/victorian_powers.json`
- `WWIIHexV0/Data/victorian_unit_templates.json`
- `WWIIHexV0/Data/victorian_personas.json`
- `WWIIHexV0/Data/victorian_terrain_rules.json`
- `WWIIHexV0/Data/DataLoader.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`

验证记录：

- 本机轻量检查：新增 JSON `jq empty` 通过；黑海数据一致性脚本通过；`plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过；`swiftc -parse` 已覆盖 `DataLoader.swift` 和 `MapEditorGameResourceBridge.swift`。
- 云端重验证：run `28729942914` attempt `1` 结果包 `WWIIHexV0-ci-v1-main-5d0fca4-run28729942914-attempt1` 已核对，`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`。
- 后续补强：新增 `tools/validate_black_sea_data.py`，并把黑海危机 / 维多利亚 JSON 的 `jq empty` 与交叉引用检查加入 `.github/workflows/ci-results.yml`；后续 push 会由云端结果包复核该补强。

遗留事项：

- 铁路、港口、煤站、电报等 v5.2 语义本轮仅通过道路、城市/要塞、region infrastructure 和 `dataNotes` 表达；正式规则仍留 v5.3-v5.4。
- UI、legacy 胜利 fallback、经济/生产和测试夹具仍有 legacy 二战语义，需要后续 v5.3-v5.9 继续清理。

后续迭代：

- 2026-07-05：补齐黑海危机默认外交关系。`DiplomacyState.initial(... scenarioId:)` 对 `black_sea_crisis_1853` 生成场景化关系：Britain / France / Ottoman / Sardinia 对 Russia 为 `atWar`，联军内部为 `coBelligerent`，Austria 对 Russia 为 `hostile`、对 Ottoman 为 `militaryAccess`，其余保持 neutral；`DataLoader` 和 `StrategicStateBootstrapper` 均传入 `scenarioId`，避免默认新局和空外交兜底把黑海危机退回全中立。
- 2026-07-05：补齐前线层多国家外交敌我判断。`FrontLineManager` 的初始构建、dirty update、动态 hex 接触、包围候选和补给影响可接收 `DiplomacyState`，运行时 `DataLoader`、`StrategicStateBootstrapper`、`StrategicStateSynchronizer` 和 `WarCommandExecutor` 均传入真实外交状态；缺省 nil 保留旧测试和 Probe fixture 兼容，避免黑海危机中非交战但不同国家、共同作战方或 neutral 被误画为前线。
- 2026-07-05：根据 run `28730699270` 结果包修复前线层外交补线的云端构建问题。该 run 的 manifest 显示 `staticChecksOutcome=success`、`buildOutcome=failure`，xcodebuild 报 `WWIIHexV0/Rules/FrontLineManager.swift` 中 `isOperationalOpponent` 的 legacy fallback 分支缺少 `return`；本轮补回返回值，不改变外交状态优先判断逻辑。
- 2026-07-05：补齐黑海危机数据驱动胜利条件。`GameState` 保存 scenario `victoryConditions`，`VictoryRules` 优先执行 `controlObjective`、`controlObjectives`、`holdObjectives` 数据条件，并按外交关系把 allied / coBelligerent 控制计入同一战争目标侧；legacy 阿登无数据条件时继续使用 Bastogne / St. Vith / German armor fallback。新增 `RuleEngineCoreTests` 覆盖黑海条件加载和联军目标控制胜利路径。

## v5.3 - 维多利亚物流规则起步切片

完成日期：2026-07-05

核心更新：

- 新增 `LogisticsTag` 和 `HexTile.logisticsTags`，黑海危机 scenario tile 可显式标注 `rail`、`port`、`coast`、`telegraph`、`expeditionaryDepot`、`siegeDepot`；旧存档/旧测试夹具缺字段时默认空标签。
- `DataLoader` 读取 scenario `logisticsTags`，并可从 `keyLocations.kind == port` 派生港口标签；`tools/validate_black_sea_data.py` 增加物流标签白名单检查。
- `MapState` 增加物流标签查询和港口补给锚点查询；只有本方、allied 或 coBelligerent 控制的港口可作为补给锚点，单纯 `militaryAccess` 不算共同补给。
- `MovementRules` 对相邻双 `rail` hex 使用铁路通行成本；`SupplyRules` 把正式 supply source 与可用港口合并为补给锚点；`CombatRules` 给炮兵攻击城市/要塞增加轻量攻城修正。
- `MapEditorExporter` 对新增可选 `logisticsTags` 字段显式导出 `nil`，保持当前编辑器旧字段导出兼容；正式可编辑港口/铁路字段留后续切片。
- 黑海危机数据标注 Constantinople、Odessa、Varna、Sevastopol、Danube Forts、Balaklava、Bucharest 等关键港口、铁路、电报和围城节点。
- 新增维多利亚单位显示适配：`ComponentType.tank/motorizedInfantry/infantry/artillery` raw value 暂不改名，但玩家可见的 HUD、inspector、tooltip 和 SpriteKit 兵牌语义映射为黑海危机、近卫、骑兵、线列步兵和炮兵口径。
- 新增维多利亚组件 schema 兼容层：`ComponentType` 增加 `lineInfantry`、`guardInfantry`、`cavalry`、`engineers`、`irregulars`、`colonialInfantry`、`supplyTrain`；黑海默认 `victorian_unit_templates.json` 已改用这些组件，legacy `tank/motorizedInfantry/infantry` 继续保留给旧数据和测试。
- `Division.isShockFormation` / `isMobileFormation` 成为维多利亚规则和 AI 的兼容判断；`DataLoader` 对未知 template component type 改为显式 validation error，避免静默丢失组件。
- 经济/生产显示开始脱离二战口径：`EconomyPanelView` 将 `manpower/industry/supplies` 显示为 `Recruits`、`Treasury`、`Stores`，`ProductionKind.displayName` 将 Panzer / Motorized 等兼容 case 显示为近卫旅、骑兵旅、攻城炮兵和补给车队。
- MapEditor 单位模板 picker 改为线列步兵军、近卫旅、骑兵旅、攻城炮兵；导出的 template id 仍保持旧兼容值。

关键文件：

- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Core/MapState.swift`
- `WWIIHexV0/Data/ScenarioDefinition.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/black_sea_crisis_1853_scenario.json`
- `WWIIHexV0/Data/victorian_unit_templates.json`
- `WWIIHexV0/Agents/AgentContexts.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `WWIIHexV0/Tests/RuleEngineCoreTests.swift`
- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorCanvasScene.swift`
- `MapEditor/MapEditorExporter.swift`
- `tools/validate_black_sea_data.py`

验证记录：

- 本机轻量检查：`swiftc -parse` 覆盖本轮 Swift 改动文件通过；`jq empty WWIIHexV0/Data/victorian_unit_templates.json` 通过；`python3 -m py_compile tools/validate_black_sea_data.py` 通过；`python3 tools/validate_black_sea_data.py` 通过，输出 `Black Sea data ok: 120 tiles, 40 regions, 17 units, 6 generals, 4 agents.`。
- 云端重验证：物流规则切片已由 run `28732229919` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-70f45c5-run28732229919-attempt1` 核对通过；显示适配切片已由 run `28732813059` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-5fc74de-run28732813059-attempt1` 核对通过；组件 schema 切片已由 run `28733588844` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-3647145-run28733588844-attempt1` 核对通过。

遗留事项：

- `ComponentType.tank/motorizedInfantry` raw value 仍保留作 legacy 兼容；完整围城状态、多回合封锁、海权、生产 kind raw value 迁移、MapEditor 新字段编辑能力和更完整物流图例仍待 v5.4-v5.7 后续切片。
- 本轮只做规则层最小可观察效果，未引入完整全球市场、完整海军战术或复杂远征状态机。

## v5.4 - 维多利亚生产 taxonomy 起步切片

完成日期：2026-07-05 至 2026-07-06

核心更新：

- `ProductionKind` 新增默认维多利亚生产 case：`lineInfantryCorps`、`guardBrigade`、`cavalryBrigade`、`siegeArtilleryBattery`、`supplyConvoy`。
- `ProductionKind.allCases` 默认只向经济面板暴露维多利亚生产项；legacy `infantryDivision`、`panzerDivision`、`motorizedDivision`、`artilleryDivision`、`supplyStockpile` 保留解码和执行兼容。
- 生产完成逻辑按新旧 case 分组生成线列步兵军、近卫旅、骑兵旅、攻城炮兵或补给车队效果，不绕过 `Command.queueProduction -> RuleEngine -> EconomyRules` 管线。
- `EconomyResources.victorianSummary` 统一经济日志、经济面板成本和 region inspector 输出为 `REC/TRE/STO`，减少默认 UI 中 `MP/IC/SUP` 残留。
- `Division.isInfantryHeavy` 扩展识别 `lineInfantry`、`guardInfantry`、`colonialInfantry` 和 `irregulars`，让维多利亚组件获得既有步兵地形防御规则兼容。
- 新增 `EconomyCommand` 和 `Command.economy(command:)`，支持 `mobilizeReserves`、`raiseWarLoan` 与 `buySupplies` 起步预算/动员动作，经 `CommandValidator`、`CommandExecutor` 和 `EconomyRules` 统一执行。
- `FactionEconomyLedger` 新增 `warDebt` 兼容字段；战争贷款增加 treasury 和 debt，后续回合通过 debt service 消耗 treasury；购买补给消耗 treasury 并增加 stores。
- `mobilizeReserves` 消耗 treasury / stores 并增加 recruits，只改 faction 级经济总账，不直接生成单位或绕过生产/部署规则。
- `EconomyPanelView` 新增 Budget 区块，展示 debt / debt service，并将预算按钮接入 `AppContainer.executeEconomyCommand`。
- `RegionInspectorView` 新增物流只读展示：所选 hex 显示物流标签，region 显示从 hex 聚合得到的标签数量，继续保持 hex 为物流权威。
- 新增 `ConstructionKind.railway`、`ConstructionOrder` 和 `Command.queueConstruction(kind:target:)` 起步切片；铁路工程从经济面板选中 hex 后经 `RuleEngine` 扣费入队，回合结算完成时只给目标 hex 添加 `.rail` 物流标签，不改占领、region、theater、front 或 deploy 权威。
- 新增 `ConstructionKind.fieldWorks` 与 `LogisticsTag.fieldWorks`；野战工事同样从经济面板选中 hex 后经 `RuleEngine` 扣费入队，完成时只给目标 hex 添加 `.fieldWorks` 标签，并由 `CombatRules.terrainDefenseBonus` 提供轻量防御加成，不改任何地图控制权威。
- 新增 `ConstructionKind.portWorks`；港口工程只能排在已有 `.coast` 标签且尚无 `.port` 的己控 hex 上，完成时只给目标 hex 添加 `.port` 标签，并复用现有同盟/共同作战港口补给锚点规则。
- `CommandValidationError` 新增 `invalidConstructionSite`，避免把非 coast 建港等站点约束误报为资源不足。
- `BoardScene` 主地图开始直接渲染可见 hex 上已有 `LogisticsTag`：铁路、港口、煤站、电报、远征 depot、野战工事和围城 depot 显示为小型 SpriteKit 标记；`.coast` 仍作为建港/海岸规则标签，不默认铺满地图。
- `md/flow/flow.md` 同步记录当前经济/生产兼容边界。

关键文件：

- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/TerrainStyle.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `tools/validate_black_sea_data.py`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 本机轻量检查：`swiftc -parse` 覆盖 `EconomyState.swift`、`EconomyRules.swift`、`EconomyPanelView.swift`、`RegionInspectorView.swift` 通过；`git diff --check` 通过；本轮改动文件尾随空白扫描无命中；冲突标记扫描无命中。
- 云端重验证：run `28734509698` attempt `1` 结果包 `WWIIHexV0-ci-v1-main-aa2935a-run28734509698-attempt1` 已核对，`branch=main`、`commitSha=aa2935a684505ba44ef512eff10aef53bf86f9c3`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`；`junit.xml` 为 3 tests、0 failures、1 skipped；`xcodebuild.log` 结尾 `BUILD SUCCEEDED`。
- `EconomyCommand` 预算动作切片已由 run `28735351078` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-f20f409-run28735351078-attempt1` 核对通过；manifest 显示 `branch=main`、`commitSha=f20f409aafce14846ecf03ae3ed7458e4859caa6`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`；`junit.xml` 为 3 tests、0 failures、1 skipped；`xcodebuild.log` 结尾 `BUILD SUCCEEDED`。
- Region inspector 物流展示切片已由 run `28735908770` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-51e1e46-run28735908770-attempt1` 核对通过；manifest 显示 `branch=main`、`commitSha=51e1e46e2d1ba05d935b0ec217aba4cfedf662b6`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`；`junit.xml` 为 3 tests、0 failures、1 skipped；`xcodebuild.log` 结尾 `BUILD SUCCEEDED`。
- 铁路工程建设命令切片已由 run `28736720326` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-321b76f-run28736720326-attempt1` 核对通过；manifest 显示 `branch=main`、`commitSha=321b76f7662a36eeca112dcc66fafc18f0cf7ea8`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`；`junit.xml` 为 3 tests、0 failures、1 skipped；`xcodebuild.log` 结尾 `BUILD SUCCEEDED`。
- 野战工事建设命令切片已由 run `28740861458` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-b7b2b85-run28740861458-attempt1` 核对通过；manifest 显示 `branch=main`、`commitSha=b7b2b857001df5104d31640944c9668c07b4a623`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`；`junit.xml` 为 3 tests、0 failures、1 skipped；`xcodebuild.log` 结尾 `BUILD SUCCEEDED`。
- 港口工程建设命令切片已由 run `28741593559` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-c3c824e-run28741593559-attempt1` 核对通过；manifest 显示 `branch=main`、`commitSha=c3c824e0066d023a60108b14abde999b3c5694a4`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`；`junit.xml` 为 3 tests、0 failures、1 skipped；`xcodebuild.log` 结尾 `BUILD SUCCEEDED`。
- 预备役动员命令切片已由 run `28786905898` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-4c635d4-run28786905898-attempt1` 核对通过；manifest 显示 `branch=main`、`commitSha=4c635d42e7261b1639e08e3a926a78167cf93d3d`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`；`junit.xml` 为 3 tests、0 failures、1 skipped；`xcodebuild.log` 结尾 `BUILD SUCCEEDED`。
- 主地图物流标记切片已由 run `28787785995` attempt `1` 的 artifact `WWIIHexV0-ci-v1-main-c34e29c-run28787785995-attempt1` 核对通过；manifest 显示 `branch=main`、`commitSha=c34e29cfb59576a4c005502f7774226c55cc1672`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`；`junit.xml` 为 3 tests、0 failures、1 skipped；`xcodebuild.log` 结尾 `BUILD SUCCEEDED`。

遗留事项：

- `EconomyResources.manpower/industry/supplies` 内部字段仍保留作兼容；完整国库、工业产能、铁路运输力、船运量和完整战争支持状态机仍待后续 v5.5-v5.7 切片。
- 本轮已引入单 hex 铁路工程、野战工事、港口工程和主地图物流标记；尚未引入舰队整备、铁路运输力、建设上限、完整财政/舆论状态机或可交互物流图例；`warDebt` 仅是最小财政压力字段，不等同完整债务/议会系统。

## v5.5 - 战争目标与舆论压力起步切片

完成日期：2026-07-06

核心更新：

- 新增 `WarSupportAdjustment` 和 `DiplomacyState.adjustWarSupport(for:delta:turn:)`，允许规则层按 faction 调整对应国家的 `CountryProfile.warSupport`，并保持 0-100 边界。
- `EconomyRules.resolveFactionTurn` 在回合经济结算中计算战争债务服务和战略补给短缺压力；`warDebt` 的 debt service 会持续侵蚀战争支持，stores 短缺会叠加支持度惩罚，并通过外交日志记录受影响国家。
- `DiplomacyPanelView` 改为读取完整 `GameState`，在外交面板展示 scenario `victoryConditions` 中的战争目标、目标名称、Open / Holding / Resolved 状态和 hold duration。
- 外交面板国家列表展示 `warSupport`，并对低支持度使用阈值颜色提示。
- `RootGameView` 把 `container.gameState` 传入外交面板，避免 UI 只能看到静态 `DiplomacyState` 而看不到胜利条件和胜利状态。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 功能 commit `57052c9928f149a4cf6aa0d8bf6a1ff6d1b10ded` 已 push 到 `origin/main`。
- 本机轻量检查：`swiftc -parse` 覆盖 `DiplomacyState.swift`、`EconomyRules.swift`、`DiplomacyPanelView.swift`、`RootGameView.swift` 通过；`git diff --check` 通过；本轮改动文件尾随空白扫描无命中；冲突标记扫描无命中。
- 云端重验证：run `28788988901` attempt `1` 结果包 `WWIIHexV0-ci-v1-main-57052c9-run28788988901-attempt1` 已核对，manifest 显示 `branch=main`、`commitSha=57052c9928f149a4cf6aa0d8bf6a1ff6d1b10ded`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=skipped`；`junit.xml` 为 3 tests、0 failures、1 skipped；`xcodebuild.log` 结尾 `BUILD SUCCEEDED`。

遗留事项：

- 本轮是战争目标可视化和战争支持压力桥，不是完整 `DiplomaticPlay`、议会、新闻报纸、战争厌倦、国家级财政或投降谈判系统。
- 经济仍是 faction 级总账，因此 `adjustWarSupport(for faction:)` 会影响该 faction 下所有国家；后续若引入国家级经济账本，需要把支持度压力收窄到具体国家或 coalition 成员。
- 战争目标来源仍是 scenario `victoryConditions`，尚未提供玩家/AI 动态提出、修改或谈判战争目标的命令入口。

后续迭代：

- 2026-07-06：新增 `Siege Depot Works` 围城补给站建设切片。`ConstructionKind.siegeDepotWorks` 从经济面板选中己控 hex 后经 `Command.queueConstruction -> RuleEngine -> EconomyRules` 扣费入队；站点必须邻接外交上可攻击方控制的城市或要塞 hex，完成时只给目标 hex 添加 `.siegeDepot` 物流标签。炮兵从带 `.siegeDepot` 的 hex 攻击城市/要塞时获得轻量攻城准备加成。该切片不改变 hex controller、region controller、`regionToTheater`、`hexToTheater`、`hexToFrontZone` 或前线。
- 2026-07-06：完成黑海默认玩家势力与主路径可见文案清理切片。`AppContainer` 未显式注入 `playerFaction` 时从 `GameState.turnOrder` / `humanControlledFactions` 推导默认玩家视角，黑海危机默认落到 Britain，`resetGame()` 后同步重算；命令门禁新增 `commandFaction` 口径，当前 `activeFaction` 若是人控 action phase，就允许该势力操作，避免 France / Ottoman 人控回合被 AI 跳过后无法命令。主 UI、交互日志、Agent prompt 和 legacy MockAI 可见 intent 将二战/旧口径的 `Allies`、Guderian/Bastogne、`division/unit`、`FrontZone` 标签收敛为 player-controlled formation / command sector 等通用历史策略口径。内部 `Division`、`FrontZone` 和 Guderian legacy fallback 仍保留给旧数据、测试和回归路径。

## v5.6 - 维多利亚 persona AI 指挥链起步切片

完成日期：2026-07-06

核心更新：

- `AgentRole` 增加 `expeditionaryCommander`、`fieldCommander` 与 `generalStaff`，使 `victorian_personas.json` 中 Raglan、Saint-Arnaud、Omar Pasha、Menshikov 等 agent 可实例化为运行时 `GameAgent`。
- 新增 `GameAgent.defaultCommander(for:from:state:)`：默认 AI 身份优先按 faction 从 `victorian_personas.agents` 选择 persona，缺失时使用通用 General Staff，legacy Germany 仍保留 Guderian fallback。
- `AppContainer.bootstrap()` 不再固定构造 Guderian / Germany marshal；它会从当前 `GameState.turnOrder` 与 `humanControlledFactions` 推导默认 AI faction，并为该 faction 构造 persona commander 与 marshal agent。
- `turnManager(for:)` 不再为非 Germany faction 生成 `*_mock_commander`；运行时 AI 审计记录使用 persona id/name，provider 在 UI / 日志中显示为 `Simulated Staff`。
- `MarshalAgentConfig.fromCommander(_:)` 让 AppContainer 默认 marshal theater payload 与 compiled directive envelope 使用同一个 persona id/name；黑海 Russia 默认路径不再在 marshal 审计链中暴露 `marshal_russia` 这类通用占位身份。
- 默认 `.marshalDirective` 路径重新接入受限 Cabinet posture 层：`RulerAgent` 作为兼容承载读取外交/前线/部署摘要，输出 `RulerDecisionRecord`，塑形已编译的 `DirectiveEnvelope`，再交给 `WarCommandExecutor -> RuleEngine`；它不直接修改外交关系、经济账本、hex controller 或单位位置。
- `TacticName.displayName` 为 Agent 面板提供兼容显示名，保留 raw value / JSON schema 不变；默认 UI 中 `blitzkrieg` 显示为 `Rapid advance`。
- `AgentPanelView` 将底层 raw JSON 的可见区改为 `Decision Payload`，展示时把内部 tactic raw value 映射为维多利亚兼容 display name，保留记录中的原始 `rawJSON` 供规则/解码兼容。
- `tools/validate_black_sea_data.py` 增加 persona agent role 白名单检查，避免 JSON / Swift 角色 schema 分叉时 CI 仍误报通过。

关键文件：

- `WWIIHexV0/Agents/GameAgent.swift`
- `WWIIHexV0/Agents/AgentConfiguration.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/Tests/ScenarioDataTests.swift`
- `tools/validate_black_sea_data.py`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

遗留事项：

- 本轮只接入受限 Cabinet posture 层；尚未实现完整 ForeignMinister / WarMinister / Treasury / Admiralty / Press 多角色 directive 链，也尚未实现 DiplomaticPlay 动态外交命令。
- `MockAIClient` 仍是 deterministic provider 实现，作为 `Simulated Staff` fallback 使用；真实 LLM 接入、外交 play directive 和上游内阁 JSON 合同留后续 v5.6-v5.8。

后续迭代：

- 2026-07-06：修复 MapEditor 默认黑海资源 roundtrip 的 scenario metadata 保真风险。`MapEditorDocument` 新增 `MapEditorScenarioMetadata`，`MapEditorGameResourceBridge.loadDefaultDocument()` 从 `black_sea_crisis_1853_scenario.json` 保存 factions、turnOrder、playerFaction、aiFaction、humanControlledFactions、victoryConditions 和 dataNotes；`MapEditorExporter` 优先使用该 metadata 导出，只有新建空白文档才退回 legacy Germany / Allies fallback。`MapEditorOutputTests` 同步改为断言黑海默认 Britain / humanAction / 多国 turn order 和原始胜利条件，避免覆盖默认资源时把黑海剧本退回阿登式 metadata。
- 2026-07-06：新增规则层最小 `DiplomacyCommand.declareWar` 入口。`Command.diplomacy(command:)` 经 `CommandValidator` 限制 action phase、非自身/非 neutral/尚未开战且双方具备 country profile 后，由 `CommandExecutor` 调用 `DiplomacyState.declareWar` 将 active faction 与目标 faction 的全部 country pair 置为 `atWar`，写入 `.diplomacy` 日志并刷新 `FrontLineState` / `WarDeploymentState` 派生层。该切片不直接移动单位、不改变 hex/region controller、不改经济账本，也不是完整 DiplomaticPlay、谈判 UI 或动态战争目标系统。

## v0 - 六角格测试板

完成日期：2026-06-14 至 2026-06-15

核心更新：

- 建立 iOS 二战回合制战棋原型，技术栈为 Swift + SwiftUI + SpriteKit。
- 创建阿登测试战场，使用 11x9 左右的 axial hex 地图。
- 落地地形、移动、战斗、占领、补给、包围、胜利条件、回合流程。
- 建立德军 MockAI 将领 `guderian`，按局势摘要生成结构化命令，再经规则系统校验执行。
- 建立 SwiftUI HUD、命令面板、事件日志、单位详情和 SpriteKit 六角格渲染。

关键系统：

- `Core/HexCoord.swift`
- `Core/MapState.swift`
- `Core/Division.swift`
- `Rules/RuleEngine.swift`
- `Rules/MovementRules.swift`
- `Rules/CombatRules.swift`
- `Rules/SupplyRules.swift`
- `Rules/VictoryRules.swift`
- `SpriteKit/BoardScene.swift`
- `UI/RootGameView.swift`

备注：

- v0 的核心边界是“可玩测试板”，不做空军、海军、经济、生产、外交、多级指挥链和真实 LLM。
- 后续所有版本都必须保留 hex 作为战术层权威。

## v0.1 - strength、撤退与补员

完成日期：2026-06-15 前后

核心更新：

- `Division` 战斗模型升级为 `strength/maxStrength`，保留 `hp/maxHP` 兼容。
- 战斗伤害从 HP 语义转向兵力语义，后续明确不恢复 organization。
- 引入撤退状态与 `RetreatMode`：`retreatable` 可自动撤退，`hold` 获得防御加成。
- 撤退失败会施加额外惩罚；无补给、包围会影响战斗与回合损耗。
- `resupply/rest` 能恢复兵力。
- UI 和日志补充 Strength、Retreating、combat/retreat/reinforce/encircle/supply 分类。

关键系统：

- `Core/Division.swift`
- `Rules/CombatRules.swift`
- `Rules/SupplyRules.swift`
- `Rules/RuleEngine.swift`
- `UI/UnitInspectorView.swift`
- `UI/HUDView.swift`

备注：

- v0.1 最终模型只看兵力，不引入 organization。
- `HOLD` 防御约 +20%，`RETREATABLE` 在单次损失比例达到阈值时自动撤退。

## Agent D - AI/Agent 决策管线

完成日期：2026-06-15

核心更新：

- 打捞并恢复早期 Agent D 管线，修复此前异常删除。
- 建立 `DecisionProvider` 协议，为 MockAI 与未来本地 LLM 共用。
- 建立 `AgentContext` / `AgentContextBuilder`，只传 Codable 摘要，不暴露 UI/SpriteKit 对象。
- 建立 `AgentDecisionEnvelope` / `AgentOrder` JSON schema。
- 建立 parser、command mapper、decision record 与 AI 决策展示面板。
- `TurnManager` 负责德军 AI 回合编排，`AppContainer.runAIIfNeeded()` 接入启动流程。

关键系统：

- `Agents/DecisionProvider.swift`
- `Agents/AgentContexts.swift`
- `Agents/AgentDecision.swift`
- `Agents/AgentDecisionParser.swift`
- `Agents/AgentCommandMapper.swift`
- `Agents/MockAIClient.swift`
- `Agents/LocalLLMDecisionProvider.swift`
- `Turn/TurnManager.swift`
- `UI/AgentPanelView.swift`
- `Tests/AgentPipelineTests.swift`

备注：

- Agent D 是重要历史管线，但 v0.37 后默认战争 AI 主路径已改为 ZoneDirective。
- 后续不得删除 Legacy Agent D；只能隔离、退役或作为回归参考。

## v0.2 - Region 战略层叠加

完成日期：2026-06-15 至 2026-06-16

核心更新：

- 明确废弃旧版“用 province 替换 hex”的方案，改为 Region 战略层叠加。
- `MapState` 同时持有 hex 与 region：`regions`、`hexToRegion`、`regionEdges`。
- 新增 `RegionId`、`RegionNode`、`RegionEdge`、`RegionGraph` 与校验错误类型。
- 建立阿登 v0.2 省份数据：17 省、41 边、99 hex 全覆盖、零重叠。
- `DataLoader` 加载 `ardennes_v02_regions.json` 并反向填充 `HexTile.regionId`。
- 新增 Region 规则层：移动、战斗、占领、补给、视野、胜利、pathfinder、rule system。
- 新增 `RegionCommand`、`CommandIntentAdapter`、AgentOrder schema v2，支持 region 命令与 hex 命令互转。
- UI 增加 `MapDisplayAdapter`、Region overlay 与 `RegionInspectorView`，hex 仍为唯一渲染对象。

关键系统：

- `Core/Region.swift`
- `Core/MapState.swift`
- `Data/RegionDataSet.swift`
- `Data/ardennes_v02_regions.json`
- `Rules/RegionRuleSystem.swift`
- `Rules/RegionMovementRules.swift`
- `Rules/RegionCombatRules.swift`
- `Rules/RegionOccupationRules.swift`
- `Rules/RegionSupplyRules.swift`
- `Rules/RegionVisibilityRules.swift`
- `Rules/RegionVictoryRules.swift`
- `Commands/RegionCommand.swift`
- `Commands/CommandIntentAdapter.swift`
- `SpriteKit/MapDisplayAdapter.swift`
- `UI/RegionInspectorView.swift`

验证记录：

- v0.2 Agent 6 验收：132 tests, 0 failures。
- 关键覆盖：RegionGraph、ArdennesV02Data、Region rules、Agent region command、MapDisplayAdapter、Board interaction、RuleEngineCore。

备注：

- v0.2 达成 Hex x Region 双轨架构稳定状态。
- 技术债：中立省 owner/controller 为 null 时仍回退到 `.allies`，因为 `Faction` 暂无 neutral case。

## v0.21 - 界面优化与重置流程

完成日期：2026-06-16

核心更新：

- 新增 `InfoPanelToggle`，信息面板默认收起，通过 `[ INFO ]` 展开。
- 新增 `UnitTooltipView`，右下角固定展示选中单位摘要。
- 新增 `NewGameButton` 与 `AppContainer.resetGame()`，支持重载初始地图/单位/Region 并清空选择与日志。
- `RootGameView` 在常规、竖屏、横屏布局中接入 Info toggle 与单位 tooltip。
- 任务 6 zoom 按设计跳过，保留固定放大 hex 与 camera drag。

关键系统：

- `UI/InfoPanelToggle.swift`
- `UI/UnitTooltipView.swift`
- `UI/NewGameButton.swift`
- `UI/RootGameView.swift`
- `UI/HUDView.swift`
- `App/AppContainer.swift`

验证记录：

- 135 tests, 0 failures。
- `swiftc -parse`、`plutil -lint`、`git diff --check` 通过。
- 模拟器烟测通过，截图记录为 `/tmp/wwiihex_v021_smoke2.png`。

## v0.31 - Theater 战区系统

完成日期：2026-06-17

核心更新：

- 新增战区数据结构：`TheaterId`、`TheaterNode`、`TheaterState`、支援请求和 AI 摘要。
- 新增 `TheaterSystem`，从 v0.2 Region 生成四个固定战区。
- 建立 `hex -> region -> theater` 映射与控制比例/胜利点聚合。
- 引入 70% 控制阈值，用于战区扩张正式化、退役和单位池重分配。
- 在 `GameState` 中加入 `theaterState`，兼容旧存档解码。
- `DataLoader` 在加载 Region 后自动生成 v0.31 四战区。

关键系统：

- `Core/Theater.swift`
- `Rules/TheaterSystem.swift`
- `Core/GameState.swift`
- `Data/DataLoader.swift`
- `Tests/TheaterSystemTests.swift`

验证记录：

- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过。
- 全量测试：146 tests, 0 failures。

备注：

- v0.31 不做 FrontLine、自动布防、攻势规划、LLM 决策、UI 重构或战斗/hex 规则改动。

## v0.32 - FrontLine 前线层

完成日期：2026-06-17

核心更新：

- 新增前线模型：`FrontLine`、`FrontSegment`、`RegionFrontState`、`FrontLineState`。
- 新增 `FrontLineManager`，支持 turn rebuild 与 event-driven dirty update。
- 建立 `enemyNeighborCache`，简化包围识别。
- 单战区面对多敌战区时，仍暴露一条主 `FrontLine` 给 AI/UI 聚合使用。
- `GameState` 增加 `frontLineState` 并兼容旧存档 empty。
- `DataLoader` 初始加载 Region/Theater 后生成 FrontLine。

关键系统：

- `Core/FrontLine.swift`
- `Core/FrontSegment.swift`
- `Core/RegionFrontState.swift`
- `Core/FrontLineState.swift`
- `Rules/FrontLineManager.swift`
- `Tests/FrontLineCreationTests.swift`
- `Tests/FrontLineUpdateTests.swift`
- `Tests/MultiEnemyFrontTests.swift`

验证记录：

- v0.32 专项测试：9 tests, 0 failures。
- 全量测试：155 tests, 0 failures。
- `project.pbxproj` lint 通过。

备注：

- v0.32 未改 UI、SpriteKit、AI agent、LLM、命令系统、RegionGraph 或 TheaterSystem 结构。

## v0.33 - WarDeployment 部署层

完成日期：2026-06-17

核心更新：

- 新增 `FrontZone`、`FrontZoneSegment`、`WarDeploymentState` 与 `WarDeploymentManager`。
- 从 v0.31 Theater 生成 v0.33 `FrontZone`。
- 建立 region 粒度前线 segment 与 `FRONT / DEPTH / GARRISON` 三层单位池。
- 支持推进、崩溃、战区消亡与事件更新。
- dirty region + neighbor zone 局部重建，避免每次全图前线扫描。
- 新增前线、segment、部署、战争演化和局部更新性能测试。

关键系统：

- `Core/FrontZone.swift`
- `Core/FrontZoneSegment.swift`
- `Core/WarDeploymentState.swift`
- `Core/WarDeploymentTypes.swift`
- `Rules/WarDeploymentManager.swift`
- `Tests/WarDeploymentFrontLineTests.swift`
- `Tests/WarDeploymentSegmentTests.swift`
- `Tests/WarDeploymentDeploymentTests.swift`
- `Tests/WarEvolutionTests.swift`

验证记录：

- v0.33 选定测试：13 tests, 0 failures。
- 全量测试：168 tests, 0 failures。
- `plutil -lint` 通过。

备注：

- v0.33 未改 UI/SpriteKit、AI/LLM/命令系统，也未引入复杂路径搜索。

## v0.331 - v0.31 至 v0.33 总测试

完成日期：2026-06-18

核心更新：

- 对 v0.31 战区、v0.32 前线、v0.33 部署进行阶段集成测试。
- 清理和巩固测试 fixture，使战区、前线、部署三层能稳定共同回归。
- 优化探针检测，准备后续地图编辑器和战争命令系统接入。

关键系统：

- `Tests/TheaterSystemTests.swift`
- `Tests/FrontLine*Tests.swift`
- `Tests/WarDeployment*Tests.swift`
- `Tests/Stage035CampaignSimulationTests.swift`

备注：

- 本阶段主要是集成验收和测试基线整理，不是新玩法版本。

## v0.34 - 地图编辑器

完成日期：2026-06-18 至 2026-06-19

核心更新：

- 在 `MapEditor/` 下加入项目专属地图编辑器骨架。
- 使用 SwiftUI 管理工具面板，SpriteKit 管理六角格交互视口。
- 编辑器直接导出项目自有 `ScenarioDefinition` 与 `RegionDataSet` JSON，不再引入 Tiled 中间件。
- 新增 macOS 独立 target `MapEditorMac`。
- 支持地块、省份、战区、初始部队编辑。
- `DataLoader` 增加任意文件名加载入口和 MapEditor 输出专用加载路径。
- 地形补充 `hill`，并同步 `terrain_rules.json`、颜色和 inspector 显示。

关键系统：

- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorHexMath.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorViewModel.swift`
- `MapEditor/MapEditorCanvasScene.swift`
- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorMacApp.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `Tests/MapEditorOutputTests.swift`

验证记录：

- `MapEditorOutputTests` 覆盖编辑器输出到 `GameState` 的集成链路。

## v0.341 - macOS 独立编辑器

完成日期：2026-06-18

核心更新：

- 新增 `MapEditorMac` target，作为独立 macOS app 运行。
- 默认窗口适配宽屏/全屏地图编辑。
- 左侧 SwiftUI split panel 管理地图、模式、参数、文件操作。
- 右侧 SpriteKit canvas 渲染六角格。
- 支持鼠标拖拽连续涂色、滚轮/触控板缩放、右键/中键/Option+左键平移。
- 默认工作流读写 `WWIIHexV0/Data/ardennes_v0_scenario.json` 与 `ardennes_v02_regions.json`。

备注：

- MapEditor 不接入 iOS 主入口，避免污染游戏 app 启动流程。

## v0.342 - 地图编辑器中文化与显式编辑流

完成日期：2026-06-18

核心更新：

- 地图编辑器左侧面板改为中文。
- 模式拆成：地块、省份、战区、部队。
- 各模式采用统一 `添加 / 删除 / 完成 / 取消` 显式编辑会话。
- 切换模式会取消当前编辑会话，避免误操作。
- 分层显示只突出当前模式相关数据。
- `MapEditorOutputTests.testEditorSessionActionsReflectInGameState` 覆盖地块、省份、战区、部队完整编辑与导出读取。

## v0.343 - 地图编辑器视口稳定、稀疏扩图与快捷键

完成日期：2026-06-18

核心更新：

- 平移改用 view-space 指针增量，避免 camera 移动导致拖动抖动。
- 滚轮/触控板缩放以鼠标所在 scene point 为锚点，减少视口漂移。
- `MapEditorDocument.contains(_:)` 改为判断实际存在 hex，支持稀疏地图。
- 地块模式新增扩展地块动作，允许在已有 hex 邻位生成新 hex。
- 删除 hex 会清理该 hex 上的初始部队，并移除空 region/theater assignment。
- region/theater 名称由 UI 输入，内部 ID 自动递增。
- 新增快捷键：`N` 添加，`M` 完成。

验证记录：

- `MapEditorOutputTests` 扩展覆盖自动 ID、邻接扩展、虚空造地失败、删除清理、平移/缩放数学。

## v0.344 - 地图编辑器交互修复、信息面板与底图层

完成日期：2026-06-19

核心更新：

- macOS 画布改用 `NSViewRepresentable + SKView`，直接接收 `keyDown`。
- 修复 SpriteKit 抢焦点后 SwiftUI `Button.keyboardShortcut` 不稳定的问题。
- 滚轮缩放与水平/Shift 滚轮平移接入 `SKView.scrollWheel`。
- 右键短按选择 hex，并在左侧信息面板展示/编辑坐标、地形、道路、region、theater 信息。
- Region/Theater 颜色改用固定高对比色板按 ID hash 取色。
- 新增编辑器底图层：导入图片、设置透明度、缩放和位置；底图不写入游戏 JSON。

验证记录：

- `MapEditorOutputTests` 扩展覆盖快捷键、右键信息选择、名称保存、底图文档状态与移动增量。

## v0.351 - 初步战争命令系统

完成日期：2026-06-19

核心更新：

- 新增战争指令协议：`DirectiveEnvelope` / `ZoneDirective`。
- 新增 `WarCommandExecutor`，将 zone 级 attack/defend 意图翻译为底层 `Command`。
- 新增 `MockAICommander`，按兵力比阈值输出 attack/defend。
- AI 指令与玩家命令最终都走 `RuleEngine` / `CommandValidator` 校验执行。
- 为后续 LLM 输出 JSON 指令预留协议层。

关键系统：

- `Commands/WarDirective.swift`
- `Commands/WarCommandExecutor.swift`
- `Agents/MockAICommander.swift`
- `Core/WarDirectiveRecord.swift`
- `Tests/CommandSystemTests.swift`

备注：

- v0.351 只是初级战争命令，不做复杂战术、撤退命令、装甲差异化或真实 LLM。

## v0.352 - 新管线唯一化、观察者模式与分层 UI

完成日期：2026-06-19

核心更新：

- 新增/强化 `WarPipelineMode.zoneDirective`，默认战争 AI 走新 ZoneDirective 管线。
- Legacy Agent D 保留但不作为默认战争 AI 主路径。
- 引入观察者模式，支持双方由 AI 自动对战，但回合推进仍受玩家操作控制。
- 新增 `WarDirectiveRecord`，记录 directive、结果、诊断和 UI 回放信息。
- UI 支持 hex/province/theater/frontLine 等图层切换。
- `MockAICommander` attack 阈值从 1.5 调整到 1.2，使战局更容易推进。

关键系统：

- `Core/WarPipelineMode.swift`
- `Turn/TurnManager.swift`
- `App/AppContainer.swift`
- `Core/WarDirectiveRecord.swift`
- `Core/MapDisplayLayer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`

## v0.353 - 默认地图验收与归属权威重构

完成日期：2026-06-19

核心更新：

- 默认地图接入真实战局模拟验收。
- 确立 hex controller 为归属权威。
- region controller、theater 控制比例、补给站归属改为从 hex controller 派生。
- 避免继续依赖静态阵营标签判断动态占领结果。
- 观察者模式下新地图可用于战争模拟和回归测试。

关键系统：

- `Rules/OccupationRules.swift`
- `Rules/StrategicStateSynchronizer.swift`
- `Rules/TheaterSystem.swift`
- `Rules/RegionOccupationRules.swift`
- `Tests/ObserverModeIntegrationTests.swift`
- `Tests/Stage035CampaignSimulationTests.swift`

备注：

- 本阶段是后续 v0.354/v0.355 修复“AI 不动、联动不及时、占领不对称”的地基。

## v0.354 - 联动修复、拒绝率治理与玩家/AI 对称性

完成日期：2026-06-19 至 2026-06-20

核心更新：

- 修复占领后 region、theater、frontline、visibility 不在同一回合联动的问题。
- 修复 ZOC 友军穿越误判，避免友军互相阻挡。
- 定位“德军若干回合后不动”的真实病灶：推进过深的部队被部署层误判为 garrison，从前线兵力池消失。
- 统一玩家与 AI 的占领判定入口，避免 AI 能占玩家地、玩家不能占 AI 地的不对称。
- 改善 RuleEngine 拒绝率诊断，避免非法命令被静默吞掉。

关键系统：

- `Rules/OccupationRules.swift`
- `Rules/StrategicStateSynchronizer.swift`
- `Rules/WarDeploymentManager.swift`
- `Rules/CommandValidator.swift`
- `Commands/WarCommandExecutor.swift`
- `Tests/WarEvolutionTests.swift`
- `Tests/ObserverModeIntegrationTests.swift`

备注：

- v0.354 期间有多轮 debug 与修复提交，包括 `v0.354 优化1`、`v0.354修复`、`0.354debug`。

## v0.355 - 动态/初始战区分离、前线 UI 与观察者收尾

完成日期：2026-06-20 至 2026-06-23

核心更新：

- 正式分离 `TheaterState.initialSnapshot` 与运行时动态战区状态。
- 修复战区阵营身份不能从动态控制比例反推的问题。
- 图层拆分为 `hex`、`province`、`initialTheater`、`dynamicTheater`、`frontLine`。
- 前线 overlay 改为按 `FrontSegment` 连线绘制。
- 观察者模式开关接入主界面 UI。
- 执行 20 回合观察者模式模拟与阶段分析，记录 directive、拒绝原因、省份换手和补给/包围趋势。

关键系统：

- `Core/Theater.swift`
- `Core/MapDisplayLayer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`
- `UI/RootGameView.swift`
- `Tests/Stage035CampaignSimulationTests.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`

验证记录：

- 历史记录显示 v0.355 阶段曾达到 Probe 9/0、Smoke 4/0、Stage Regression 63/0、Full 198/0。
- 20 回合观察者模拟：57 条 directive，拒绝率约 10%，主要拒绝原因为移动力不足与无路径。

备注：

- 文档 `0.355-迄今概览.md` 记录该阶段架构总结与后续注意事项。

## v0.356 - 默认资源一致性与前线 UI 修正

完成日期：2026-06-24

核心更新：

- DEBUG 下 `DataLoader` 优先读取源码 `WWIIHexV0/Data/*.json`，避免编辑器覆盖保存后游戏仍读取旧 bundle 资源。
- 新增默认资源一致性测试，确保编辑器 document、导出 JSON、游戏加载后的 `hexToRegion`、`regionToTheater`、`tile.regionId`、`region.name` 一致。
- 前线 UI 改为在我方动态战区侧绘制，用 `segment.regionA` 内接敌 hex 的中心点连线。
- 不同 theater 前线使用固定不同基色。
- 每个 segment 单独绘制，并在 segment 起点加分隔符，避免被看成一整条红线。

验证记录：

- 定向 MapEditorOutputTests + Stage0355DynamicTheaterTests：10 tests, 0 failures。
- Probe：9 tests, 0 failures。
- Smoke：4 tests, 0 failures。
- Full regression：200 tests, 0 failures。
- `git diff --check` 通过。

备注：

- 如果模拟器中仍运行旧 app 进程，需要重新运行 app 才会读到 DEBUG 源码 JSON。

## v0.357 - 地图视角、开局单位与前线 UI 修正

完成日期：2026-06-24

核心更新：

- 修复地图编辑器与游戏内视角上下颠倒/不一致问题。
- 修复部队初始部署异常与跨阵营战区问题。
- 修正开局不应立即让 AI 自动行动的行为，开局应先显示真实初始部队状态。
- 继续优化前线 UI，使动态战区、segment 与视觉表达一致。

关键系统：

- `MapEditor/*`
- `Data/DataLoader.swift`
- `App/AppContainer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`

## v0.358 - 动态 hex 战区语义收口

完成日期：2026-06-24

核心更新：

- 确认核心语义：`regionToTheater` 是初始/基础战区映射，`hexToTheater` 是运行时动态战区权威。
- 单位占领一个 hex 只推进该 hex 的动态战区归属，不能把整个 region 拖入进攻方 theater。
- 部署层同步引入/强化 `hexToFrontZone`，避免 region 粒度误判 FRONT/DEPTH/GARRISON。
- 前线改按动态 hex 邻接生成，测试 fixture 必须构造真实相邻 hex，不能只声明 region 邻接。
- AI target、WarDeployment、overlay、probe 和 stage tests 同步适配动态 hex 语义。

关键系统：

- `Core/Theater.swift`
- `Core/WarDeploymentState.swift`
- `Rules/TheaterSystem.swift`
- `Rules/FrontLineManager.swift`
- `Rules/WarDeploymentManager.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

备注：

- 这是 v0.3 主线的重要铁律：运行时动态战区跟 hex 走，不跟 region 走。

## v0.359 - 前线 UI 优化

完成日期：2026-06-25

核心更新：

- 继续优化前线 overlay 的可读性。
- 强化不同战区/不同 segment 的视觉区分。
- 保留 encirclement/collapsing 等警示状态的红色与加粗表达。
- 使前线 UI 更接近真实动态战区接触，而不是静态 region/theater 边界。

关键系统：

- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`
- `UI/RootGameView.swift`

## v0.3510 - 颜色优化

完成日期：2026-06-25

核心更新：

- 优化地图分层 UI 的颜色表达。
- 强化 province、initialTheater、dynamicTheater、frontLine 等 layer 的辨识度。
- 避免相邻 region/theater 颜色过近导致误判。

关键系统：

- `SpriteKit/TerrainStyle.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`

备注：

- 该版本号沿用提交历史中的 `v0.3510`，语义上属于 v0.35x UI 收尾序列，不是 v0.351 的子补丁。

## v0.3511 - UI 修复优化

完成日期：2026-06-25

核心更新：

- 继续修复和优化主游戏 UI。
- 配合 v0.359/v0.3510 的颜色和前线显示调整，改善可读性。
- 为 v0.36 命令层扩展前的界面状态收口。

关键系统：

- `UI/*`
- `SpriteKit/*`

备注：

- 该版本号同样来自提交历史，属于 v0.35x 收尾序列。

## v0.36 - 命令层扩展与多将领 MockAI

完成日期：2026-06-25

核心更新：

- `ZoneDirective` 扩展 `CommandCategory`、`TacticName`、`DirectiveTarget`。
- 新增 `ZoneCommanderAgent`，每个动态战区可由独立将领 agent 生成 directive。
- 新增 `BinaryTacticClassifier`，在 `standardAttack` 与 `holdPosition` 之间做初步分类。
- 新增 `TheaterCommanderPool`，为动态战区提供将领配置，未知新战区使用 fallback commander。
- `WarDirectiveRecord` 增加 category、tactic、commanderAgentId、commandTarget 等字段，便于回放和审计。
- `MockAICommander` 转为兼容 facade，不作为未来扩展主入口。
- 修复旧测试 fixture，使其符合 v0.358 动态 hex 邻接语义。

关键系统：

- `Commands/WarDirective.swift`
- `Commands/WarCommandExecutor.swift`
- `Core/WarDirectiveRecord.swift`
- `Agents/ZoneCommanderAgent.swift`
- `Agents/MockAICommander.swift`
- `Turn/TurnManager.swift`
- `App/AppContainer.swift`
- `Tests/CommandSystemTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

验证记录：

- Probe：17 tests, 0 failures。
- Stage Regression：63 tests, 0 failures。
- Full Regression：213 tests, 0 failures。
- 静态检查：`plutil`、`xmllint`、`jq`、`git diff --check` 通过。

备注：

- `AttackIntensity` 字段仍存在，但没有实际分流执行逻辑。
- 战区互助接口仍无调用方。
- 真 LLM 尚未接入。

## v0.37 - 命令层统一整合

完成日期：2026-06-27

核心更新：

- 默认战争 AI 路径收口为：

```text
TheaterCommanderPool -> ZoneCommanderAgent -> ZoneDirective -> WarCommandExecutor -> RuleEngine -> WarDirectiveRecord
```

- 移除 `TurnManager` 中 `MockAICommander` fallback，避免默认路径语义模糊。
- `.zoneDirective` 分支只通过显式 `commanderPool` 或 `TheaterCommanderPool.automatic(for:)` 产生 envelope。
- Legacy Agent D 只在显式 `.legacyAgentOrder` 或测试回归中使用。
- 保留 `MockAICommander` 作兼容/阈值行为测试用途，但不再作为 `TurnManager` 默认备用入口。
- 确认 `WarCommandExecutor.execute(_ directive:in:)` 不依赖具体 `ZoneCommanderAgent` 实例，手写合法 `ZoneDirective` 可直接执行。
- 新增 v0.37 手写 directive 探针，为 v0.4 玩家 UI 共用命令管线预留后端能力。
- 决定将撤退命令、突破/闪电战、装甲差异化、`AttackIntensity` 实际分流推迟到 1.x。

关键系统：

- `Turn/TurnManager.swift`
- `Commands/WarCommandExecutor.swift`
- `Commands/WarDirective.swift`
- `Agents/ZoneCommanderAgent.swift`
- `Agents/MockAICommander.swift`
- `Core/WarDirectiveRecord.swift`
- `Tests/CommandSystemTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

验证记录：

- Probe：18 tests, 0 failures。
- CommandSystemTests：15 tests, 0 failures。
- Stage Regression：69 tests, 0 failures。
- Full Regression：226 tests, 0 failures。

备注：

- v0.37 是命令层地基工程，不新增玩法机制。
- v0.4 可以在此基础上接玩家聊天/命令 UI，但必须继续共用 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。

## v0.5 - 元帅层、模拟 LLM JSON 与决策链规范化

完成日期：2026-07-04

目标分支：`v0.5-marshal-decision-chain`

分支审计：本轮开始时创建并切换过该分支；后续轻量审计中当前 checkout 先后显示为 `v0.9-ruler-diplomacy`、`v0.4-generals-command-ui-resume`、`v1.1-macos-main-game`、`v1.0-ui-ai-playtest` 等非 v0.5 分支，且工作树已有多批其他版本未提交改动。用户同意切换后，当前 checkout 已确认回到 `v0.5-marshal-decision-chain`；合并前仍必须审查 dirty worktree 中非 v0.5 文件归属和文件级冲突。

核心更新：

- 新增元帅层 `MarshalAgent`，在战区将军上游读取降维战场摘要并产出战役级意图。
- 默认战争 AI 管线升级为：

```text
MarshalAgent
  -> MarshalBattlefieldSummarizer
  -> SimulatedMarshalLLMClient
  -> TheaterDirectiveDecoder
  -> TheaterDirectiveCompiler
  -> ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
```

- 新增 `TheaterDirectiveEnvelope` / `TheaterDirective` 作为 v0.5 LLM-facing JSON schema。
- 新增 `TheaterDirectiveDecoder`，支持 fenced JSON 提取、`JSONDecoder` 解码、schemaVersion / issuer / turn / faction / zone / region / tactic-category 校验。
- 新增 `SimulatedMarshalLLMClient`，只模拟 LLM 接口和 JSON 输出，不接真实网络、本地模型或云端 API。
- 新增 `TheaterDirectiveCompiler`，把元帅意图降级为现有 `ZoneDirective`；缺失或失败时 fallback 到 `TheaterCommanderPool`。
- `WarPipelineMode` 新增 `.marshalDirective`，`AppContainer` 和 `TurnManager` 默认使用该模式；旧 `.zoneDirective` 和 `.legacyAgentOrder` 仍保留为显式路径。
- `TurnManager` 抽出公共 `executeDirectiveEnvelope`，确保元帅链路和旧将军池链路共享同一执行、记录和 endTurn 逻辑。
- v0.5 收口时移除 v0.9 旁支曾插入的 `RulerAgent` 塑形调用；该历史切片当时的 `.marshalDirective` 与显式 `.zoneDirective` 都不写统治者记录，统治者仅作为未来方向记录。v5.6 主线已重新接入受限 Cabinet posture 层，见本文件 v5.6 段。
- 新增实现记录文档，详细写明本分支算法、边界、fallback 和轻量验证。

关键系统：

- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Core/WarPipelineMode.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `md/prompt/anti生成/v0.5/anti/0.50_v0.5_marshal_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`

验证记录：

- `git rev-parse --abbrev-ref HEAD`：`v0.5-marshal-decision-chain`。
- 轻量单文件语法检查通过：
  - `swiftc -parse WWIIHexV0/Commands/WarDirective.swift`
  - `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`
  - `swiftc -parse WWIIHexV0/Turn/TurnManager.swift`
  - `swiftc -parse WWIIHexV0/App/AppContainer.swift`
  - `swiftc -parse WWIIHexV0/Core/WarPipelineMode.swift`
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty` 已通过：
  - `WWIIHexV0/Data/ardennes_v02_regions.json`
  - `WWIIHexV0/Data/general_agents.json`
  - `WWIIHexV0/Data/generals.json`
  - `WWIIHexV0/Data/terrain_rules.json`
  - `WWIIHexV0/Data/unit_templates.json`
- 文档尾随空白扫描：无命中。
- 旧默认测试口径扫描（`AGENTS.md`、`md/flow/flow.md`）：无命中。
- Cabinet/Minister 旧污染源码扫描：无命中。
- v0.5 当前文档与 `TurnManager` 的 `RulerAgent` 默认接入残留扫描：无命中。
- `git diff --check`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md` 与 `md/test/test.md` 规定默认只做轻量检查，且本轮用户明确禁止跑 Xcode。

备注：

- 本轮没有恢复历史回退的 `CabinetState`、`DirectiveBoard`、`MinisterDecisionProvider`、`RulerDirectiveFactory`、`national_cabinet.json` 或部长系统。
- 统治者层仅作为未来元帅上游预留方向，不在 v0.5 当前实现中落地。
- 当前工作树还存在不属于本 v0.5 核心目标的高级战术、外交、经济、UI 和地图编辑器方向未提交改动；v0.5 实现选择兼容现有工作树，不回滚其他改动。

## v0.8 - 初级经济、生产、城市、地形与补兵

完成日期：2026-07-04

目标分支：`codex/v0.8-economy-production`

分支审计：本轮早期创建 v0.8 分支曾因 `.git` 写入权限受限失败；期间当前 checkout 先后观察到其他版本分支，且工作树已有多批其他版本未提交改动。最终已通过受控审批成功创建 `codex/v0.8-economy-production`，但创建后仍观察到外部 checkout 漂移。因此本记录描述当前工作树中的 v0.8 经济系统实现，合并前必须重新确认当前分支、分支基点、文件级冲突、public API 冲突和 Xcode project 引用。

核心更新：

- 新增 `EconomyState`，建立 faction 级 manpower、industry、supplies 总账、生产队列、上回合收入/维护费/补员消耗。
- 新增 `EconomyRules`，从真实己方 hex 控制证据、region 城市、工厂、基础设施和补给值聚合收入。
- `GameState` 增加 `economyState`，旧存档缺失时 fallback `.empty`。
- `StrategicStateBootstrapper` 与 `RuleEngine` 在需要时 bootstrap 经济总账，保证旧状态第一次执行命令也有经济账本。
- `Command` 新增 `queueProduction(kind:)`，经 `CommandValidator` 检查 phase 和资源，经 `CommandExecutor` 调 `EconomyRules.queueProduction` 预付成本并入队。
- `CommandExecutor.executeEndTurn` 增加 active faction 经济结算：收入、战略补给维护费、短缺降级、自动补兵、生产队列推进和完成部署。
- 自动补兵只处理本阵营、未毁灭、未撤退、supplied、非敌邻、strength 未满的单位，每回合每单位最多恢复 2 strength，按兵种权重扣资源。
- 生产完成单位只能部署到本方控制、passable、空置、非敌邻，且位于首都、城镇/大都会、工厂、高基建、高补给 region 或 supply source 的后方 hex；找不到安全部署点时订单保留。
- `BaseTerrain`、`MovementRules`、`CombatRules` 增加地形加成：装甲进困难地形额外移动成本，装甲攻击平原加成，攻击困难地形惩罚，步兵在森林/城市/堡垒防御加成。
- 新增 `EconomyPanelView`，`RootGameView` 接入 Economy tab，`HUDView` 展示经济摘要，Region inspector 展示城市等级和经济产出。
- `project.pbxproj` 当前已有 `EconomyState.swift`、`EconomyRules.swift`、`EconomyPanelView.swift` 引用，未新增重复 UUID。
- 新增 v0.8 实现记录，详细写明规则算法、接入点、非目标、轻量检查和风险。

关键系统：

- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/RuleEngine.swift`
- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `md/prompt/anti生成/v0.8/anti/0.80_v0.8_economy_implementation_record.md`
- `md/prompt/anti生成/v0.8/anti/0.80_overall_analysis_report.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 轻量 Swift parse 通过：
  - 核心规则集合，含 `EconomyState.swift`、`EconomyRules.swift`、`GameState.swift`、`Command.swift`、`CommandValidator.swift`、`CommandExecutor.swift`、`RuleEngine.swift`、`StrategicStateBootstrapper.swift`、`MovementRules.swift`、`CombatRules.swift` 等。
  - 核心规则集合 + `PlatformStyles.swift` + `EconomyPanelView.swift`。
  - 核心规则集合 + `MapDisplayAdapter.swift` + `PlatformStyles.swift` + `EconomyPanelView.swift` + `HUDView.swift` + `RegionInspectorView.swift`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过。
- 改动文档尾随空白检查：通过。
- 旧默认测试口径残留检查：通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范和用户要求均禁止本轮主动跑 Xcode 与重测试。

备注：

- v0.8 不接真实 LLM 经济部长、不做完整商品价格网、不恢复 organization、不做空军/海军/战略轰炸/工厂损毁。
- `RegionDataSet.toRegions()` 仍有历史 fallback：owner/controller 缺失最终落到 `.allies`。v0.8 经济收入已加真实 hex 控制守卫，但数据层中立语义建议后续单独修。
- 当前 AI 不会主动排产；规则层已支持 active faction 通过统一 `Command` 排产，AI 经济策略留后续版本。

## v1.0 - UI / AI / 初版试玩收口

完成日期：2026-07-04

分支：`v1.0-ui-ai-playtest`

分支审计：续接收尾时当前 checkout 曾显示为 `v1.1-macos-main-game`，切回 `v1.0-ui-ai-playtest` 后又在轻量检查期间漂到 `v0.9-ruler-diplomacy` 和 `v0.5-marshal-decision-chain`。`v1.0-ui-ai-playtest` 分支已存在且与当前基线一致；交付前最后一次即时核对显示当前分支为 `v1.0-ui-ai-playtest`。由于当前工作树存在外部 checkout 漂移风险，合并前必须重新做分支与冲突审查。

核心更新：

- 创建并切换到 1.0 分支，围绕主游戏 UI、MockAI 行为、轻量性能和试玩记录做收口。
- `AgentPanelView` 接入 `WarDirectiveRecord`，AI tab 现在展示 zone、directive type、tactic、成功/拒绝命令数、目标 region 和 diagnostics。
- `EventLogView` 改为 `LogDisplayEntry` 展示模型，最近 60 条日志每条只计算一次分类，并补充 diplomacy 日志分类。
- `BoardScene.drawUnits` 缓存单位显示 hex 后排序，部署图层复用同一个 `WarDeploymentManager` 计算 role。
- `WarCommandExecutor` 开始解释 `AttackIntensity.infiltration`，无显式投入上限时限制默认投入单位数；佯攻/袭扰保留低投入策略。
- `PlatformStyles` 补充跨平台面板样式；Economy / Diplomacy 面板收口到跨平台背景和更可读字号。
- 新增 1.0 分支实现记录，写明 UI、性能、MockAI、试玩观察点、风险和未跑重测试原因。

关键系统：

- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `md/prompt/anti生成/v1.0/anti/1.00_v1.0_ui_ai_playtest_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- `git branch --show-current`：切回后曾返回 `v1.0-ui-ai-playtest`，但后续轻量检查期间又返回 `v0.9-ruler-diplomacy` 和 `v0.5-marshal-decision-chain`；分支漂移未完全消除。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- `git diff --check`：通过，无输出。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/anti生成/v1.0/anti/1.00_v1.0_ui_ai_playtest_implementation_record.md`：无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md`：无命中。
- 冲突标记扫描（AGENTS.md、README.md、update_log.md、md/flow、WWIIHexV0、MapEditor）：无命中。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是 `AGENTS.md`、`md/test/test.md` 和用户要求均禁止本轮主动跑重测试。

备注：

- 本轮并发子 agent 中 UI 只读定位完成，AI / 性能子 agent 因外部 503 失败，主线程接回实现。
- 当前工作树仍含 v0.5 / v0.7 / v1.1 等方向未提交改动，合并前必须做文件级、public API、schema、Xcode project 和文档口径冲突审查。

## v0.9 - 统治者、多国家、阵营集团与初步外交状态

完成日期：2026-07-04

分支：`v0.9-ruler-diplomacy`

核心更新：

- 新增 `DiplomacyState`，在 `GameState` 中保存国家、阵营集团、国家间外交关系和统治者决策记录。
- 新增 `CountryProfile`、`DiplomaticBloc`、`DiplomaticRelation`、`DiplomaticStatus`、`RulerStrategicPosture`、`RulerDecisionRecord` 等数据结构。
- 开局外交种子：
  - Germany 规则阵营：`German Reich`，`Axis`，`ruler_germany`。
  - Allies 规则阵营：`United States`、`United Kingdom`、`Belgium`，`Allied Coalition`，主统治者 `ruler_allies`。
  - 同阵营关系为 `allied`，跨阵营关系为 `atWar`。
- 新增 `RulerAgent`：读取外交、前线、部署、历史战争指令记录，生成 `RulerStrategicSnapshot`，选择 `offensive` / `defensive` / `coalitionMaintenance` / `stabilizeFront` 姿态。
- `RulerAgent` 只塑形 `DirectiveEnvelope`：
  - offensive：攻击强度提升为 `allOut`，按 region priority 重排目标。
  - defensive：攻击 directive 转为 `holdLine` 防御 directive。
  - coalitionMaintenance：提高防御预备队。
  - stabilizeFront：降低 `allOut` 为 `limitedCounter`，或采用 `flexible` 防御。
- `TurnManager` 在 `.marshalDirective` 与显式 `.zoneDirective` 路径中执行 `applyRuler`，写入 `RulerDecisionRecord` 和 `.diplomacy` 日志后，再交给 `WarCommandExecutor -> RuleEngine`。
- `DataLoader` 和 `StrategicStateBootstrapper` 会为新局或旧存档补齐外交状态。
- 新增 `DiplomacyPanelView`，`RootGameView` 增加 `Diplomacy` 面板，`AgentPanelView` 展示最近统治者 posture / focus。
- `GameLogCategory` 新增 `diplomacy`。
- 修复 `RulerStrategicSnapshot` 静态去重调用；修复 `hostileCountryIds(to:)` 在多盟友共享同一敌国时重复计数的问题。
- 新增 v0.9 实现记录，详细写明本分支算法、边界、冲突情况和未跑重测试原因。

关键系统：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Core/GameLogEntry.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `md/prompt/anti生成/v0.9/anti/0.90_v0.9_ruler_diplomacy_implementation_record.md`

验证记录：

- `git branch --show-current`：`v0.9-ruler-diplomacy`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/anti生成/v0.9/anti/0.90_v0.9_ruler_diplomacy_implementation_record.md`：无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md`：无命中。
- 冲突标记扫描（README.md、update_log.md、md/flow、v0.9 实现记录与相关 Swift 文件）：无命中。
- `swiftc -parse WWIIHexV0/Core/DiplomacyState.swift WWIIHexV0/Agents/RulerAgent.swift WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范与本轮用户要求均禁止主动跑 Xcode 和重测试。

备注：

- 本轮尝试把国家/外交、AI 管线、文档三块拆给子 Agent 并行，但子 Agent 调用返回 503，没有可用产物；最终由主 Agent 在当前分支内完成实现和整合。
- 当前工作树已有 v0.5 元帅层、经济层、v1.1 macOS target、地图编辑器和 UI 等未提交改动；v0.9 选择兼容当前源码，不回滚其他改动。合并前仍需做文件级冲突审查。
- 多国家当前是战略身份层，底层规则阵营仍是 `Faction.germany` / `Faction.allies`。后续若要国家级参战、中立、投降、宣战或外交行动，需要先设计国家级权限和命令入口。

## v1.1 - 主游戏 macOS target

完成日期：2026-07-04

分支：`v1.1-macos-main-game`

核心更新：

- 新增独立主游戏 macOS app target `WWIIHexV0Mac`，区别于既有 iOS 主游戏 target `WWIIHexV0` 和地图编辑器 target `MapEditorMac`。
- 新增 macOS 主入口 `WWIIHexV0MacApp`，复用 `AppContainer.bootstrap()` 与 `RootGameView(container:)`，默认窗口 1440x900，最小内容区域 1200x760。
- `WWIIHexV0Mac` resource phase 接入主游戏默认 JSON：`ardennes_v0_scenario.json`、`ardennes_v02_regions.json`、`general_agents.json`、`generals.json`、`terrain_rules.json`、`unit_templates.json`。
- `BoardSceneView` 增加 macOS `NSViewRepresentable` 分支，用 `BoardEventSKView` 承载 `BoardScene`，iOS 继续使用 `UIViewRepresentable` 分支。
- `BoardScene` 增加 macOS 鼠标点击、拖拽平移、滚轮/触控板缩放；点击仍只回调 `onHexTapped`，后续由 `AppContainer.handleBoardTap -> RuleEngine` 处理。
- 新增 `PlatformStyles`，将主游戏 UI 的 `Color(.systemBackground)` / `Color(.tertiarySystemBackground)` 替换为 iOS/macOS 条件背景色。
- 因当前工作树已有经济、外交、统治者、将领 registry 等源码引用，`project.pbxproj` 同步把这些已被引用的支持文件和 `generals.json` 接入相关 target phase，但本轮不改这些业务逻辑。
- 新增 v1.1 实现记录，详细写明 target 设计、输入桥接算法、资源加载、轻量检查和风险。

关键系统：

- `WWIIHexV0.xcodeproj/project.pbxproj`
- `WWIIHexV0/App/WWIIHexV0MacApp.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/BoardSceneView.swift`
- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `md/prompt/anti生成/v1.1/anti/1.10_v1.1_macos_main_game_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`

验证记录：

- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / macOS app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范与用户要求均禁止本轮主动跑 Xcode 和重测试。

备注：

- v1.1 是平台承载和输入桥接分支，不改变 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 规则权威链路。
- 当前工作树存在多条其他方向的未提交改动；v1.1 选择兼容当前源码引用并记录风险，不回滚其他人改动。

## v0.7 - 高级战术与命令扩展

完成日期：2026-07-04

目标分支：`v0.7-tactical-upgrade`

分支审计：本轮曾创建并切换到 `v0.7-tactical-upgrade`，但连续接力时当前 checkout 多次显示为其他分支，且工作树已有多批 v0.5 / v1.0 / v1.1 / UI / 经济 / 外交方向未提交改动。按项目规则，本轮未回滚这些改动；合并前必须重新确认分支归属和文件级冲突。

核心更新：

- `TacticName` 扩展为进攻 8 类、防御 4 类：
  - 进攻：`standardAttack`、`blitzkrieg`、`spearhead`、`breakthrough`、`pincerMovement`、`fireCoverage`、`feint`、`guerrillaWarfare`。
  - 防御：`holdPosition`、`elasticDefense`、`defenseInDepth`、`lastStand`。
- `AttackParameters` 新增 `focusRegionId`、`supportRegionIds`、`convergenceRegionId`、`coordinatedZoneIds`、`maxCommittedUnits`、`exploitDepth`，支持定点突破、钳形会师、投入上限和纵深目标意图。
- `DefenseParameters` 新增 `fallbackRegionIds`、`counterattackRegionIds`、`strongpointRegionIds`、`maxFrontCommitment`，支持弹性防御、纵深防御和死守口径。
- `TheaterDirective` 新增 `convergenceRegionId` / `coordinatedZoneIds`，并补自定义 decode，旧 JSON 缺字段时仍兼容。
- `TheaterDirectiveDecoder` 校验 convergence region 和 coordinated zone 存在性，继续校验 tactic/category 一致性。
- `BinaryTacticClassifier` 从二元分类升级为读取兵力比、机动兵力、炮兵支援、纵深预备队、压力和补给警告的战术分类器。
- `TacticConditionChecker` 从恒 true 改为按战术最低条件放行：机动战术要求机动单位，火力覆盖要求炮兵/远程单位，佯攻要求前线单位，纵深防御要求 depth 预备队。
- `WarCommandExecutor` 新增 `AttackTacticProfile`，按战术控制单位来源、机动优先、炮兵优先、只攻击不推进、弱点聚焦、深目标候选、非矛头单位 hold 和投入上限。
- 定点突破弱点评分落地：

```text
enemyStrength 越低越优先
terrain.movementCost 越低越优先
region 内有 road 越优先
city.victoryPoints + supplyValue + factories 越高越优先
guerrillaWarfare 额外参考 infrastructure
```

- `defenseInDepth` 新增独立执行路径：一线 `allowRetreat`，保留预备队，其余 depth 机动单位尝试反击，否则向 fallback / strongpoint 防御地形移动。
- `fireCoverage` 落地为炮兵/远程优先、能打则打、无目标则 hold，不主动推进。
- `feint` 落地为少量前线单位牵制，默认约 1/3 前线投入。
- `blitzkrieg` / `spearhead` 落地为机动优先、集中弱点、可使用 depth 单位，非矛头前线单位 hold。
- `pincerMovement` 落地为 convergence / coordinated 数据层和单 zone 执行器 profile；多 zone 会师由元帅层或人工下发多条 directive，包围效果交给动态战区/前线/补给派生。
- `MockAICommander` 保留新增 attack 参数，避免 allOut 包装时丢失 focus/convergence/coordinated 字段。
- 新增 v0.7 实现记录文档，详细写明算法、边界、冲突风险和轻量检查口径。

关键系统：

- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Agents/MockAICommander.swift`
- `md/prompt/anti生成/v0.7/anti/0.70_v0.7_tactical_upgrade_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/flow/03_ai_zone_directive_pipeline.mermaid`
- `README.md`

验证记录：

- 轻量单文件语法检查通过：
  - `swiftc -parse WWIIHexV0/Commands/WarDirective.swift`
  - `swiftc -parse WWIIHexV0/Commands/WarCommandExecutor.swift`
  - `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`
  - `swiftc -parse WWIIHexV0/Agents/MockAICommander.swift`

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md` 与 `md/test/test.md` 规定默认只做轻量检查，且本轮用户明确禁止跑 Xcode。

遗留风险：

- 未做运行时战局验证，战术效果和 AI 行为只通过源码与轻量 parse 检查确认语法层可用。
- 当前工作树混有其他版本改动，合并前必须做文件/API/schema/文档冲突检查。

## v0.4 - 将军养成初步、将军 UI 与玩家双轨命令

完成日期：2026-07-04

目标分支：`v0.4-generals-command-ui-final`

分支审计：本轮从一个已混入 v0.9 / v0.5 / v1.x 外部未提交改动的工作树创建 0.4 续作分支。期间 checkout 又被外部切到 `codex/v0.8-economy-production`，最终已重新固定到 `v0.4-generals-command-ui-final`。按项目规则，本轮没有回滚外部改动；只在当前分支继续补齐 0.4 将军和玩家命令链路。合并前必须重新审查 project、public API、JSON schema 和文档口径冲突。

核心更新：

- 新增实体将军数据链：`generals.json`、`GeneralData`、`GeneralRegistry`、`GeneralDispatcher`。
- `RegionNodeDefinition` / MapEditor region draft 支持 `assignedGeneralId`，默认阿登 region JSON 已给蒙哥马利、魏刚、古德里安、里布写入初始种子。
- `FrontZone` 增加 `generalAssignment`，记录将军 id、HQ region、辖下 division、忠诚、满意度和玩家干预次数。
- `WarDeploymentState.preservingGeneralAssignments` 与 AppContainer 刷新逻辑保留/补齐将军分配，避免部署层重建后将军丢失。
- `TheaterCommanderPool` 在 AppContainer 构造时可由 `GeneralDispatcher.commanderPool` 使用真实将军配置，缺失时仍 fallback 到自动 commander。
- 新增 `PlayerCommandState` 和 `PlayerPlannedOperation`，保存本回合微操锁和玩家战区计划。
- 玩家微操 move/attack/hold/resupply/allowRetreat 成功后锁定该师，降低所属将军满意度并增加干预次数；结束回合或阵营/回合变化时清空锁。
- `WarCommandExecutor.execute` 新增兼容参数 `excluding excludedDivisionIds`，在进攻、防御、纵深防御和非矛头 hold 阶段跳过玩家微操部队。
- `AppContainer` 新增玩家宏观将军命令：`Hold Line` 生成 defense `ZoneDirective`，`Attack Region` 根据当前选中敌方 region 和相邻玩家 FrontZone 生成 attack `ZoneDirective`，执行后不自动结束回合。
- 新增 `GeneralCommandPanelView` 与 `GeneralProfileView`，展示将军头像占位、军衔、风格、技能、履历、忠诚/满意度、HQ 状态、辖下部队和计划操作。
- `RootGameView` 新增 `General` tab，Unit tab 也嵌入将军命令面板。
- `BoardScene` 根据 `PlayerPlannedOperation` 画进攻箭头/防御圆环，`UnitNode` 对本回合玩家微操单位画金色圈。
- `WarDirectiveRecord` 记录玩家宏观指令结果，AI 面板与日志可继续共用同一复盘数据。

关键系统：

- `WWIIHexV0/Data/generals.json`
- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/Core/GeneralAssignment.swift`
- `WWIIHexV0/Core/PlayerCommandState.swift`
- `WWIIHexV0/Core/FrontZone.swift`
- `WWIIHexV0/Core/WarDeploymentState.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/RegionDataSet.swift`
- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/anti生成/0.4/v0.4_generals_command_ui_branch_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- `jq empty WWIIHexV0/Data/generals.json` 通过。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json` 通过。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- `git diff --check` 通过。
- 文档尾随空白检查无匹配。
- 单文件轻量 parse 通过：`PlayerCommandState.swift`、`GeneralAssignment.swift`、`GeneralRegistry.swift`、`GeneralCommandPanelView.swift`、`GeneralProfileView.swift`、`WarCommandExecutor.swift`、`AppContainer.swift`、`BoardScene.swift`、`UnitNode.swift`、`RootGameView.swift`。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md`、`md/test/test.md` 和用户要求均禁止本轮主动跑 Xcode 与重测试。

遗留风险：

- 未做运行时 UI 点击和 SpriteKit 视觉验证，按钮行为、sheet 展示、计划线位置仍需后续人工或授权轻量运行确认。
- 当前工作树混有其他版本改动，合并前必须重新做文件/API/schema/project 冲突审查。

## 历史维护记录

以下提交不作为正式 v 版本，但影响项目资料完整性：

- 2026-06-15：重整 `md` 目录，添加 README，补充 v0.1-v1.0 提示词。
- 2026-06-15：打捞 Agent D 与误删代码，恢复 AI 决策管线。
- 2026-06-15：记录 v0.5 擅自编程与回退资料，保留为历史警示；当前主线不得引入 Cabinet/StrategicDirective/Minister 污染。
- 2026-06-18：整理文档结构，将已完成阶段文档迁入 `md/prompt/...（已完成）`。
- 2026-06-24 至 2026-06-25：补充 0.36 提示词、0.355 截止分析、20 回合文档更新。
- 2026-06-27：创建 `AGENT.md`，写入后续 Codex 接手项目时的架构、测试、文档维护和交付规则。
- 2026-07-04：更新当前协作规范：默认禁止 Xcode / XCTest / 模拟器 / 性能类重测试，只做轻量语法/格式检查；新增多版本分支、并发子 Agent 和合并前冲突检查规则。关键文件：`AGENTS.md`、`md/test/test.md`、`md/flow/flow.md`、`README.md`、`md/prompt/v0.f/fable-5-重构优化总提示词.md`。
- 2026-07-04：新增拿破仑战争迁移总提示词，规划 v3.0-v3.8 从 WWIIHexV0 迁移为 AI Agent 驱动拿战游戏的版本路线、最终发布效果、并发子 Agent 分工、轻量检查和风险边界。关键文件：`md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md`。
- 2026-07-04：新增明末迁移总提示词，规划 v4.0-v4.8 从 WWIIHexV0 迁移为 AI Agent 驱动明末历史策略游戏的产品目标、版本路线、最终发布效果、并发子 Agent 分工、轻量检查和风险边界。关键文件：`md/prompt/v4.0-明末迁移/codex-v4.0-明末aiagent迁移总提示词.md`。
- 2026-07-04：新增唐宋迁移总提示词，规划 v5.0-v5.9 从 WWIIHexV0 迁移为 AI Agent 驱动唐宋时代历史策略游戏的首发剧本、产品目标、架构边界、版本路线、并发子 Agent 分工、轻量检查和发布验收标准。关键文件：`md/prompt/v5.0-唐宋迁移/codex-v5.0-唐宋aiagent历史策略迁移总提示词.md`。
- 2026-07-04：新增维多利亚迁移总提示词，规划 v5.0-v5.9 从 WWIIHexV0 迁移为 AI Agent 驱动维多利亚时代历史策略游戏的 `蒸汽帝国 Agent` / `Steam & Empire Agent Strategy` 路线、首发 `black_sea_crisis_1853` / `黑海危机 1853` 剧本、产品目标、架构边界、版本路线、并发子 Agent 分工、轻量检查和发布验收标准。关键文件：`md/prompt/v5.0-维多利亚迁移/codex-v5.0-维多利亚时代aiagent历史策略迁移总提示词.md`。
- 2026-07-04：新增现代战争迁移总提示词作为历史候选资料，规划 v6.0-v6.10 现代联合指挥策略游戏方向；该资料不作为当前 `md/plan/plan.md`、`README.md`、`AGENTS.md` 的默认迁移主线。关键文件：`md/prompt/v6.0-现代战争迁移/codex-v6.0-现代战争aiagent迁移总提示词.md`。
- 2026-07-04：协作流程制度升级为 `main` 直推 + GitHub Actions 云端重验证 + Agent C 下载未加密结果包验收。此记录只表示协作和验证骨架变化，不代表业务功能质量已通过新一轮运行时验证。关键文件：`AGENTS.md`、`README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/prompt/README.md`、`.github/workflows/ci-results.yml`。本轮采用 AITRANS 的云端结果包和 Agent C 复判制度，未迁入其漫画探针、GGUF、模型 Release、`smalldata_test` 或 PR 流项目特例。
- 2026-07-04：纠正此前误按 `codex-v6.0-现代战争aiagent迁移总提示词.md` 同步的项目口径，改为根据 `codex-v5.0-维多利亚时代aiagent历史策略迁移总提示词.md` 重写 `md/plan/plan.md` 项目 MD 大纲，并同步 `README.md`、`AGENTS.md` 的基本描述：当前代码基线仍是 WWIIHexV0，v5 路线目标是 `蒸汽帝国 Agent` / `Steam & Empire Agent Strategy`。此为文档大纲整理，不代表 v5.x 业务代码已实现。
- 2026-07-05：完成 v5.0 维多利亚迁移审计合同文档，记录当前二战硬编码、二元阵营、旧 phase、旧资源、旧单位、旧 UI 文案和默认数据残留，明确 v5.1-v5.5 的执行边界和风险文件。关键文件：`md/prompt/v5.0-维多利亚迁移/v5.0_audit_and_contract.md`、`md/plan/plan.md`。本轮为文档审计迭代，不代表 Swift / JSON 业务迁移已实现。
- 2026-07-05：新增 v5.1 多国家、通用回合、外交关系和敌我判断执行提示词，要求先处理 `Faction` / `GamePhase` / `CommandValidator` / `CommandExecutor` / `DataLoader` / neutral fallback 等架构风险，再进入 v5.2 黑海危机数据默认化。关键文件：`md/prompt/v5.0-维多利亚迁移/v5.1_powers_turns_diplomacy_prompt.md`、`md/plan/plan.md`。此为下一轮实现入口，不代表 v5.1 Swift 迁移已完成。
- 2026-07-05：优化维多利亚迁移总提示词，将 v5.0-v5.9 路线对齐当前 `main` 直推、GitHub Actions 未加密结果包和 Agent C 复判制度；补充当前配套文档状态、Agent A/B/C 交接合同、阶段提示词完成定义和交付字段。关键文件：`md/prompt/v5.0-维多利亚迁移/codex-v5.0-维多利亚时代aiagent历史策略迁移总提示词.md`。本轮仅为文档总控迭代，不代表 v5.1 或后续业务代码已实现。
- 2026-07-05：继续完善维多利亚迁移总提示词，新增数据与 schema 迁移合同、运行时迁移优先级和总提示词完成/维护规则，明确新 JSON、id、legacy 数据、MapEditor 导出、neutral controller 和阶段路线的边界。关键文件：`md/prompt/v5.0-维多利亚迁移/codex-v5.0-维多利亚时代aiagent历史策略迁移总提示词.md`。本轮仍为文档-only 迭代，不代表黑海危机数据或 v5.1 代码已实现。
- 2026-07-05：本地落地 v5.1 多国家、通用回合和外交敌我判断基础切片：`Faction` 扩展为 legacy Germany / Allies 加 Britain、France、Russia、Ottoman、Austria、Sardinia、Neutral；`GamePhase` 增加 `humanAction` / `aiAction` / `diplomacyResolution`；`GameState` 增加 `turnOrder`、`humanControlledFactions` 和通用 next faction/action phase；`DiplomacyState` 增加 `canAttack`、`canEnterTerritory`、Victoria country profiles 和 legacy Germany/Allies 默认 atWar；`DataLoader`、`ScenarioDefinition`、`RegionDataSet`、`CommandValidator`、`CommandExecutor`、`WarCommandExecutor`、AI/补给/经济/部署/UI/MapEditor 若干路径改为使用外交关系或 neutral fallback。同步更新 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/plan/plan.md` 和维多利亚总提示词的状态口径。未跑本机 Xcode / XCTest / 模拟器 / Probe / Smoke / Full；本切片尚未 commit、push、GitHub Actions 和 Agent C artifact 验收。
- 2026-07-05：修复 `WWIIHexV0 CI Results` 结果包脚本在 macOS bash 下生成 failure summary 时的 `printf` 兼容问题。上一轮 commit `f3fd448` 已 push 到 `origin/main` 并触发 run `28716014937`，artifact `WWIIHexV0-ci-v1-main-f3fd448-run28716014937-attempt1` 上传成功，但 workflow 在 failure summary 阶段因 `printf '- Branch...'` 被解释为选项而失败；本轮改为 `printf '%s\n' ...` 安全输出，确保后续 CI 能暴露真实 static/build 结果。
- 2026-07-05：根据 run `28728057587` 结果包继续修复 v5.1 云端构建问题。该 run 的 manifest 显示 `staticChecksOutcome=success`、`buildOutcome=failure`，xcodebuild 报 `WWIIHexV0/Agents/ZoneCommanderAgent.swift` 中 `MarshalBattlefieldSummarizer.visibleEnemyRegionIds` 找不到 `isEnemyControlled`；本轮把同名外交敌控 helper 补入 summarizer 作用域，保持元帅摘要敌我判断通过 `DiplomacyState.canAttack`。
- 2026-07-05：根据 run `28728164979` 结果包继续修复 v5.1 云端构建问题。该 run 的 manifest 显示 `staticChecksOutcome=success`、`buildOutcome=failure`，xcodebuild 报 `WWIIHexV0/Core/GameState.swift` 中 `actionPhase(for:)` 缺少 `return`；本轮补回通用多国家 action phase 返回值，保持旧 Germany / Allies 兼容 phase 之外的 faction 走 `GamePhase.actionPhase(for:humanControlledFactions:)`。
- 2026-07-05：根据 run `28728322925` 结果包继续修复 v5.1 云端构建问题。该 run 的 manifest 显示 `staticChecksOutcome=success`、`buildOutcome=failure`，xcodebuild 报 `WWIIHexV0/Commands/WarCommandExecutor.swift` 中 `defensiveDestination` 的候选 hex 链式表达式类型检查超时；本轮将表达式拆成显式 region/hex 循环，保持原有筛选条件和排序逻辑。
- 2026-07-05：继续推进 v5.1 部署层多国家敌我判断：`WarDeploymentManager` 的前线接触、敌控 region/hex 和 unit role 判断可接收 `DiplomacyState`，运行时 DataLoader、StrategicStateBootstrapper、StrategicStateSynchronizer、CommandExecutor、WarCommandExecutor、SpriteKit 展示适配器均传入真实外交状态；缺省参数保留旧测试和 Probe fixture 兼容，避免非交战但参战的维多利亚国家被部署层误判为敌军前线。同时修正 `DataLoader.initialActiveFaction`、`MapEditorGameResourceBridge` 和 `WarCommandExecutor.applyStrategicAdvance` 中默认 fallback 到 `.allies` / `.germany` 的多国家不安全行为，改为优先读取有效 scenario faction 或 neutral / no-op。
- 2026-07-05：根据 run `28728891932` 结果包修复 v5.1 部署层外交状态补线的云端构建问题。该 run 的 manifest 显示 `staticChecksOutcome=success`、`buildOutcome=failure`，xcodebuild 报 `WWIIHexV0/Data/DataLoader.swift` 把 `diplomacyState` 参数传给不接收该参数的 `FrontLineManager.makeInitialState`；本轮把参数移动到紧随其后的 `WarDeploymentManager.makeInitialState`。
- 2026-07-05：根据 run `28729121627` 结果包继续修复 v5.1 云端构建问题。该 run 的 manifest 显示 `staticChecksOutcome=success`、`buildOutcome=failure`，xcodebuild 报 `WWIIHexV0/Rules/WarDeploymentManager.swift` 中 `isOperationalOpponent` 的 legacy fallback 分支缺少 `return`；本轮补回返回值，不改变外交状态优先判断逻辑。
