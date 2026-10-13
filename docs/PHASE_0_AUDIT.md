# 阶段 0 审计报告

审计日期：2026-10-13。  
审计对象：`F:\xufeng\games` 的工作区，不是开发计划里的预期状态。  
审计范围：阶段 0（项目初始化与技术验证）。本次没有进入阶段 1，也没有修改游戏脚本、场景或配置来让验收通过。

状态用词：

| 状态 | 含义 |
| --- | --- |
| 已验证 | 本次审计有命令输出、退出码或截图 |
| 已实现，未验证 | 有代码，本次没有运行到那条路径 |
| 仅有文档 | 文档写了目标或约定，没有对应实现 |
| 未完成 | 没有实现 |
| 存在问题 | 已发现错误、缺陷或会带来返工的风险 |

`docs/DEVELOPMENT_PLAN.md` 里已有一份同日运行记录。本报告不引用那份记录作为证据。下面的命令都是本次重新执行的。

## 1. 审计结论

**可以进入阶段 1。**

阶段 0 要求的工具链、最小场景、网格、临时领主移动、按配置放置建筑、非法放置和无效配置拒绝，都有本次运行证据。设计文档把第一版目标和当前实现分开写了，没有把战斗、经济、探索、肉鸽、存档或模组扫描写成已经可用。

没有发现 P0 或 P1。进入阶段 1 之前没有必须先改的代码缺陷。第 8 节里的事项是阶段 1 开工时要守住的边界，不是阶段 0 的补做清单。

## 2. 项目环境与入口

| 项 | 实际结果 |
| --- | --- |
| 项目根目录 | `F:\xufeng\games`。仓库目录名是 `games`，没有再套一层 `frontier-wardens/`。`docs/ARCHITECTURE.md` 写明这是有意的 |
| 项目名称 | `project.godot` 中 `config/name="Frontier Wardens"`，`config/description="边境守望"`，`config/version="0.1.0"` |
| 引擎 | Godot 4.7.2.stable.official.ed1daf0bf。可执行文件位于本机 `%LOCALAPPDATA%\Godot\4.7.2-stable\`，不在仓库内 |
| 是否为稳定版 | 是。版本字符串含 `stable.official`。项目特性为 `PackedStringArray("4.7", "GL Compatibility")`，与 4.7.2 的主版本一致 |
| 脚本语言 | GDScript。仓库没有 `.cs`、`.csproj` 或 `.sln`。使用的可执行文件名不含 `mono` / .NET |
| 渲染 | `renderer/rendering_method="gl_compatibility"`。窗口运行日志为 `OpenGL API 3.3.0 ... Compatibility`，设备为 NVIDIA GeForce GTX 1060 3GB |
| Git | 已初始化。当前分支 `main`。HEAD 为 `e2e1eb5`，说明 `first commit`，作者名 xufeng，时间 2026-10-13 16:57:48 +0800。提交说明不摘录作者邮箱 |
| 远程 | 已配置 `origin`，指向 GitHub 仓库 `xfastres/games`。`main` 没有上游跟踪分支 |
| 工作区 | 不干净。详见第 7 节。游戏脚本和 `project.godot` 相对 HEAD 没有未提交修改 |
| 编辑器能否识别 | 能。存在 `project.godot`（`config_version=5`）、`.godot/editor/project_metadata.cfg`（记录了上述 Godot 可执行文件，最近场景为 `res://scenes/main/tech_demo.tscn`）、`icon.svg.import` 和已生成的图标缓存。本次命令行成功加载该项目 |
| 启动入口 | `run/main_scene="res://scenes/main/tech_demo.tscn"` |
| 主场景 | `scenes/main/tech_demo.tscn`，根节点 `TechDemo`（`Node2D`），脚本 `scripts/world/tech_demo.gd` |
| 运行方式 | 用 Godot 打开本目录的 `project.godot`，或执行 `Godot_v4.7.2-stable_win64_console.exe --path F:\xufeng\games` |
| 依赖与插件 | `project.godot` 没有自动加载，也没有插件段。仓库没有 `addons/`。没有第三方测试框架 |
| 导入资源 | 唯一导入资源是 `icon.svg`。对应 `.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex` 存在。本次运行的标准错误为空，没有导入失败信息 |
| 敏感配置 | 源码、JSON、Markdown 和 `project.godot` 中未发现密钥、口令或访问令牌。Git 提交元数据含作者邮箱，本报告不摘录 |

