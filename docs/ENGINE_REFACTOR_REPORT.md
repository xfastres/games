# 引擎能力重构报告

日期：2026-10-13。引擎：Godot 4.7.2.stable.official.ed1daf0bf。可执行文件：`%LOCALAPPDATA%\Godot\4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`。

审计见 `docs/GODOT_NATIVE_FEATURE_AUDIT.md`。这次没有进入阶段 2，也没有加探索、肉鸽、存档或工坊。

## 1. 原来手写的基础能力

- `GridRoute._shortest()` 自己维护队列、距离和父节点，做四方向广度优先。注释写了曼哈顿距离，搜索并没有使用启发函数。
- `TerrainField` 用上下左右掩码从 16 张程序图里选道路图，再 `set_cell()`。`TileMapLayer` 已经在用，地形连接没有用。
- 敌人是 `Node2D`，直接改 `global_position`，并用距离做减速和侧步。
- 攻击冷却和波次间隔在物理帧里减 `delta`。
- 哥布林用 `_draw()` 画单帧图。没有 `AnimatedSprite2D`。

## 2. 已迁到 Godot 的部分

### 全局寻路

调用路径：

1. 放置：`DefenseMatch.place_at_world_position()` 把建筑占地写入 `_blocked`，再 `_invalidate_routes()`。
2. 拆除：`DefenseMatch.notify_structure_destroyed()` 擦掉占地并清空缓存。
3. 查询：`EnemyUnit._choose_action()` 只在路径代数变化时调用 `DefenseMatch.route_plan()`。
4. `route_plan()` 未命中缓存时调用 `GridRoute.plan()`。
5. `GridRoute._make_grid()` 创建 `AStarGrid2D`，设置区域、格子像素、`DIAGONAL_MODE_NEVER` 和 `HEURISTIC_MANHATTAN`，对建筑与城堡调用 `set_point_solid()`，再用 `get_id_path()`。

敌人坐标不进入固体格。无路时另建一张不把墙标成固体的网格，只用来决定攻击哪一格；返回的可走路径在墙前停下。

改之前用无头脚本确认过：同一起终点、关闭对角、曼哈顿启发时，`(0,0)` 到 `(2,2)` 的原生路径就是原测试锁定的东边那条。该探测脚本已删除，正式断言仍在 `stage1_5_route_checks.gd`。

### 地面

调用路径：

1. `DefenseMatch._build_ground()` 创建 `TileMapLayer`，逻辑格与图层格相同，原点是 `map_origin`。
2. `TerrainField._build_tileset()` 生成 64×64 图块，并 `add_terrain_set()`、`set_terrain_set_mode(MATCH_SIDES)`、`set_terrain_peering_bit()`。
3. `TerrainField.apply()` 对道路格调用 `TileMapLayer.set_cells_terrain_connect()`。草地、泥土、石地仍是普通 `set_cell()`。连接如果改写了邻格，非道路格会再刷回去。

现成草地是菱形，道路裁图不是方格图集，没有拿去自动连接。

## 3. 保留的自定义逻辑

| 逻辑 | 原因 |
| --- | --- |
| 攻击城堡、攻击阻挡、无路错误文本 | 玩法规则，不是通用寻路 |
| `PlacementGrid`、造价、金币、生命、波次、胜负 | 内容与战斗规则 |
| JSON 校验 | 以后的内容包需要明确失败，而不是改成 `Resource` |
| 敌人局部间距 | 不与网格固体、刚体和导航代理叠在同一件事上 |
| 物理帧冷却 | 大量敌人不值得每人挂一个 `Timer` |
| 静态哥布林绘制 | 没有真实逐帧图。不复制单帧去冒充 `SpriteFrames` |
| `try_begin_step()` | 移动循环已不再调用。敌人 `setup()` 仍要求棋盘提供这个方法，所以接口还在 |

没有使用 `NavigationAgent2D`。城墙会建会拆，全局路已经由格子固体表示。再烘一套导航网格会变成第二套全局寻路。RVO 也不能保证单格通道里对向穿行。

没有把敌人改成互相碰撞的 `CharacterBody2D`。领主技术场景里的 `CharacterBody2D.move_and_slide()` 保持原样。

## 4. 新增和修改的文件

修改：

- `scripts/combat/grid_route.gd`
- `scripts/combat/defense_match.gd`
- `scripts/combat/enemy_unit.gd`
- `scripts/combat/enemy_presentation.gd`
- `scripts/world/terrain_field.gd`
- `tests/unit/stage1_5_route_checks.gd`
- `tests/unit/stage1_5_terrain_checks.gd`
- `tests/unit/stage1_5_crowd_checks.gd`
- `docs/ARCHITECTURE.md`
- `docs/DATA_SCHEMA.md`

新增：

- `docs/GODOT_NATIVE_FEATURE_AUDIT.md`
- `docs/ENGINE_REFACTOR_REPORT.md`
- `tests/fixtures/defense/crowd_cross.json`
- `tests/fixtures/defense/crowd_junction.json`
- `docs/screenshots/engine_refactor_ground.png`
- `docs/screenshots/engine_refactor_units.png`

没有 Git 提交。

## 5. 命令、退出码和关键输出

工作目录都是 `F:\xufeng\games`。

