# 架构

## 工程根目录

游戏工程就是仓库根目录，不另套 `frontier-wardens/`。`AGENTS.md` 已经在根目录，Godot 项目文件也放在这里。

## 职责边界

这些边界是第一版的目标。阶段 0 只实现其中内容校验、网格放置和临时角色移动，其余系统还没有代码。

| 模块 | 职责 | 阶段 0 |
| --- | --- | --- |
| `scripts/content` | 读取并校验内容定义。不负责战斗、经济和场景流程 | 已有建筑定义校验 |
| `scripts/world` | 地图网格、放置规则、技术验证场景编排 | 已有放置网格和验证场景 |
| `scripts/buildings` | 可复用的建筑表现。不知道具体建筑名字 | 已有一个占位场景 |
| `scripts/lord` | 领主移动和控制。不引用具体建筑 | 已有临时领主 |
| `scripts/combat` | 伤害、投射物、目标选择、胜负 | 未实现 |
| `scripts/economy` | 资源库存、产出、花费、拆除返还 | 未实现 |
| `scripts/construction` | 建造、选中、升级、拆除流程 | 未实现 |
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

计划中的战斗、经济、探索、存档目录先不建空文件夹，避免把尚未开始的系统看成已经存在。

## 内容如何扩展

新增一座使用现有表现的建筑时，应新增一份建筑 JSON，并复用已有场景。放置和加载代码不写 `if id == "某种建筑"`。

阶段 0 的扩展点只有一个：建筑场景提供 `setup(world_position, size_px, building_id, display_name)`。占位建筑用这份数据画矩形和名称。真正的攻击行为要等战斗阶段做成可复用组件，仍然不能按建筑名字分支。

复杂的新行为以后走明确的行为类型。未知行为类型必须报错，不能静默跳过。阶段 0 还没有行为类型字段。

## 技术决策

- 使用本机 Godot 4.7.2 stable 标准版（GDScript，不含 .NET）。API 以这个版本为准。
- 渲染使用 GL Compatibility，方便在普通 Windows 机器和自动化运行里启动。
- 阶段 0 的网格用 `Node2D._draw` 画出来。地形图集和 `TileMapLayer` 留到需要真实地形的阶段，避免在没有图块资源时假装地图系统已经完成。
- 寻路留到战斗原型。阶段 0 只验证网格坐标和占用。
- 测试不引入 GdUnit 或其他外部框架。`tests/unit/stage0_checks.gd` 用 Godot 无头模式直接运行。
- 中文界面使用 Windows 的 `SystemFont`（微软雅黑）。不把第三方字体打进仓库。
- 校验器就是 `ContentLoader` / `BuildingDefinition`。`tools/content_validator/` 还没有独立命令行程序。