本次没有交互式点击 Godot 编辑器界面。编辑器识别的证据是既有 `.godot` 元数据，加上同一可执行文件能够加载并运行项目。

窗口与视口：1280×720。截图实测也是 1280×720。

## 3. 文件与目录清单

下面是审计时工作区里实际存在的内容。`.git/` 是仓库元数据。`.godot/` 是本地编辑器缓存，已被 `.gitignore` 忽略。计划中的 `scripts/combat`、`scripts/economy`、`scripts/exploration`、`scripts/roguelike`、`scripts/save`、`scripts/mods` 等目录不存在，与 `docs/ARCHITECTURE.md` 的写法一致。

```
F:\xufeng\games
├── project.godot
├── icon.svg
├── icon.svg.import
├── .gitignore
├── AGENTS.md
├── README.md
├── CHANGELOG.md
├── data/buildings/test_watchpost.json
├── docs/GDD.md
├── docs/ARCHITECTURE.md
├── docs/DATA_SCHEMA.md
├── docs/MODDING.md
├── docs/DEVELOPMENT_PLAN.md
├── scenes/main/tech_demo.tscn
├── scenes/lord/temp_lord.tscn
├── scenes/buildings/placeholder_building.tscn
├── scripts/content/building_definition.gd
├── scripts/content/content_loader.gd
├── scripts/content/resource_path.gd
├── scripts/core/ui_font.gd
├── scripts/world/tech_demo.gd
├── scripts/world/placement_grid.gd
├── scripts/lord/temp_lord.gd
├── scripts/buildings/placeholder_building.gd
├── tests/unit/stage0_checks.gd
├── tests/fixtures/invalid_building_missing_id.json
├── tests/fixtures/invalid_building_bad_version.json
├── tests/fixtures/invalid_building_bad_footprint.json
├── tests/fixtures/invalid_building_unknown_field.json
├── tests/fixtures/invalid_building_missing_scene.json
├── tests/fixtures/invalid_not_json.json
├── mods/README.md
├── tools/content_validator/README.md
└── .godot/          （本地缓存，含编辑器元数据、脚本类缓存、图标导入结果）
```

每个 `.gd` 旁都有 Godot 生成的 `.uid` 文件，已纳入 Git。`tests/artifacts/` 在 `.gitignore` 中，当前不存在。