| 命令 | 退出码 | 关键输出 |
| --- | --- | --- |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage1_5_route_checks.gd` | 0 | `STAGE15_ROUTE_PASS`。含拆墙重算和两个出兵点 |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage1_5_terrain_checks.gd` | 0 | `STAGE15_TERRAIN_PASS` |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage0_checks.gd` | 0 | `STAGE0_PASS` |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage1_checks.gd` | 0 | `STAGE1_PASS`。`PROTOTYPE_RESULT outcome=victory frames=1270 城堡 300/300 alive=0 gold=154` |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage1_5_crowd_checks.gd` | 0 | `STAGE15_CROWD_PASS`。明细见下表 |
| 对 31 个 `.gd` 执行 `--headless --check-only --script <脚本> --quit` | 0 | 每个文件 `CHECK_OK`，`CHECK_FAILED 0` |
| 十字路口用例写入后再对 `stage1_5_crowd_checks.gd` 执行 `--check-only` | 0 | `CHECK_EXIT 0` |
| `--path F:\xufeng\games -- --shot` | 0 | OpenGL 3.3，GTX 1060。`DEFENSE_READY ... gold=200 waves=3`，两张 `STAGE1_SHOT` |

群体用例，物理帧 60 Hz：

| 情况 | 帧数 | 耗时 | 结果 |
| --- | --- | --- | --- |
| 10 人同向走向城堡 | 559 | 9317 ms | 10 人进入前区，3 人攻击，最小间距 34.3，重叠帧 0，城堡 4664/5000 |
| 20 人单格通道 | 325 | 5268 ms | 20 人通过出口，最小间距 48.0，重叠帧 0 |
| 前方停下 | 150 | 2347 ms | 没有人穿过停下的敌人，最大停滞 2.35 秒 |
| 前方死亡 | 119 | 1980 ms | 1 人进入攻击，其余贴到城堡前 |
| 拆墙后改道 | 201 | 3343 ms | 有墙路径更长，拆墙后 2 人攻击，没有人站在活墙上 |
| 8 人攻击城堡 | 43 | 567 ms | 3 人同时攻击，城堡掉血，最小间距 37.3 |
| 20 人相向，城堡在三行通道中央 | 65 | 943 ms | 左右各至少 1 人到达，城堡掉到 4976，最小间距 61.0 |
| 20 人十字路口，北流与东流 | 92 | 1394 ms | 北侧 3 人进入横路，东侧 8 人越过路口，1 人进入攻击，没有人离开开放十字，最小间距 37.9 |

寻路断言仍包括：空图长度 5、绕墙长度 6、等长路径稳定为 `(0,0)→(1,0)→(2,0)→(2,1)→(2,2)`、墙前攻击、不可达错误、敌人不写入阻挡表、放墙和拆墙后的长度变化。两个正式出兵点 `(15,2)` 与 `(15,5)` 的路径长度都是 14，终点分别是 `(1,2)` 和 `(1,5)`，不进入城堡格。

地形连接断言：草地留在地面行；横直 `(2,2)`、竖直 `(5,1)`、转角 `(6,1)`、T 字 `(6,2)`、十字 `(7,2)`。这些坐标来自图层上的 `get_cell_atlas_coords()`，不是只检查掩码函数。

阶段 1 原有断言没有删除。原型仍是三波胜利、城堡 300/300、金币 154。开局金币、城墙 10、弓箭塔 50 没有改。

## 6. 游戏窗口

实际启动了游戏窗口，不是无头模式。设备是 NVIDIA GeForce GTX 1060，OpenGL 3.3。退出码 0。

看过两张画面：

- `docs/screenshots/engine_refactor_ground.png`：金币 200，城堡 300/300，波次 0/3。草地变体、两侧出兵泥土、横向道路和左侧转角连在一起。
- `docs/screenshots/engine_refactor_units.png`：放置城墙和弓箭塔后金币为 140。城堡、城墙、弓箭塔、静态劫掠者和箭都在同一张地面上。

这是启动后的摆拍。没有用手打完一局。

## 7. 仍未验证

- 人手从开始波次打到胜利或失败，再点重新开始。
- 单格通道里的对向穿行。当前规则是排队，不从别人身上穿过去。前方停下的测试锁定了这个行为。
- 正式关卡画面里的 T 字和十字。主场景道路是两条横路加左侧连接，T 字和十字只在自动化测试里铺过。
- 走路、攻击、受伤、死亡的逐帧动画。素材不存在。
- `NavigationAgent2D` 避障。按审计没有接入，因此也没有做它的狭窄通道实验。

## 8. 剩余问题

| 优先级 | 问题 |
| --- | --- |
| P2 | 哥布林和临时领主都没有动作序列。状态名会变，画面仍是一张图。死亡没有动画可等，赏金仍在 `_die()` 里发一次。 |
| P2 | 10 人混战时最小间距 34.3 像素，身体会有轻微交叠。 |
| P3 | 单格通道不做对向换位。宽路收成一格时，后排会在路口外排队。 |
| P3 | 程序生成的道路色块还不是手绘无缝图。现有素材不能替换。 |
| P3 | 格子线上仍留淡线，用来对准建造。 |

下一阶段建议仍按开发计划做经济和建造。不要为了补动画去复制单帧，也不要在这一阶段引入导航网格。
