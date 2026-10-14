# Godot 原生能力审计

日期：2026-10-13。引擎：Godot 4.7.2.stable.official.ed1daf0bf。仓库 `main`，HEAD `abcce0fb1b8e95f2f4e430e94d8a7d54699289a3`。开始时工作区干净，没有未提交修改。

审计依据是当时的脚本和调用路径，不是场景里有没有某个节点名字。结论分四级：

- P0：当前功能有严重错误或已经堵住流程。
- P1：手写基础能力和引擎重复，并且影响正确性或后续维护。
- P2：适合这次或紧接着做的重构。
- P3：可以暂缓。

本次没有发现 P0。寻路步数、绕墙、拆墙重算和群体排队在阶段 1.5 的测试里已经成立。问题是这些能力大多是手写的，地形连接也没有走 TileSet 的地形位。

## 1. 网格与寻路

| 项 | 内容 |
| --- | --- |
| 当前路径 | `DefenseMatch.route_plan()` 按格子缓存，缓存未命中时调用 `GridRoute.plan()`。放置和拆除调用 `_invalidate_routes()`，代数加一，敌人下一次行动才重算。 |
| 文件 | `scripts/combat/grid_route.gd`、`scripts/combat/defense_match.gd`、`scripts/combat/enemy_unit.gd` |
| 手写部分 | 四方向广度优先。自己维护队列、距离表和父节点。邻居顺序是东、西、南、北。等长目标再按横向差、y、x 选择。 |
| 是否最短 | 代价都是 1，广度优先的步数是最短的。注释里写了曼哈顿启发，搜索本身不是 A*，没有启发函数。 |
| 障碍 | `blocked` 只来自城堡占格和建筑占格。敌人坐标在 `_enemy_at`，不会写入 `_blocked`。 |
| 拆墙 | `notify_structure_destroyed()` 擦掉占格并清空路径缓存。 |
| 无路 | 第二次搜索允许走进阻挡，停在第一面墙或城堡上，返回 `attack_blocker` 或 `attack_castle`。走不通时 `ok=false`，错误文本含原因。 |
| 原生能力 | `AStarGrid2D`。规则方格、四方向、单位代价，和这个 API 一致。 |
| 是否已正确使用 | 没有。工程里没有任何 `AStarGrid2D` 调用。 |
| 是否值得替换 | 值得替换最短路计算。攻击城堡、攻击阻挡和无路错误是玩法，要留在 `GridRoute.plan()`。 |
| 替换成本 | 小。地图只有十几列。已用无头脚本确认：`DIAGONAL_MODE_NEVER` 加曼哈顿启发时，`(0,0)` 到 `(2,2)` 的路径就是现有测试锁定的 `(0,0)→(1,0)→(2,0)→(2,1)→(2,2)`。 |
| 回归风险 | 等长路径的形状如果和旧队列顺序不同，会碰到 `stage1_5_route_checks.gd` 的路径断言。探测结果与该断言一致。 |
| 推荐 | P1。用 `AStarGrid2D.get_id_path()` 计算可走最短路。墙和城堡用 `set_point_solid()`。无路时另开一张不把墙标成固体的网格，只用来选出要攻击的阻挡，敌人仍不穿过它。不把敌人格标成固体。继续用现有的按格缓存，不每帧重算。 |

不采用 `NavigationRegion2D` 做这张网格的全局寻路。城墙会建也会拆，导航多边形要反复烘培；建造和攻击都已经是格子。两套全局寻路不能叠在同一个敌人上。

## 2. 地图与瓦片