| 路径 | 实际作用 |
| --- | --- |
| `project.godot` | Godot 4 工程：名称、主场景、GL Compatibility、窗口尺寸 |
| `scenes/main/tech_demo.tscn` | 当前唯一可运行场景 |
| `scripts/world/tech_demo.gd` | 把配置加载、网格绘制、放置、临时领主和提示文字接在一起 |
| `scripts/world/placement_grid.gd` | 按占地检查边界和占用，占用表记录的是建筑 id |
| `scripts/lord/temp_lord.gd` | 临时领主的移动和地图边界 |
| `scenes/lord/temp_lord.tscn` | 蓝色菱形 `CharacterBody2D` |
| `scripts/buildings/placeholder_building.gd` | 按传入的尺寸、id 和名称画占位矩形 |
| `scenes/buildings/placeholder_building.tscn` | 占位建筑场景，供配置文件引用 |
| `scripts/content/content_loader.gd` | 读取一份明确传入的建筑 JSON |
| `scripts/content/building_definition.gd` | 校验并生成 `BuildingDefinition` |
| `scripts/content/resource_path.gd` | 限制资源路径必须是项目内真实文件 |
| `scripts/core/ui_font.gd` | 使用 Windows 系统字体显示中文 |
| `data/buildings/test_watchpost.json` | 唯一一份正式建筑配置 |
| `tests/unit/stage0_checks.gd` | 无头断言：路径、配置、放置、场景和移动 |
| `tests/fixtures/` | 六份故意写坏的配置 |
| `mods/README.md` | 说明阶段 0 不扫描此目录。没有 `mod.json` 或内容包 |
| `tools/content_validator/README.md` | 说明阶段 0 没有独立命令行校验器 |
| `docs/GDD.md` | 第一版目标。开篇写明这些是目标，不是已完成功能 |
| `docs/ARCHITECTURE.md` | 目录职责和阶段 0 实际做到哪一层 |
| `docs/DATA_SCHEMA.md` | 建筑 JSON 的已实现字段，以及以后才会出现的对象 |
| `docs/MODDING.md` | 本地内容包、完整内容包、玩家工坊的分阶段边界 |
| `docs/DEVELOPMENT_PLAN.md` | 阶段 0 到阶段 6 的范围。阶段 5 才做内容注册和本地模组扫描 |
| `AGENTS.md` | 给后续开发用的约束，不是运行时系统 |
| `README.md` | 如何打开项目，以及阶段 0 的检查命令 |
| `CHANGELOG.md` | 0.1.0 记录了阶段 0 的文档和验证场景 |

## 4. 阶段 0 验收表

