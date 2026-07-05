# WWIIHexV0 / Steam & Empire Agent 项目 MD 大纲

本文是 `md/` 目录的项目路线大纲。当前代码仍是 WWIIHexV0 二战 hex 战棋工程；v5.0 起按维多利亚时代历史策略方向迁移，目标产品暂定为 `蒸汽帝国 Agent` / `Steam & Empire Agent Strategy`。大纲依据 `md/prompt/v5.0-维多利亚迁移/codex-v5.0-维多利亚时代aiagent历史策略迁移总提示词.md`，只整理规划与文档口径，不代表对应业务代码已经实现。

## 1. 当前工程基线

当前项目是 Swift + SwiftUI + SpriteKit 的 iOS / macOS 回合制 hex 战棋工程。主链路为：

```text
MapEditor / JSON 数据
  -> DataLoader
  -> GameState
  -> HexTile.controller + Division.coord
  -> Region 聚合
  -> EconomyState 收入 / 生产 / 补员
  -> DiplomacyState 草案
  -> Initial Theater snapshot + runtime hexToTheater
  -> FrontLine 动态 hex 接触
  -> WarDeployment hexToFrontZone + FRONT/DEPTH/GARRISON
  -> MarshalAgent / TheaterDirective JSON
  -> TheaterDirectiveDecoder / TheaterDirectiveCompiler
  -> ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
  -> StrategicStateSynchronizer
  -> UI / SpriteKit / 日志 / WarDirectiveRecord
```

核心权威边界：

- Hex 仍是战术权威：真实占领、单位位置、移动、攻击、视野和补给落点以 hex 为准。
- Region 是战略聚合层，不替代 hex。
- `regionToTheater` 是初始/基础战区归属，不是运行时推进权威。
- `hexToTheater` 是运行时动态战区权威。
- `hexToFrontZone` 是部署层动态归属权威。
- 玩家、AI、聊天命令和 MockAI 必须落到 `Command` / `ZoneDirective`，再经 `WarCommandExecutor`、`CommandValidator`、`RuleEngine` 执行。
- Legacy Agent D 保留作回归参考，默认战争 AI 主路径不得退回旧管线。

当前历史包袱与已落地切片：

- v5.1 已把 `Faction` 扩展到 legacy Germany / Allies 加 Britain、France、Russia、Ottoman、Austria、Sardinia、Neutral，并新增 `humanAction` / `aiAction`、`turnOrder`、`humanControlledFactions` 和 `DiplomacyState.canAttack` / `canEnterTerritory` 入口；commit `2919c49` 已通过 GitHub Actions 结果包验收。
- v5.2 已开始把默认入口切到 `black_sea_crisis_1853`：新增黑海危机 scenario / regions、`victorian_powers.json`、`victorian_unit_templates.json`、`victorian_personas.json`、`victorian_terrain_rules.json`，并保留阿登为 legacy fallback。
- `Faction.opponent` 已不应再作为主路径敌我判断；后续新代码必须继续通过 `DiplomacyState` 或后续外交规则判断可攻击/可通行。
- `FrontLineManager` 运行时路径已接入 `DiplomacyState`，前线接触、包围候选和补给影响不再仅凭不同 faction 判断敌我；旧测试/Probe fixture 仍可通过缺省 nil 保持 legacy 兼容。
- `Division`、`tank`、`motorizedInfantry`、`Panzer Division`、阿登、Germany、Allies、Bastogne、Guderian、Montgomery、Manpower、Industry、Supplies 等二战语义仍存在于 legacy 数据、UI 或源码兼容名中。
- `RegionDataSet.toRegions()` 的 nil owner/controller fallback 已改为 `.neutral`；后续迁移仍不得把 nil / neutral fallback 到 legacy 双方。
- project 文件和文档已多轮多分支修改；任何合并或迁移前必须做文件/API/schema/project/文档冲突审查。

## 2. 当前协作与验证大纲

默认协作流程：