| 项 | 内容 |
| --- | --- |
| 当前路径 | `DefenseMatch._build_ground()` 创建 `TileMapLayer`，位置等于 `map_origin`。`TerrainField` 决定每格种类，再 `set_cell()`。 |
| 文件 | `scripts/world/terrain_field.gd`、`scripts/combat/defense_match.gd`、`scripts/world/placement_grid.gd` |
| 手写部分 | 运行时画 64×64 色块。道路用上下左右掩码从 16 张图里选一张。这是自己做的自动连接。 |
| 素材 | `assets/sprites/terrain/grass_tile_01.png` 到 `04` 是尺寸不一的菱形。`assets/source/art_pack_a/terrain/` 里的道路裁图只有数像素到几十像素。不能当成可连接图块。 |
| 原生能力 | 已经在用 `TileMapLayer` 和 `TileSetAtlasSource`。没有使用 TileSet 地形集合、`set_terrain_peering_bit` 或 `set_cells_terrain_connect`。 |
| 逻辑分离 | 地形种类不写入 `_blocked`。寻路只看建筑和城堡。`PlacementGrid` 仍负责占地，不该删。 |
| 坐标 | 方格，不是等距菱形。`cell_center()` 和 `world_to_cell()` 用 `map_origin` 与 `cell_size`。TileMapLayer 的格子坐标和逻辑格一致。 |
| 是否值得替换 | 值得把道路选图换成地形连接。图块仍用程序生成的 16 连通路，因为现成图片不合格。 |
| 替换成本 | 小。Godot 4.7 的接口是 `add_terrain_set(位置)`、`add_terrain(集合, 位置)`，`get_tile_data(坐标, 备选)` 必须带备选编号。探测里直线、转角、T 字和十字的图块坐标与现有掩码一致。 |
| 回归风险 | 地形连接会改写相邻格。连接之后要把非道路格刷回去，否则草地会被改掉。不能改成菱形坐标。 |
| 推荐 | P1。地面继续用 `TileMapLayer`。道路配置 `TERRAIN_MODE_MATCH_SIDES`，由 `set_cells_terrain_connect()` 选图。草地、泥土、石地仍是普通图块。建筑继续是独立场景，不画进地面层。 |

`DefenseMatch._draw()` 仍画建造预览和淡格线，那是操作反馈，不是地图本体。

## 3. 角色移动与碰撞

| 项 | 内容 |
| --- | --- |
| 敌人 | `scenes/combat/enemy_unit.tscn` 根节点是 `Node2D`。`EnemyUnit._move_along()` 直接改 `global_position`。 |
| 领主 | `TempLord` 是 `CharacterBody2D`，`move_and_slide()`，只存在于阶段 0 的技术场景，不在防守主场景里。 |
| 手写部分 | 敌人用前向间距减速、侧向推开、以及 `_step_unblocked()` 拒绝走进 `is_path_blocked()` 的格子。 |
| 物理关系 | 敌人之间没有碰撞体。城墙和城堡也不是刚体。阻挡是逻辑占格。 |
| 互相堵住 | 阶段 1 的 `try_begin_step()` 会预约目标格，预约失败就停住。当前移动循环已经不再调用它。方法还留着，因为敌人 `setup()` 要求棋盘提供这组接口。 |
| 原生能力 | `CharacterBody2D` 适合领主这种需要滑墙的可控角色。不适合把整队敌人改成互相碰撞的刚体，窄路会卡死。 |
| 是否已正确使用 | 领主使用正确。敌人没有使用，而且不该为了“用上节点”改成刚体。 |
| 推荐 | P3。敌人保持 `Node2D` 加逻辑占格。刚体碰撞不接管寻路阻挡。 |

## 4. 群体移动与动态避障