| 验收项 | 当前状态 | 证据 | 发现的问题 | 是否阻塞阶段 1 |
| --- | --- | --- | --- | --- |
| Godot 能识别并打开项目 | 已验证 | 编辑器元数据指向 `Godot_v4.7.2-stable_win64.exe`，最近场景是技术验证场景。本次 `--path F:\xufeng\games` 的无头和窗口命令都打印了引擎横幅并退出码 0。`project.godot` 运行前后 SHA256 同为 `7CBEB51658C4ABB876808B0FC97BCC49E88F716E01FA1FEBDD4E5CD288B17CB4`，没有被引擎改写 | 本次没有点击编辑器图形界面。没有单独执行 `--import` | 否 |
| 存在可运行的最小场景 | 已验证 | 主场景 `scenes/main/tech_demo.tscn`。无头 `--quit-after 3`、无头 `--quit-after 90`、窗口 `--shot` 都打印了「已加载建筑：测试哨所 (base.test_watchpost)」，退出码 0 | 无 | 否 |
| 显示基础网格地图 | 已验证 | `scripts/world/tech_demo.gd` 的 `_draw()` 画 12×8、每格 64 像素的矩形和网格线。窗口截图 `user://stage0_preview.png`（1280×720，42833 字节，2026-10-13 17:21:45）能看到绿色网格 | 这是 `Node2D._draw`，不是 `TileMapLayer`。架构文档已写明地形图集留到以后 | 否 |
| 领主能在地图上移动 | 已验证（程序驱动） | `tests/unit/stage0_checks.gd` 把 `scripted_direction` 设为向右，断言 15 个物理帧后 x 增加超过 10 像素，再向左推时不越过地图边界。整套测试输出 `STAGE0_PASS`，退出码 0。截图里能看到蓝色菱形领主站在网格上 | WASD / 方向键那条 `Input.get_vector` 路径没有用真实按键跑过。见 P3 | 否 |
| 能放置测试建筑 | 已验证（程序调用） | 测试调用 `place_at_world_position`：合法位置成功，同一格返回「已被占用」，网格外返回「不在地图网格内」，组 `placed_building` 里只有 1 个实例，实例 meta 的 id 为 `base.test_watchpost`。`--shot` 在格子 (3, 3) 放下建筑。截图 HUD 为「已放置：测试哨所 于格子 (3, 3)」，格子上有标着「测试哨所」的棕色方块 | 左键单击走的是 `_unhandled_input`。本次没有向窗口发送真实鼠标点击 | 否 |
| 从配置读取建筑并使用其属性 | 已验证 | `data/buildings/test_watchpost.json` 的 id、名称、场景、1×1 占地被加载。HUD 显示「测试哨所」和 `base.test_watchpost`。场景来自配置里的 `scene`。占地参与放置尺寸和占用格计算。非法样本被拒绝后，合法配置仍然完成放置 | `description` 被解析进 `BuildingDefinition`，画面没有显示这段说明。配置里没有 `icon` | 否 |
| 占用格和网格外有明确错误 | 已验证 | 测试标准输出包含「无法放置：格子 (2, 1) 已被占用」和「无法放置：坐标不在地图网格内」。`STAGE0_PASS` 还覆盖了 2×2 占地越界、失败时不占用格子、0 尺寸地图 | 这些断言由测试直接调用放置函数，不是玩家点击 | 否 |
| 无效配置被拒绝，合法配置仍能加载 | 已验证 | 场景启动打印「无效配置已拒绝：缺少字段：id」，随后仍放置了合法建筑。`stage0_checks.gd` 对六份夹具和若干内联 JSON 做了断言；失败会打印 `STAGE0_FAIL` 并以退出码 1 结束。本次是 `STAGE0_PASS`、退出码 0。成功时夹具错误原文不会逐条打印 | 无 | 否 |
| 全部 GDScript 可被引擎解析 | 已验证 | 9 个 `.gd` 分别执行 `--headless --check-only --script <脚本> --quit`，退出码都是 0，标准错误为空 | `--check-only` 只表示解析通过，不表示玩法跑过 | 否 |
| 第一版目标和范围写清楚 | 仅有文档，且与「阶段 0 未做完第一版」一致 | `docs/GDD.md` 写了 15–25 分钟单局、第一版模块表，以及不做多人、玩家脚本和在线工坊。同文写明阶段 0 不要求满足第一版 8 条验收 | 这些模块除技术验证场景外都还没有代码。这是范围说明，不是完成声明 | 否 |
| 核心系统、内容数据和扩展内容分开 | 已实现，部分仅有文档 | 已有代码分成 `scripts/content`、`scripts/world`、`scripts/buildings`、`scripts/lord`。战斗、经济、探索、肉鸽、存档、模组扫描没有目录，架构文档把它们标为未实现 | 技术验证场景同时负责加载、绘制、放置和界面。以阶段 0 的体量可以接受 | 否 |
| 文档没有把未实现能力写成已经支持 | 已核对，一致 | `README.md` 写明战斗、经济、探索、肉鸽、存档、主菜单和模组扫描还没做，`mods/` 不会被加载。`ContentLoader` 的注释和实现都是读取一个传入路径。`mods/` 与 `tools/content_validator/` 只有 README | `docs/DEVELOPMENT_PLAN.md` 的已提交版本和工作区版本不一致，见 P3。这不改变功能是否存在 | 否 |

## 5. 可扩展性审查

阶段 0 不要求玩家工坊。这里只判断以后加内容时有没有一条说得通的路，以及这条路有没有被写成已经完工。

### 领主

当前只有硬编码的临时领主：`tech_demo.gd` 固定加载 `res://scenes/lord/temp_lord.tscn`。没有领主 JSON，也没有领主定义类型。`docs/DATA_SCHEMA.md` 和 `docs/GDD.md` 把领主数据、边境骑士、以及「新增领主不改核心逻辑」写成后续目标。

扩展路径：以后增加领主定义，字段至少包含场景、生命、移动和攻击；玩法代码只读定义，不写领主名字分支。这条路径现在只存在于文档。阶段 1 如果只做敌人攻城，可以暂时继续使用这个临时角色，但不要在战斗脚本里写死「边境骑士」。

### 建筑

这是目前唯一有数据加载实现的内容类型。