```text
人工目标
  -> Agent A 本地分析并写版本化提示词
  -> Agent B 基于最新 origin/main 在 main 上实现
  -> Agent B 本机只跑轻量检查
  -> Agent B commit 并 push 到 origin/main
  -> GitHub Actions 云端重验证并上传未加密结果包
  -> Agent C 下载结果包核对 manifest / JUnit / 日志 / run id
  -> 失败则 Agent B 在 main 追加修复 commit
  -> 通过则 Agent C 更新核心文档
```

本机默认只做轻量检查：

- Markdown 尾随空白检查。
- 冲突标记扫描。
- `git diff --check`。
- JSON 使用 `jq empty`。
- project 文件使用 `plutil -lint`。
- 少量纯 Swift 改动可尝试 `swiftc -parse`，但不得扩大为全项目 build。

默认不在本机主动执行：

- `xcodebuild build/test/build-for-testing`。
- 模拟器、UI test、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full。
- 性能测试、全量 lint、全量格式化。

## 3. 维多利亚最终产品目标

工作名：

- 中文：`蒸汽帝国 Agent`
- 英文：`Steam & Empire Agent Strategy`

时代范围：

- 约 1837-1901 年的维多利亚时代。
- 第一版不做完整全球七十年沙盒，先用范围可控的危机剧本证明系统。

首发推荐剧本：

```text
scenarioId: black_sea_crisis_1853
displayName: 黑海危机 1853
时间范围：1853-1856 克里米亚战争的抽象战役窗口
地图范围：黑海、克里米亚、多瑙河口、巴尔干北缘、高加索西缘、君士坦丁堡方向
主要势力：俄罗斯帝国、奥斯曼帝国、大英帝国、法兰西第二帝国、奥地利帝国、撒丁王国、中立小邦/地方势力
规模：120-220 个 hex，35-70 个 region，8-16 个战区/军区/远征军防区
回合：18-36 回合，代表季度或战役阶段
```

选择黑海危机的原因：

- 能体现大国外交、远征军、港口、海上补给、堡垒围攻、铁路/电报早期影响、舆论和财政压力。
- 地图范围可控，不需要第一版做全球全量省份。
- 多方 AI 差异明显：俄罗斯追求黑海和巴尔干影响，奥斯曼保卫海峡和多瑙防线，英法远征和海上封锁，奥地利摇摆施压，撒丁寻求参战换取外交收益。
- 现有 hex / region / theater / front / deploy 层可复用，海军和全球市场首版可用 off-map 影响层表达。

最终体验关键词：

- 维多利亚时代战略桌面：雕版世界地图、铁路、电报线、港口、煤站、报纸战报、内阁文件夹、外交照会、议会压力、军令电报、红蓝铅笔推进箭头。
- 工业动员、铁路补给、港口与海权、外交危机、列强干预、财政预算、威望、战争支持和舆论压力。
- AI Agent 通过可审计 JSON 指令协作决策；所有行动仍被统一规则系统约束。
- UI 玩家可见层面不再出现主要二战文案残留。

## 4. 迁移总原则

保留：

