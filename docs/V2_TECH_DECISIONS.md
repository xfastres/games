# V2 技术决策

日期：2026-10-13。引擎：Godot 4.7.2.stable.official.ed1daf0bf。

这些选择以当时的探测和测试为准。要更换时，先改本文件并补可复现的验证。

## 采用的原生能力

| 能力 | 负责 | 不负责 | 代码 |
| --- | --- | --- | --- |
| `AStarGrid2D` | 四方向最短路。`DIAGONAL_MODE_NEVER`，启发函数是曼哈顿距离。固体点只来自城堡和建筑 | 攻击哪一座墙、胜负、敌人间距、每帧重算 | `scripts/v2/path/fw_path_grid.gd` |
| `TileMapLayer` + `TileSet` | 逻辑格和世界坐标的唯一换算；铺地 | 建造费用和寻路阻挡 | `FwTerrainBoard.apply()`，`FwMatch.cell_to_world()` |
| TileSet 地形 | `TERRAIN_MODE_MATCH_SIDES`，`set_cells_terrain_connect()` 选择直线、转角、T 字和十字 | 手写 16 宫格最终贴图。地形种类不写入阻挡表 | `scripts/v2/map/fw_terrain_board.gd` |
| `CharacterBody2D` | `move_and_slide()` 按速度移动。`MOTION_MODE_FLOATING` | 不与其他敌人发生刚体碰撞。`collision_mask = 0` | `scripts/v2/entities/fw_enemy.gd` |
| `Area2D` | 弓箭塔按配置射程收集 `collision_layer = 2` 的敌人 | 不决定伤害数字，也不阻挡寻路 | `FwStructure._add_range()` |
| 信号和 `queue_free()` | 城堡摧毁、建筑拆毁、敌人死亡 | — | `FwCastle`、`FwStructure`、`FwEnemy` |
| 物理帧 `delta` | 波次间隔、攻击间隔、受伤闪动 | 不为每个冷却各挂一个 `Timer` 节点 | `FwWaveDirector`、`FwEnemy`、`FwStructure` |

## 明确不用

### 等距 TileSet

探测脚本在 Godot 4.7.2 里对 `TILE_SHAPE_ISOMETRIC` 逐个调用 `set_terrain_peering_bit`。能写入并读回 0 的只有：

- `TERRAIN_MODE_MATCH_SIDES`：`TOP_SIDE`、`BOTTOM_SIDE`、`TOP_CORNER`、`BOTTOM_CORNER`。`RIGHT_SIDE` 和 `LEFT_SIDE` 被引擎拒绝。
- `TERRAIN_MODE_MATCH_CORNERS`：`BOTTOM_RIGHT_SIDE`、`TOP_LEFT_SIDE`、`BOTTOM_RIGHT_CORNER`、`TOP_LEFT_CORNER`。

两种模式都给不出东西南北四个方向，无法做直线、转角、T 字和十字。因此 V2 使用方格 `TileSet`，格距 64。现有草地 PNG 尺寸分别是 81×66、99×76 等，不能铺进这个 TileSet，地面图块是运行时生成的开发图块。

### `NavigationAgent2D` / RVO

不使用。导航网格会变成第二套全局寻路，和 `AStarGrid2D` 冲突。局部间距放在敌人脚本里，并且由群体测试约束。

### `AnimatedSprite2D`

不使用。`goblin.png` 是 42×51 单帧。复制这一张图不会变成五段动作。有真实分帧后再接 `AnimatedSprite2D`。

### 旧版重复实现

V2 不调用 `GridRoute`、`TerrainField`、`EnemyUnit`、`DefenseMatch`。这些文件留在原处，旧场景继续用它们。

## 保留的旧代码

| 代码 | 原因 |
| --- | --- |
| `ContentLoader`、`DefenseMatchConfig`、`BuildingDefinition`、`EnemyDefinition`、`WaveSet` | 已有字段、未知行为和坏路径校验。V2 的 JSON 指向 V2 场景，不复制一套解析器 |
| `GoldWallet`、`HealthPool` | 花费、奖励和扣血规则已经测过，没有场景依赖 |
| `UiFont` | 中文系统字体 |
| `assets/sprites/` 里已检查的单帧 PNG | 原图不复制。清单在 `assets/v2/manifest.json` |

## 间距容差

跟随距离 48 像素开始减速，34 像素停下。自动化把中心距低于 22 像素记为重叠。哥布林贴图宽 42，中心距 34 时纹理外框可能有大约 4 像素交叠；不把这一张单帧复制成走路动画，也不把贴图外框当成刚体。