- `BuildingDefinition` 校验 id、`schema_version`、名称、场景、可选说明、可选图标和占地。未知字段直接失败。
- `PlacementGrid.try_place()` 只使用占地和 id。测试用 id `sample.other`、占地 2×2 放置成功，说明放置逻辑没有判断是不是「测试哨所」。
- 占位场景提供 `setup(world_position, size_px, building_id, display_name)`，用数据画矩形和名称。
- 加载器不会扫描 `data/buildings/`。技术验证场景写死了 `res://data/buildings/test_watchpost.json`。再放一个 JSON 文件不会自动出现在游戏里，调用方必须把路径传进去。

因此：普通建筑的校验和放置已经不依赖建筑名字；「只加一个 JSON 就进入游戏」还没有目录注册。`docs/DEVELOPMENT_PLAN.md` 把注册表放在阶段 5。阶段 1 的城墙和弓箭塔应继续走 `BuildingDefinition` 和场景 `setup()`，不要在核心逻辑里写 `if id == "某种建筑"`。

### 敌人、肉鸽强化、遗物

未完成。没有解析器、注册表或示例配置。`docs/DATA_SCHEMA.md` 只列出以后要有的方向：敌人的移动和攻击目标、强化的效果组件 id 和数值、遗物与其他对象一样要有唯一 id 和 `schema_version`。文档写明阶段 0 的加载器不会注册这些对象。

风险在阶段 1 到阶段 4：如果敌人、波次和强化先写进脚本常量，阶段 5 再抽成数据时会返工。这是开工约束，不是阶段 0 的实现缺口。

### 资源、地图区域、波次

未完成，也没有假的空系统。地图目前是技术验证场景里的常量：12 列、8 行、格子 64 像素、原点 `(64, 128)`。没有资源库存、区域或波次文件。

### 本地内容包

仅有文档和空目录说明。`mods/README.md` 与 `docs/MODDING.md` 都写明阶段 0 不扫描 `mods/`。加载器只接受调用方传入的 `res://` 路径。内置 `data/` 和外部内容包以后共用校验后的定义对象；现在只有内置建筑这一条路径。

### 玩家工坊

仅有文档。`docs/MODDING.md` 把工坊标为更后面的阶段 C：导入导出、依赖、预览、发布和订阅都还没有选型，也没有代码。第一版明确不执行玩家脚本。

### 版本、依赖和 ID 校验

已实现的部分：

- 单个建筑文件的 `schema_version` 只能是整数 1。`true`、非整数和 2 会失败。测试覆盖了布尔版本和夹具里的版本 2。
- id 必须是至少两段的小写标识，例如 `base.test_watchpost`。
- 未知字段、缺失字段、损坏 JSON、不存在的场景都会返回错误文本，并且 `definition` 为 null。
- 资源路径必须是 `res://` 下的真实文件，拒绝绝对路径、`user://`、空目录段和 `..`。测试覆盖了这些路径。

尚未实现，且文档没有假装已经实现：

- 跨文件 id 查重。
- 内容包 `game_api_version`、依赖和 `mod.json`。
- 某个内容包失败时仍进入主菜单。阶段 0 没有主菜单；技术验证场景在非法样本被拒绝时继续运行，这一点已被启动日志证实。
- 存档记录内容包版本。没有存档系统。

没有为了这些未来规则提前做一套框架。`tools/content_validator/` 故意只有说明，避免出现第二套会和 GDScript 漂移的校验器。这个判断和当前代码一致。

数据加载失败时的诊断是可核对的：错误字符串进入返回值和画面，不返回定义对象。场景在「无效样本竟然通过」时会 `push_error`。没有空的错误吞掉。

## 6. 已发现的问题

### P0

无。项目能被 Godot 4.7.2 启动，主场景能加载合法建筑并拒绝无效样本。

### P1

无。没有发现会让阶段 0 验收失效，或现在就必须推倒重来的结构。