- Hex / Region / Theater / FrontLine / WarDeployment 分层架构。
- `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 统一执行管线。
- `WarDirectiveRecord`、`AgentDecisionRecord`、`RulerDecisionRecord` 审计记录。
- MapEditor 的稀疏 hex、region、theater、unit 编辑与导出能力。
- iOS 主游戏、macOS 主游戏、macOS 地图编辑器方向。
- 模拟 LLM / MockAI fallback 思路：真实模型不可用时仍能 deterministic 地推进游戏。
- 当前轻量检查和未授权不跑重测试规则。

替换或抽象：

- `Faction.germany/allies` -> 多国家/多势力体系；短期可扩展 enum，长期目标是 `PowerId` / `CountryId` / `Faction` 兼容桥。
- `Faction.opponent` -> `DiplomacyState` / `PowerRelation` / `WarRelationRules` / `DiplomaticPlayState`。
- `GamePhase.germanAI/alliedPlayer` -> `humanAction` / `aiAction` / `resolution` / `diplomacyResolution` 等通用阶段。
- `Division` 玩家可见语义 -> 军团、师、旅、远征军、殖民旅、守备队。
- 二战兵种 -> 线列步兵、近卫步兵、骑兵、炮兵、工兵、非正规军、殖民部队、补给纵队。
- 经济显示 -> 兵源/可动员人口、国库、工业产能、军需补给、铁路运输力、船运量、威望、战争支持。
- 生产 -> 动员步兵师、炮兵旅、骑兵旅、工兵队、补给车队、港口补给、铁路工程、要塞修筑、舰队整备。
- Theater / FrontZone 显示 -> 军区、远征军区、殖民辖区、作战区、防线。
- Marshal / Ruler / General 数据 -> 总参谋部、陆军大臣、远征军总司令、君主/首相/内阁首脑、外交官、大臣、总督、实业家等人物体系。

禁止：

- 不做一次性大规模重命名后凭感觉修编译。
- 不让任何 Agent 直接改 `GameState` 权威字段。
- 不绕过 `WarCommandExecutor`、`CommandValidator`、`RuleEngine`。
- 不删除 Legacy Agent D。
- 不把 region 当成战术权威；进军、攻击、围城、占领仍必须落到 hex。
- 不第一版就做完整世界地图、完整全球市场、完整海军战术、完整殖民系统、完整意识形态政治、完整 1837-1901 全时间线。
- 不把殖民扩张写成无成本的正面叙事；必须呈现财政、舆论、外交和地方反抗的代价。
- 不硬编码真实 LLM API key、模型路径或网络端点。

## 5. 维多利亚系统大纲

### 5.1 势力、国家和集团

短期可以保留源码 `Faction` 名称作为兼容层，但目标语义改为“规则控制方”。首发建议至少支持：

- Britain / 大英帝国。
- France / 法兰西第二帝国。
- Russia / 俄罗斯帝国。
- Ottoman / 奥斯曼帝国。
- Austria / 奥地利帝国。
- Sardinia / 撒丁王国。
- Neutral / 中立小邦与地方势力。

长期迁移为数据驱动：

```text
PowerId / CountryId
  -> displayName
  -> governmentType
  -> capitalRegionId
  -> greatPowerRank
  -> prestige
  -> treasury
  -> rulingInterest
  -> primaryCulture / acceptedCultures
  -> aiProfile
  -> color / flag / mapPattern
```

敌我判断不能写成 `faction != otherFaction`；是否可攻击必须结合外交关系、战争状态、通行权、保护国、停战、远征协定、殖民冲突和中立规则。

### 5.2 地图层

```text
Hex
  -> 战术格：城市、港口、铁路节点、要塞、山地、河流、道路、海岸、煤站

Region
  -> 省份/州/战略节点：人口、工业、财政、补给、港口、铁路、威望点、民族/宗教/治安标签

Theater
  -> 军区/远征军区/殖民辖区：克里米亚远征军、多瑙军区、高加索军区、君士坦堡防区

FrontLine
  -> 前线接触：真实动态战区相邻 hex 形成战线，不等于省界

WarDeployment
  -> 前线部队、预备队、驻防/要塞守军
