# 架构

## 工程根目录

游戏工程就是仓库根目录，不另套 `frontier-wardens/`。`AGENTS.md` 已经在根目录，Godot 项目文件也放在这里。

## 职责边界

这些边界是第一版的目标。阶段 0 实现了内容校验、网格放置和临时角色移动。阶段 1 增加了防守战斗、击杀金币和按配置放置城墙、弓箭塔。探索、肉鸽、存档和模组扫描仍然没有代码。

| 模块 | 职责 | 当前 |
| --- | --- | --- |
| `scripts/content` | 读取并校验内容定义。不负责战斗、经济和场景流程 | 建筑、敌人、波次、防守关卡 |
| `scripts/world` | 地图网格、放置规则、技术验证场景编排 | 放置网格、地形图层和验证场景 |
| `scripts/buildings` | 可复用的建筑表现。不知道具体建筑名字 | 占位建筑，以及按行为类型装配的战斗建筑 |
| `scripts/lord` | 领主移动和控制。不引用具体建筑 | 只有技术验证场景里的临时领主 |
| `scripts/combat` | 伤害、投射物、目标选择、寻路、波次和胜负 | 阶段 1 防守原型。全局最短路由 AStarGrid2D 计算 |
| `scripts/economy` | 资源库存、产出、花费、拆除返还 | 只有金币的花费和击杀奖励 |
| `scripts/construction` | 建造、选中、升级、拆除流程 | 未实现。阶段 1 的选中和放置在防守场景里 |
| `scripts/exploration` | 迷雾、区域、营地和遗迹 | 未实现 |
| `scripts/roguelike` | 强化抽取和 3 选 1 | 未实现 |
| `scripts/progression` | 局内升级和局外解锁 | 未实现 |
| `scripts/save` | 存档、版本和缺失内容检测 | 未实现 |
| `scripts/mods` | 本地内容包扫描。不执行外部脚本 | 未实现 |

依赖方向：

- 内容定义不引用地图、战斗或 UI。
- 放置网格只使用建筑定义里的占地和 id，不判断建筑名字。
- 场景脚本负责把定义、网格和表现接起来。
- `mods/` 与核心脚本分开。外部内容以后也不能替换 `scripts/` 或 `project.godot`。

## 阶段 0 的实际结构

```
project.godot
docs/
scenes/main/tech_demo.tscn
scenes/lord/temp_lord.tscn
scenes/buildings/placeholder_building.tscn
scripts/content/
scripts/core/ui_font.gd
scripts/world/
scripts/lord/
scripts/buildings/
data/buildings/test_watchpost.json
tests/unit/stage0_checks.gd
tests/fixtures/
mods/README.md
tools/content_validator/README.md
```

计划中的探索、肉鸽、存档目录先不建空文件夹，避免把尚未开始的系统看成已经存在。阶段 1 新增了 `scripts/combat`、`scripts/economy`、`scenes/combat`、`data/enemies` 和 `data/combat`。

## 阶段 1 的战斗边界

- 防守场景负责把关卡配置、网格、界面和胜负接起来。寻路、生命、投射物、波次和金币各自单独实现。
- 城墙和弓箭塔使用行为类型 `blocker` 和 `ranged`。放置、伤害和寻路不判断建筑显示名或具体 id。
- 未知行为类型在读取配置时失败。战斗建筑场景若收到未支持的类型，也会返回错误。
- 敌人只沿四方向走空格子。全局最短路由 `AStarGrid2D` 计算，调用在 `GridRoute`。有路就绕开建筑；没有路时攻击挡路的建筑，避免停在原地。敌人不进入固体格。
- 局部间距在 `EnemyUnit` 里处理，不使用导航区域，也不把敌人写成永久障碍。
- 地面是 `TileMapLayer`。道路用 TileSet 的四边地形连接选图。地形种类不改变占格。建造仍走 `PlacementGrid`。
- 主场景是 `scenes/combat/defense_match.tscn`。`scenes/main/tech_demo.tscn` 仍只做阶段 0 验证。

## 内容如何扩展

新增一座使用现有表现的建筑时，应新增一份建筑 JSON，并复用已有场景。放置和加载代码不写 `if id == "某种建筑"`。

阶段 0 的扩展点只有一个：建筑场景提供 `setup(world_position, size_px, building_id, display_name)`。占位建筑用这份数据画矩形和名称。真正的攻击行为要等战斗阶段做成可复用组件，仍然不能按建筑名字分支。

复杂的新行为以后走明确的行为类型。未知行为类型必须报错，不能静默跳过。阶段 0 还没有行为类型字段。

## 技术决策

- 使用本机 Godot 4.7.2 stable 标准版（GDScript，不含 .NET）。API 以这个版本为准。
- 渲染使用 GL Compatibility，方便在普通 Windows 机器和自动化运行里启动。
- 阶段 0 的技术场景仍用 `Node2D._draw` 画网格。防守地图的地面是 `TileMapLayer`。现成草地和道路图不能拼接，图块由 `TerrainField` 生成，道路连接交给 TileSet 地形位。
- 寻路使用 `AStarGrid2D`，只走上下左右，启发函数是曼哈顿距离。攻击城堡、攻击阻挡和胜负仍在游戏代码里。像素坐标转换在 `DefenseMatch.cell_center()` 和 `world_to_cell()`。
- 测试不引入 GdUnit 或其他外部框架。`tests/unit/stage0_checks.gd` 用 Godot 无头模式直接运行。
- 中文界面使用 Windows 的 `SystemFont`（微软雅黑）。不把第三方字体打进仓库。
- 校验器就是 `ContentLoader` / `BuildingDefinition`。`tools/content_validator/` 还没有独立命令行程序。