### P2

无。下面的事项不需要在进入阶段 1 之前先改代码。

### P3

1. **键盘和鼠标事件没有用操作系统输入验证。** 移动和放置的自动化测试调用的是 `scripted_direction` 和 `place_at_world_position()`。按键绑定在 `temp_lord.gd` 的 `_ensure_move_actions()`，左键在 `tech_demo.gd` 的 `_unhandled_input()`。代码存在，本次没有向运行中的窗口发送真实按键或点击。截图只能证明领主和建筑被画出来，不能证明玩家按过 WASD。
2. **`description` 没有显示。** 字段被保存，HUD 和占位建筑只用了名称、id、场景和占地。不影响「至少一个属性被正确使用」。
3. **输入动作没有写进 `project.godot`。** 动作在领主 `_ready()` 里创建。编辑器的输入映射界面在运行前看不到这些动作。
4. **资源路径只允许 ASCII 文件名。** `ResourcePath._is_safe_segment()` 只接受字母、数字、`-`、`.`、`_`。当前文件都符合。以后如果内容包使用中文文件名，会被拒绝。id 规则本身要求小写 ASCII，这是文档已经写明的。
5. **建筑注册还不是目录扫描。** 这是阶段 0 的既定范围，架构文档写了。阶段 1 增加城墙和塔时，应加 JSON 并让调用方加载这些定义，不要把建筑名字写进战斗分支。
6. **已提交的开发计划和工作区不一致。** HEAD 中的 `docs/DEVELOPMENT_PLAN.md` 仍写着「不是 Git 仓库。本阶段没有创建仓库，也没有提交。」工作区已改成记录 `first commit`（xufeng，2026-10-13 16:57）。`git log` 与工作区这句话一致，与 HEAD 里的旧句子不一致。功能不受影响，但这份未提交修改还在工作区里。
7. **审计开始时根目录有一个未跟踪文件 `Untitled`，内容是一行本地 Godot 启动命令。** 审计结束、写入本报告之前，该文件已经不在磁盘上。本次审计的命令没有删除它。结束时 `git status` 只剩 `docs/DEVELOPMENT_PLAN.md` 的修改；写入本报告后会再增加本文件。

场景引用是有效的：三个 `.tscn` 的脚本路径都能对上现存 `.gd`，运行时没有缺脚本错误。没有空脚本，也没有用空函数冒充战斗或经济。占位建筑会实际画出矩形和名称。没有第二套建筑校验。核心放置代码没有按建筑名字分支。校验失败会返回原因。抽象规模停在「一份 JSON、一个定义对象、一张占用网格」，没有提前建完整个游戏框架。

## 7. 测试与运行记录

环境：Windows 10.0.19045，PowerShell，工作目录 `F:\xufeng\games`。  
命令使用的可执行文件：`%LOCALAPPDATA%\Godot\4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`。  
这是同目录下编辑器可执行文件的控制台启动器。编辑器元数据指向旁边的 `Godot_v4.7.2-stable_win64.exe`。两者都报告同一版本字符串。  
日志副本在本机临时目录 `frontier_wardens_phase0_audit`，没有写入仓库。