```

首版海军不做完整战术舰队格斗。海权先通过港口、海上补给、封锁状态、远征军登陆许可和 off-map sea lane 表达。

### 5.3 军事规则层

- `strength` 继续代表战斗力，不恢复 organization。
- `supplyState` 显示为补给/弹药/粮秣状态。
- `RetreatMode.hold/retreatable` 显示为固守/可撤。
- 步兵：稳定，适合守线和攻城。
- 近卫：强战斗力和高士气，高维护费。
- 骑兵：侦察、追击、平原机动强，对要塞/山地/堑壕弱。
- 炮兵：围城、压制和火力准备强，机动差，弹药消耗高。
- 工兵：修铁路、破坏铁路、围城、渡河和要塞攻坚加成。
- 非正规军/地方武装：维护低、地形适应强，正面战斗和补给组织弱。
- 殖民部队：适合特定地形，但政治/舆论风险在后续经济政治层表达。
- 堑壕/要塞：首版可作为地形与 region 防御 modifier。

### 5.4 经济、工业和社会层

短期显示映射：

```text
manpower -> 兵源 / 可动员人口
industry -> 国库 / 工业产能
supplies -> 补给 / 弹药粮秣
```

中期资源：

- `treasury` 国库。
- `industrialCap` 工业产能。
- `coal` 煤。
- `iron` 铁。
- `arms` 军械。
- `ammunition` 弹药。
- `food` 粮食。
- `convoys` 船运量。
- `railCapacity` 铁路运输力。
- `adminCapacity` 行政力。
- `prestige` 威望。
- `warSupport` 战争支持。
- `infamy` 国际恶名。

Region 经济标签：

- population、industryLevel、railLevel、portLevel。
- coalOutput、ironOutput、grainOutput。
- unrest、nationalityTags。

首发闭环：

- 每回合按真实控制的 region 聚合国库、兵源、补给。
- 远征军、炮兵、近卫和海上补给消耗更高。
- 铁路/港口影响补给和部署，不直接改变 hex 占领权。
- 玩家可下达动员、修铁路、整备远征军、补充弹药、修筑要塞等命令，最终仍走统一命令系统。

### 5.5 外交和危机层

外交是维多利亚主玩法，不只是状态面板。首版可做轻量 DiplomaticPlay：

```text
DiplomaticPlay
  -> issuerPowerId
  -> targetPowerId
  -> regionId / strategicRegionId
  -> warGoal
  -> escalation
  -> backers
  -> opposingBackers
  -> deadlineTurn
  -> outcome
```

基础关系：

- allied、coBelligerent、neutral、inSphere、protectorate、guaranteed。
- hostile、atWar、truce、militaryAccess、blockaded。

外交行动：

- 发出照会、要求撤军、支持一方、提供贷款/补给。
- 要求通行权、宣布封锁、调停停战、扩大战争目标。

所有外交行动必须通过 directive / command / validator 进入状态，不能让 UI 或 Agent 直接改外交关系。

### 5.6 AI Agent 层

推荐层级：

```text
HeadOfStateAgent / PrimeMinisterAgent / CabinetAgent
  -> ForeignMinisterAgent / WarMinisterAgent / TreasuryAgent / AdmiraltyAgent
  -> GeneralStaffAgent
  -> TheaterDirectiveEnvelope
  -> TheaterDirectiveCompiler
  -> ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
```

角色方向：

- HeadOfStateAgent：国家姿态、战争承受度、威望底线。
- CabinetAgent：平衡财政、舆论、外交、战争目标。
- ForeignMinisterAgent：照会、结盟、调停、通行权、外交危机。
- WarMinisterAgent：兵源、动员、远征军、要塞、补给优先级。
- AdmiraltyAgent：封锁、护航、远征补给、港口优先级。
- TreasuryAgent：预算、贷款、军费、铁路投资。
- IndustrialistAgent：铁路、煤铁、军工和市场建设压力。
- GovernorAgent：殖民辖区治安、补给和地方招募。
- GeneralStaffAgent / TheaterCommanderAgent：把国家目标降级为 theater / zone 指令。
- PressAgent：舆论压力、战争支持变化建议或事件。

所有上游 Agent 输出必须是 Codable JSON directive，不能直接执行状态修改。

### 5.7 UI 风格合同

第一屏布局建议：

```text
Top HUD:
  日期/回合、当前国家、国库、兵源、补给、威望、战争支持、危机状态

Main Map:
  hex 地图、region overlay、铁路、港口、要塞、前线、远征补给线、外交热点

Left Rail:
  内阁、外交、经济、军队、海军/港口、报纸

Right Inspector:
  选中 hex / region / unit / general / diplomatic play 详情

Bottom Strip:
  电报、战报、AI 决策摘要、拒绝原因