| 项 | 内容 |
| --- | --- |
| 当前路径 | 全局路：`route_plan()`。局部：`enemies_near()` 距离小于 48 像素就减速，停滞约 0.35 秒后才侧向，侧向不得后退，绕路不得超过 1 步。没有侧格就排队。 |
| 文件 | `scripts/combat/enemy_unit.gd`、`tests/unit/stage1_5_crowd_checks.gd` |
| 手写部分 | 间距、推开和侧步。没有使用 RVO。 |
| 原生能力 | `NavigationAgent2D` 的 `avoidance_enabled` 能做局部避让，但需要导航网格，并且 `velocity_computed` 仍要自己移动。它不保证单格通道里的对向穿行。 |
| 是否已正确使用 | 没有使用导航代理。当前也没有第二套全局寻路。 |
| 推荐 | P3，这次不引入。职责定为：`AStarGrid2D` 管全局格路；`_blocked` 管建筑和城堡；局部间距管相邻敌人；敌人状态仍是移动、攻城堡、攻阻挡、死亡。同一格墙不能同时被寻路固体、刚体和导航障碍各处理一次。阶段 1.5 已覆盖 20 人同向通道、前方停下、死亡后续行、拆墙和城堡攻击。对向穿行仍未做。 |

## 5. 角色动画

| 项 | 内容 |
| --- | --- |
| 当前路径 | `EnemyPresentation` 只保存状态名。`EnemyUnit._draw()` 把 `goblin.png` 画在固定脚底。 |
| 文件 | `scripts/combat/enemy_presentation.gd`、`scripts/combat/enemy_unit.gd`、`assets/sprites/characters/enemies/goblin.png` |
| 素材 | 哥布林是 42×51 单帧。没有 idle、walk、attack、hurt、death 序列。`default_lord.png` 也是单帧，而且没有接到临时领主上。临时领主仍是菱形 `Polygon2D`。 |
| 原生能力 | 有真实逐帧图时应用 `AnimatedSprite2D` 和 `SpriteFrames`。现在没有这种图。 |
| 是否已正确使用 | 没有 `AnimatedSprite2D`。状态切换不改生命和攻击冷却。死亡在 `_die()` 里只发一次赏金，然后 `queue_free()`。没有死亡动画可等。伤害由攻击间隔结算，不由动画帧结算。 |
| 推荐 | P2，保持静态显示。禁止把同一张图复制成多帧。缺的动作记在 `missing_actions`。有序列帧之后再接 `AnimatedSprite2D`，脚底仍用现在的 `FOOT_OFFSET`。 |

## 6. 定时器、信号和生命周期

| 项 | 内容 |
| --- | --- |
| 当前路径 | 攻击冷却、受伤闪动和波次间隔都在 `_physics_process` 里减 `delta`。投射物用 `Tween`。城堡摧毁用 `destroyed` 信号。死亡用 `queue_free()`。敌人用分组 `defense_enemy` 查找。 |
| 文件 | `scripts/combat/enemy_unit.gd`、`scripts/combat/wave_spawner.gd`、`scripts/combat/projectile.gd`、`scripts/combat/ranged_weapon.gd` |
| 手写部分 | 大量单位共用的浮点冷却，不是每个单位一棵 `Timer` 节点。 |
| 推荐 | P3。波次和攻击间隔继续用物理帧计时。几十个敌人各自挂 `Timer` 没有收益。不把 JSON 换成 `Resource`。 |

## 7. 数据和业务逻辑

| 项 | 内容 |
| --- | --- |
| 当前路径 | `ContentLoader` 读 JSON，未知字段、坏路径和未知行为类型直接失败。 |
| 保留 | 金币 200、城堡 300、城墙 10、弓箭塔 50、三波、击杀奖励、胜负和重新开始。这些不迁到引擎节点里。 |
| 推荐 | P3。继续用 JSON，方便以后的内容包和校验。 |

## 优先级汇总

| 级别 | 项 | 本次动作 |
| --- | --- | --- |
| P0 | 无 | 不改战斗规则 |
| P1 | 手写广度优先；手写道路掩码选图 | 迁到 `AStarGrid2D` 和 TileSet 地形连接 |
| P2 | 没有可用动画帧 | 保持静态图，并在报告里标明缺帧 |
| P3 | 刚体、RVO、Timer 节点、JSON 改 Resource、等距坐标 | 不做 |

`PlacementGrid`、造价、生命、波次、胜负和“无路则攻击阻挡”都保留。