| 命令 | 结果 |
| --- | --- |
| `--version` | 标准输出 `4.7.2.stable.official.ed1daf0bf`，退出码 0 |
| 对 9 个 `.gd` 分别执行 `--headless --path . --check-only --script <脚本> --quit` | 每个退出码 0。标准输出只有引擎横幅。标准错误为空。脚本为 `resource_path.gd`、`building_definition.gd`、`content_loader.gd`、`ui_font.gd`、`placement_grid.gd`、`tech_demo.gd`、`temp_lord.gd`、`placeholder_building.gd`、`stage0_checks.gd` |
| `--headless --path . --script res://tests/unit/stage0_checks.gd` | 退出码 0。输出含「已加载建筑：测试哨所 (base.test_watchpost)」「无效配置已拒绝：缺少字段：id」「无法放置：格子 (2, 1) 已被占用」「无法放置：坐标不在地图网格内」「STAGE0_PASS」 |
| `--headless --path . --quit-after 3` | 退出码 0。打印合法建筑已加载、无效配置已拒绝。帮助文本写明 `--quit-after` 是迭代次数，不是秒 |
| `--headless --path . --quit-after 90` | 退出码 0，耗时约 1 秒。同样打印上述两行加载信息。这是 README 里的次数；开发计划正文写的是曾经跑过 `--quit-after 30`，那次不是本次证据 |
| `--path . -- --shot` | 退出码 0。渲染日志为 OpenGL 3.3 Compatibility，设备 NVIDIA GeForce GTX 1060 3GB。打印 `STAGE0_SHOT`，文件为 `%APPDATA%\Godot\app_userdata\Frontier Wardens\stage0_preview.png`。实测 1280×720，42833 字节。画面含网格、蓝色领主、棕色「测试哨所」，HUD 含配置名称、id、无效配置拒绝原因和格子 (3, 3) |

本次未能验证的项目：

| 项目 | 原因 |
| --- | --- |
| 在 Godot 编辑器里用鼠标打开并按下运行按钮 | 本次只用命令行。编辑器缓存说明以前被编辑器打开过，但不能代替这次的点击操作 |
| `--import` | 该参数会启动编辑器并等待导入。项目已有导入缓存，游戏运行也没有导入错误。为避免编辑器改写工程文件，没有再跑 |
| 真实 WASD、方向键和鼠标左键 | 自动化测试没有发送操作系统输入事件。见 P3 |
| 第一版的战斗、经济、探索、存档、主菜单 | 阶段 0 明确不做，仓库里也没有这些系统 |
| `mods/` 加载、内容包版本和依赖校验 | 未实现。没有可运行的失败样本之外的模组扫描器 |
| README 里「90」如果被人理解成 90 秒 | 引擎帮助写的是迭代次数。本次 `--quit-after 90` 约 1 秒结束，不能当成在窗口里停留了 90 秒 |

开发计划里的旧记录与本次结论方向一致，但本报告只采用上表。

## 8. 下一步建议

进入阶段 1 之前没有必须先改的功能缺陷。建议直接按 `docs/DEVELOPMENT_PLAN.md` 的阶段 1 做战斗原型，并守住下面三条：

1. 城墙、弓箭塔继续用建筑 JSON 和 `BuildingDefinition`。放置和战斗不要按建筑 id 写分支。需要新行为时再加明确的行为类型，未知类型要报错。
2. 敌人、波次和金币可以先服务这一次可玩的防守，但不要把某个领主或建筑的名字写进伤害、寻路或胜负判断。
3. 提交或搁置工作区里对 `docs/DEVELOPMENT_PLAN.md` 的修改时，保留「仓库已经存在 `first commit`」这句。HEAD 里的「本阶段没有创建仓库」已经和 `git log` 不符。

阶段 1 不要提前做模组扫描、主菜单、存档或完整注册表。那些在开发计划的阶段 5 和阶段 6。

## 附录 A：`project.godot`

```
; Engine configuration file.
; Godot 4.7 may rewrite this file on import. Keep the main scene and renderer.

config_version=5

[application]

config/name="Frontier Wardens"
config/description="边境守望"
config/version="0.1.0"
run/main_scene="res://scenes/main/tech_demo.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
run/flush_stdout_on_print=true
config/icon="res://icon.svg"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0.08, 0.09, 0.11, 1)
```

## 附录 B：阶段 0 实际结构（摘自架构文档，并已对照目录）

`docs/ARCHITECTURE.md` 写明：阶段 0 只实现内容校验、网格放置和临时角色移动。内容定义不引用地图或战斗。放置网格只使用占地和 id。`mods/` 与核心脚本分开。网格用 `_draw` 绘制。测试不引入 GdUnit。这些句子和当前文件一致。