```

视觉要求：

- 地图可有纸张/雕版质感，但不能一屏单调米色。
- 使用国家旗色和图案区分势力；无颜色区分时用纹理、描边或图标补充。
- 铁路、电报线、港口、煤站、要塞必须有清晰符号。
- 报纸/电报用于战报和 AI 理由，不堆长篇说明。
- 默认 UI 中文优先。
- 玩家可见层不再显示 Ardennes、Germany、Allies、Panzer、Bastogne、German AI、Allied Player。

## 6. v5.0-v5.9 路线大纲

| 版本 | 主题 | 关键交付 | 非目标 / 风险 |
|---|---|---|---|
| v5.0 | 迁移审计、产品合同和维多利亚术语层 | 已形成 `md/prompt/v5.0-维多利亚迁移/v5.0_audit_and_contract.md`：二战硬编码审计、术语表、首发剧本、版本边界、并发方案 | 不做大范围重命名，不实现完整维多利亚玩法 |
| v5.1 | 多国家、通用回合、外交关系和敌我判断 | 已形成 `md/prompt/v5.0-维多利亚迁移/v5.1_powers_turns_diplomacy_prompt.md`；多国家 `Faction`、通用 action phase、turn order、人控势力集合、集中外交可攻击/可通行判断、neutral fallback 已通过 commit `2919c49` 云端验收 | 后续仍要清理测试、UI、胜利条件和 legacy 数据残留 |
| v5.2 | 黑海危机地图、剧本数据和地图编辑器迁移 | 已开始接入 `black_sea_crisis_1853` 默认入口、维多利亚 regions、powers、unit templates、personas、terrain rules，并保留 legacy 阿登加载入口 | 铁路/港口/煤站/电报暂以 notes、道路、城市/要塞、infrastructure 表达；正式规则留 v5.3-v5.4 |
| v5.3 | 维多利亚军队、铁路补给、港口远征和围城规则 | 步兵/近卫/骑兵/炮兵/工兵/补给纵队、铁路/港口/要塞规则 | 不追求复杂军事仿真 |
| v5.4 | 工业经济、预算、动员和建设命令 | 国库、工业、补给、铁路运输力、船运量、威望、战争支持，建设/动员命令 | 不做完整全球市场 |
| v5.5 | 外交危机、战争目标、列强干预和舆论压力 | DiplomaticPlay、warGoal、backers、escalation、战争支持和谈判 | 外交不直接占领 hex |
| v5.6 | 维多利亚 Agent 指挥链和结构化 JSON 合同 | HeadOfState / Cabinet / Foreign / War / Treasury / Admiralty / GeneralStaff / Theater Agent | 真实 LLM 单独版本，不硬编码密钥 |
| v5.7 | 发布级 UI、地图视觉、报纸战报和可访问性 | 维多利亚视觉系统、地图优先布局、内阁/外交/经济/军队/报纸信息架构 | 视觉验证需人工或授权运行 |
| v5.8 | 内容扩展、事件、历史人物和多剧本框架 | 事件系统、多剧本选择、历史人物与报纸事件 | 事件不得绕过规则 |
| v5.9 | 发布候选、残留清理、试玩闭环和文档收口 | 默认维多利亚剧本、二战残留清理、README/flow/update_log 收口 | 未授权前不得声称发布验证完成 |

当前 v5.0 / v5.1 审计结论：

- `Faction.germany/allies`、`Faction.opponent`、`GamePhase.germanAI/alliedPlayer`、`CommandValidator.phaseAllowsCommands` 和 `CommandExecutor.executeEndTurn` 的主路径已在本地 v5.1 切片中开始迁移；后续仍要清理测试、UI、胜利条件和 legacy 数据残留。
- `DataLoader` 默认资源已开始切到黑海危机；`DiplomacyState` 对 `black_sea_crisis_1853` 有场景化初始关系，英法奥斯曼撒丁对俄开战，奥地利保持武装中立压力；Guderian 专项校验只限 legacy 阿登数据，旧 `playerFaction` / `aiFaction` 字段仍保留作 schema 兼容。
- `ComponentType.tank/motorizedInfantry`、`ProductionKind.panzerDivision`、`EconomyResources.manpower/industry/supplies` 和默认 `unit_templates.json` 是 v5.3-v5.4 必修点。
- `DiplomacyState` 已有 `CountryProfile` 基础，并开始支持 Black Sea Crisis 多国家默认关系；后续仍需把外交危机、战争目标、后援方、升级和谈判迁入规则状态。
- `VictoryRules` 仍绑定 Bastogne / St. Vith / German armor，后续要改成数据驱动战争目标。

## 7. 多 Agent 分工大纲

每轮最多并发 3-5 个子 Agent，主 Agent 必须先定义公共接口合同和文件边界。

| 子 Agent | 范围 | 职责 |
|---|---|---|
| Audit / Docs / QA | README、update_log、md/flow、md/test、v5 prompt | 扫描硬编码、维护词汇表、风险清单、文档同步 |
| Data / Scenario | Data JSON、ScenarioDefinition、RegionDataSet、DataLoader | 黑海危机剧本、维多利亚地形/兵种/人物/国家数据 |
| Core / Rules | Core、Commands、Rules | 多国家敌我、铁路补给、港口远征、围城、要塞、炮兵规则 |
| Economy / Society | EconomyState、EconomyRules、Command、Validator、Executor | 国库、工业、兵源、补给、铁路、远征维护、预算命令 |
| Diplomacy / Politics | DiplomacyState、RulerAgent、外交 directive | 外交危机、战争目标、列强干预、威望、恶名、战争支持 |
| AI | Agents、Turn | 君主、内阁、外交大臣、战争大臣、财政大臣、海军部、总参谋部、战区司令、报界 Agent |
| UI / SpriteKit / Art | UI、SpriteKit、Assets | 维多利亚地图、铁路、港口、报纸、外交照会、内阁、军令电报 |
| MapEditor | MapEditor | 省份/州、军区/远征区、铁路、电报线、港口、煤站、要塞编辑 |
| Project / Integration | project.pbxproj、资源引用、整合记录 | 资源 target membership、UUID、文件/API/schema/project/doc 冲突检查 |

整合前必须检查：

- 多 Agent 是否改同一文件。
- public API、JSON schema、project 文件是否分叉。
- 是否出现 `Faction`、`PowerId`、`CountryId`、`BlocId`、`DiplomaticBlocId` 多套概念混乱。
- 是否有人绕过 `RuleEngine`。
- 是否把 `regionToTheater`、`hexToTheater`、`hexToFrontZone` 的权威边界写乱。
- 是否把外交、经济、海军、殖民事件直接写成无校验状态变更。

## 8. 数据 schema 大纲

维多利亚迁移可沿用旧结构，但必须在阶段记录中标明兼容旧名与维多利亚字段。

建议 schema：

- Power / Country：`power_britain`、政府、首都、大国排名、威望、国库、执政派系、文化、AI profile、旗色。
- 人物 / Agent：`person_palmerston`、rank/office、power、外交/财政/统率/声望/谨慎倾向、派系、biography。
- 维多利亚单位模板：lineInfantry、guardInfantry、cavalry、artillery、engineers、irregulars、colonialInfantry、supplyTrain。
- Region / Objective：港口、铁路节点、煤站、要塞、工业区、城市、海岸、战略通道；owner/controller 支持多国和 neutral。
- DiplomaticPlay：issuerPowerId、targetPowerId、regionId、warGoal、escalation、backers、opposingBackers、deadlineTurn、outcome。
- CabinetDirective / TheaterDirective：schemaVersion、issuerId、turn、powerId、strategicIntent、domain、priority、action、targetPowerId、regionId、theaterId、budgetLimit、rationale。

命名规则：

- id 使用 ASCII，例如 `power_britain`、`region_sevastopol`、`theater_crimea_expedition`、`person_palmerston`。
- 中文只放 `displayName`、`localizedName`、`briefing`、`biography`、`description`、`notes` 等展示字段。
- 不把受版权保护的游戏素材、影视剧照、商业人物头像或未经授权地图写入默认资源。

## 9. 发布候选验收大纲

发布候选前必须确认：

- 默认启动进入黑海危机或明确的维多利亚剧本。
- 玩家可选择或默认扮演一个势力。
- 可查看省份、港口、铁路、要塞、军队、外交危机。
- 可移动、攻击、围城/占领、补给、结束回合。
- AI 至少能完成外交/军事/经济中的两类决策，并留下结构化记录。
- 外交危机或战争目标影响胜负。
- 战报、报纸、电报或 AI 面板能解释关键决策。
- 主 UI 无主要二战残留。
- 玩家和 AI 都经 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 或明确的新 validator/executor。
- `HexTile.controller` 和 `Division.coord` 仍是战术权威。
- `regionToTheater` 仍是初始/基础映射，不表示运行时推进。
- `hexToTheater` 和 `hexToFrontZone` 仍是动态权威。
- 新 JSON 都通过 `jq empty`。
- project 文件如改动通过 `plutil -lint`。
- README、`md/flow/flow.md`、`md/flow/flowchart.md`、`update_log.md` 和阶段记录口径一致。
- 未跑重测试的范围和风险写清楚。

发布前需要人工授权：

- Xcode build。
- iOS Simulator 或真机启动。
- macOS target 启动。
- 10-20 回合观察者模式。
- 基础 UI 点击烟测。
- SpriteKit 截图或人工视觉检查。
- 性能体感检查。

未获授权前，不得声称“已发布”或“可发布已验证”。只能写“发布候选代码和文档已准备，运行时验证未授权，风险未验证”。

## 10. 关键风险清单

- 当前历史分支多、工作树曾多次漂移；迁移前必须确认分支、基点、dirty 文件和冲突。
- `Faction` 二元模型是最大风险点，强改会影响 AI、补给、前线、部署、UI 和数据加载。
- 新增代码若重新调用 `Faction.opponent`，会破坏多方、中立和外交危机。
- `GamePhase.germanAI/alliedPlayer` 残留会让新势力控制权表现错误。
- `RegionDataSet.toRegions()` 的 nil fallback 已改为 `.neutral`，后续仍需持续防止 neutral / nil 回落到 legacy 双方。
- `DataLoader` fallback components 和部分 legacy validation 仍保留阿登/Guderian 兼容路径，新场景不得重新依赖它们。
- `project.pbxproj` 只能由一个 Agent 处理。
- UI/SpriteKit 改动需要视觉验证，但当前规范禁止主动启动 app。
- 外交、经济、事件、海权如果直接改状态，会绕过命令权威。
- 真实 LLM 接入、模型输出质量和长回合稳定性必须单独版本验证。
- 维多利亚题材容易膨胀到全球市场和完整政治模拟，首版必须控制在黑海危机闭环。

## 11. 后续执行口径

后续 Agent B 执行维多利亚迁移时的优先级：

1. 保住规则权威：hex 是战术权威，命令必须走规则系统。
2. 先拆二战硬编码，再做维多利亚内容。
3. 先做多国家、外交关系和敌我判断，再做复杂 AI。
4. 先做一个精制可玩的黑海危机剧本，不做全球无限沙盒。
5. 先做工业/财政/铁路/港口/外交危机/围城的最小闭环，不做完整全球市场。
6. 每轮只改当前版本范围，不顺手重构无关文件。
7. 多 Agent 并发时，先约定接口，再分文件实现，最后必须做冲突审查。
8. 轻量检查必须写具体命令和结果；重测试未授权必须明确说明未跑。

下一轮推荐入口：

- 先完成本地 v5.1 切片的 commit / push / GitHub Actions / Agent C artifact 验收。
- 验收通过后进入 v5.2 黑海危机地图默认化；验收前不要把 `black_sea_crisis_1853` 切为默认剧本。
- v5.2 若要新增 Swift 文件或资源，必须由唯一 Project / Integration Agent 处理 `project.pbxproj`。