同文档列出的未实现目录（`combat`、`economy`、`construction`、`exploration`、`roguelike`、`progression`、`save`、`mods`）在磁盘上不存在。

## 附录 C：建筑配置与加载约定（摘自数据格式文档，并已对照代码）

`docs/DATA_SCHEMA.md` 写明阶段 0 只实现建筑定义的一个子集。必填字段为 `id`、`schema_version`、`name`、`scene`、`footprint.width`、`footprint.height`。可选字段为 `description` 和 `icon`。`schema_version` 只能是 1。未知字段是错误。正式示例是 `data/buildings/test_watchpost.json`。

示例原文：

```json
{
  "id": "base.test_watchpost",
  "schema_version": 1,
  "name": "测试哨所",
  "description": "阶段 0 用于验证网格放置的占位建筑。",
  "scene": "res://scenes/buildings/placeholder_building.tscn",
  "footprint": {
    "width": 1,
    "height": 1
  }
}
```

`BuildingDefinition` 的 `ROOT_FIELDS`、`REQUIRED_ROOT` 与上表一致。价格、生命、射程和行为类型没有进入当前格式，代码里也没有这些字段。

## 附录 D：建筑加载、放置、领主移动

### 读取一份配置

`scripts/content/content_loader.gd` 先检查路径，再读文本，再交给 `BuildingDefinition.parse_text()`。它不是模组扫描器。

```gdscript
static func load_building(path: String) -> Dictionary:
	var path_error := ResourcePath.validate_project_file(path, "配置文件", ".json")
	if path_error != "":
		return {"ok": false, "error": path_error, "definition": null}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error": "无法读取配置：%s（%s）" % [path, error_string(FileAccess.get_open_error())],
			"definition": null,
		}
	var text := file.get_as_text()
	file.close()
	return BuildingDefinition.parse_text(text)
```

技术验证场景在 `_ready()` 中加载两份文件：合法的 `res://data/buildings/test_watchpost.json`，以及故意缺少 id 的夹具。合法定义失败时场景停止后续生成；非法定义若意外通过，会 `push_error`。

### 按定义放置，不判断建筑名字

`PlacementGrid.try_place()` 用占地收集格子，越界或已占用则整次失败并且不写入占用表。成功时占用表的值是 `definition.id`。

放置入口在 `tech_demo.gd` 的 `place_at_world_position()`：把世界坐标换成格子，`load(definition.scene_path)`，要求节点有 `setup`，再用定义里的占地和名称调用它。网格拒绝时会释放刚创建的节点。

### 占位建筑使用配置里的名称和 id

`placeholder_building.gd` 的 `setup()` 把 id、显示名称写入 meta，按传入像素尺寸画矩形，并把 `display_name` 设为标签文字，然后加入组 `placed_building`。

### 临时领主移动

`temp_lord.gd` 在物理帧里优先使用 `scripted_direction`；该向量为零时才读取 `move_left` / `move_right` / `move_up` / `move_down`。速度为方向乘以 220。`_keep_inside_map()` 把位置夹在 `configure()` 传入的矩形内。技术验证场景把领主放在地图原点偏移 `(1.5, 1.5)` 格的位置，并把边界设为地图矩形向内 18 像素。

自动化测试覆盖的是 `scripted_direction`，不是键盘事件。

## 附录 E：场景脚本引用

| 场景 | 脚本 |
| --- | --- |
| `scenes/main/tech_demo.tscn` | `res://scripts/world/tech_demo.gd` |
| `scenes/lord/temp_lord.tscn` | `res://scripts/lord/temp_lord.gd` |
| `scenes/buildings/placeholder_building.tscn` | `res://scripts/buildings/placeholder_building.gd` |

全局类缓存里的类名与脚本一致：`BuildingDefinition`、`ContentLoader`、`PlacementGrid`、`ResourcePath`、`TempLord`、`UiFont`。
