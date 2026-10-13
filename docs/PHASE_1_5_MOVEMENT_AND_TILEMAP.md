# 阶段 1.5：寻路、群体移动、动画与瓦片地图

日期：2026-10-13。引擎：Godot 4.7.2。工作区原有未提交修改全部保留，没有重置。

## 1. 根因

结论来自改之前读到的脚本，不是从现象反推。

### 1.1 敌人互相堵住

敌人是 `Node2D`，没有 `CharacterBody2D`，也没有物理碰撞体。移动靠 `global_position.move_toward()`。

挡住队伍的是逻辑占格，不是物理刚体：

- `DefenseMatch._enemy_at` 记录敌人当前格。
- `DefenseMatch._move_claim` 在迈步时再占住目标格。一个正在走的敌人同时占两格。
- `try_begin_step()` 在目标格已有别人或已被预约时直接返回 `false`。
- `EnemyUnit._physics_process()` 在预约失败后什么都不做，下一帧仍向同一格申请。

因此前方敌人停下（攻击城墙、城堡，或自己也在等格子）时，后方只会反复申请同一格。窄路上会排成不能超越的单列；两个人互相要走进对方的格子时会永久对等。寻路没有把敌人写进 `_blocked`，所以这不是“把敌人当成永久障碍”的寻路错误，而是移动预约把暂时的阻挡变成了停步。

### 1.2 路线看起来绕

`GridRoute` 只允许上下左右，代价为 1，启发函数是到最近目标的曼哈顿距离。这个组合下 A* 的步数是最短的，也不存在切墙角。

它每次只返回下一步。等长路线的取舍取决于开放列表里谁先被弹出，方向顺序是东、西、南、北。多个城堡邻格距离相同时，路径可以先拐到横向不齐的邻格，看起来像绕路，步数却一样。

有空路时优先绕开阻挡，只有完全没路才攻击墙。这是阶段 1 已有规则，本阶段没有改成“看见墙就打”。

### 1.3 身体重叠

同一格不会被两个敌人预约成功，所以不是物理穿模。贴图是单帧，画出高度 48 像素、宽度约 40 像素，格子是 64 像素。相邻格子的图会贴得很近。预约失败时大家停在格子中心，观感是挤在一起。

### 1.4 地图是纯色方格

`DefenseMatch._draw()` 用 `draw_rect` 铺深色矩形，再用 `draw_line` 画格线。没有 `TileMapLayer`。格子是 64×64 的正方形，不是菱形等距格。寻路和建造都用这个方格坐标。

素材包里的地形不能拿来拼：

| 文件 | 尺寸 | 原因 |
| --- | --- | --- |
| `assets/sprites/terrain/grass_tile_01.png` 到 `04` | 81×66、99×76、97×70、99×69 | 菱形，边长也不一致 |
| `assets/source/art_pack_a/terrain/road_straight.png` | 7×6 | 图集裁切失败 |
| `road_corner.png` | 5×6 | 同上 |
| `road_crossroad.png` | 5×10 | 同上 |
| `road_t_junction.png` | 46×14 | 不是方格道路 |
| `dirt_tile.png`、`stone_tile.png` | 120×95 | 不是 64×64 可平铺方块 |

`assets/sprite_manifest.json` 里这些草地本来就标了 `used_in_game: false`。

### 1.5 没有动画

`scenes/combat/enemy_unit.tscn` 的根节点是 `Node2D`。`goblin.png` 是 42×51 的单张图，从总图裁出。素材说明写明图集里的动作帧没有导出成对齐的序列。提示词也只要求一张待机参考。没有 idle、walk、attack、hurt、death 的逐帧图。

## 2. 修改

| 文件 | 目的 |
| --- | --- |
| `scripts/combat/grid_route.gd` | 四方向广度优先最短路。返回整条可走路径、步数和终点。等长目标先比步数，再比与起点的横向差，再比 y、x。走不通时返回明确错误。 |
| `scripts/combat/defense_match.gd` | 按格子缓存路径。放置或拆掉阻挡时清空缓存并增加代数。敌人不再用占格锁迈步。出生点按距离让开。地面改成 `TileMapLayer`。 |
| `scripts/combat/enemy_unit.gd` | 沿缓存路径走。只在进入新格或阻挡变化时再查路径。前方过近就减速，不把别人写成永久障碍。侧向只在不后退、绕路不超过 1 步时发生。窄路没有侧格就排队。 |
| `scripts/combat/enemy_presentation.gd` | 动画状态接口。脚底锚点固定。不循环单帧冒充动画。 |
| `scripts/world/terrain_field.gd` | 草地、泥土、道路、石地的逻辑层，以及 64 像素方格图块。道路按上下左右邻接选 16 种连接。 |
| `tests/unit/stage1_5_route_checks.gd` | 寻路测试，调用项目里的 `GridRoute` 和 `DefenseMatch`。 |
| `tests/unit/stage1_5_crowd_checks.gd` | 群体移动测试，使用真实敌人场景和 `DefenseMatch`。 |
| `tests/unit/stage1_5_terrain_checks.gd` | 地形拼接测试，使用真实 `TileMapLayer`。 |
| `tests/fixtures/defense/crowd_match.json` 等 | 群体测试关卡。 |

`try_begin_step()` 还在，是为了棋盘方法检查。新的移动循环不再调用它，所以不会和软间距叠成两套锁。

地形图是运行时画的 64×64 纯色方块，不是素材包里的菱形或裁坏的道路。正式关卡仍用原来的方格坐标。草地变体、出兵点泥土、两条横向道路和左侧竖向连接已经铺到主场景。道路不写入 `_blocked`。石地和 T 字、十字只在测试里铺，避免石地看起来像一堵墙。

## 3. 寻路测试

命令：

```
Godot_v4.7.2-stable_win64_console.exe --headless --path F:\xufeng\games --script res://tests/unit/stage1_5_route_checks.gd
```

退出码 0。最后一行 `STAGE15_ROUTE_PASS`。

断言的是步数、每步恰好上下左右一格、不走进阻挡、以及终点，不是“数组非空”。

| 情况 | 结果 |
| --- | --- |
| 空地图 (0,0) 到 (5,0) | 长度 5，终点 (5,0) |
| 城堡在 (0,0)，从 (5,0) 接近 | 长度 4，停在城堡旁的 (1,0)，终端是攻击城堡 |
| 墙在 (2,1)，从 (4,1) 到 (0,1) | 长度 6，大于直线曼哈顿距离 4，路径不含墙 |
| (0,0) 到 (2,2) 的两条长度 4 的路 | 稳定选择 (0,0)→(1,0)→(2,0)→(2,1)→(2,2)。南边那条同样是 4 步，不会被选中。连续两次结果相同 |
| 目标格被墙挡住 | 先走到墙前，终端是 `attack_blocker`，攻击格就是那面墙 |
| 城堡在地图外、没有城堡、人站在城堡格上 | `ok=false`，错误文本分别含“找不到”“没有可攻击”“城堡格子” |
| 拆墙 | 短关卡从 (7,1) 出发，无墙长度 6。放墙后变长，代数 +1。墙被打掉后长度回到 6，缓存再次失效 |

寻路没有把起点写进阻挡表。

## 4. 群体移动测试

命令：

```
Godot_v4.7.2-stable_win64_console.exe --headless --path F:\xufeng\games --script res://tests/unit/stage1_5_crowd_checks.gd
```

退出码 0。最后一行 `STAGE15_CROWD_PASS`。物理帧 60 Hz（`CROWD_PHYSICS_HZ 60`）。异常重叠指任意两名存活敌人距离小于 30 像素的帧数。哥布林画出的宽度约 40 像素。

| 情况 | 帧数 | 真实耗时 | 到达 | 剩余 | 最大停滞 | 最小间距 | 重叠帧 | 城堡生命 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10 人从同一出兵点依次走向城堡 | 559 | 9321 ms | 10 人进入城堡前区，其中 3 人进入攻击 | 10 人存活 | 0.70 秒 | 34.3 px | 0 | 4664 / 5000 |
| 20 人走单格宽通道 | 325 | 5268 ms | 20 人通过出口 | 通道内 0 | 0.00 秒 | 48.0 px | 0 | 5000 |
| 前方停住 | 150 | 2346 ms | 0 | 5 | 2.35 秒 | 39.9 px | 0 | 5000 |
| 前方死亡后 | 119 | 1987 ms | 4 人贴到城堡，1 人进入攻击 | 4 | 2.35 秒 | 42.5 px | 0 | 5000 |
| 拆墙后改走新路 | 201 | 3350 ms | 4 人到达墙后的城堡侧，2 人攻击 | 4 | 0.35 秒 | 39.9 px | 0 | 4928 |
| 8 人靠近城堡 | 43 | 581 ms | 8 人有位移或进入攻击，3 人同时攻击 | 8 | 0.22 秒 | 44.2 px | 0 | 4976 |

20 人通道是 24×1、格子 48 像素的单行地图。到达出口（x≤1）的人会被移出战斗组，避免他们停在城堡前把通道堵死。这测的是通道能否排过去，不是 20 人同时挤在一个城堡邻格里。预算 900 帧，实际 325 帧走完。

10 人那组的最小间距是 34.3 像素，低于理想间距 48，但没有一帧低于 30。约 40 像素宽的身体会有几像素交叠。

拆墙用例里，有墙时的路径比拆掉后更长，路径代数增加，拆墙前没有人站进墙格。

宽广场收进一个单格路口时，队伍会在路口外排成长队，尾部不一定在城堡攻击结束前全部穿过。这个形状没有当成通过条件。

## 5. 动画

没有完成多帧动画。`goblin.png` 是 42×51 单帧。`EnemyPresentation.uses_frame_animation` 为 false。缺少的动作是 idle、walk、attack、hurt、death。

状态接口会在移动、攻击、受伤、死亡时切换名字。换状态不改生命、攻击冷却和路径。脚底锚点固定在局部 y=18，高度 48，测试确认 walk 和 attack 的矩形底边相同。死亡没有动画可等，仍然走原来的 `_die()`，赏金只在那里发一次。阶段 1 的原型结算金币仍是 154，和以前一致。

攻击伤害仍由攻击间隔结算，不由动画帧结算。

## 6. 瓦片连接

方格，64×64。逻辑种类和图片分开。邻接只看上下左右是不是道路。

| 连接 | 掩码 | 图块坐标 |
| --- | --- | --- |
| 横向直线 | 东+西 = 10 | (2, 2) |
| 纵向直线 | 北+南 = 5 | (5, 1) |
| 转角 | 东+南 = 6 | (6, 1) |
| T 字 | 东+南+西 = 14 | (6, 2) |
| 十字 | 15 | (7, 2) |
| 泥土 |  | (4, 0) |
| 石地 |  | (5, 0) |
| 草地变体 | 由格子坐标决定 | (0..3, 0) |

改一格后，相邻道路的掩码和图块会重算。把正式关卡的道路格改成石地，阻挡格数量和寻路长度都不变。

正式关卡上能看到草地变体、出兵点泥土、直线道路和转角。T 字和十字在测试地图里通过，没有铺进正式关卡。石地同样只在测试里出现。

## 7. 运行截图

窗口实际启动，OpenGL 3.3，设备 NVIDIA GeForce GTX 1060。命令退出码 0。

```
Godot_v4.7.2-stable_win64_console.exe --path F:\xufeng\games -- --shot
```

输出：

```
DEFENSE_READY base.defense_prototype gold=200 waves=3
STAGE1_SHOT .../stage1_preview.png
STAGE1_SHOT .../art_integration_preview.png
```

副本：

- `docs/screenshots/phase1_5_ground.png`：草地、泥土出兵点和道路。
- `docs/screenshots/phase1_5_units.png`：同一地面上的城堡、城墙、弓箭塔、静态哥布林和箭。

这是启动后的摆拍，不是人手打完一局。哥布林仍是一张静态图。

## 8. 命令、退出码和关键输出

可执行文件：`%LOCALAPPDATA%\Godot\4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`。

| 命令 | 退出码 | 关键输出 |
| --- | --- | --- |
| 对 31 个 `.gd` 执行 `--headless --path F:\xufeng\games --check-only --script <脚本> --quit` | 0 | 每个文件 `CHECK_OK`，`CHECK_FAILED 0`。含阶段 0、阶段 1 和本阶段测试脚本 |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage0_checks.gd` | 0 | `STAGE0_PASS` |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage1_checks.gd` | 0 | `STAGE1_PASS`。`PROTOTYPE_RESULT outcome=victory frames=1270 城堡 300/300 alive=0 gold=154`。坏 JSON 仍打印 `DEFENSE_LOAD_FAIL` |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage1_5_route_checks.gd` | 0 | `STAGE15_ROUTE_PASS` |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage1_5_crowd_checks.gd` | 0 | `STAGE15_CROWD_PASS`。明细见第 4 节 |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage1_5_terrain_checks.gd` | 0 | `STAGE15_TERRAIN_PASS` |
| `--path F:\xufeng\games -- --shot` | 0 | `DEFENSE_READY`，两张 `STAGE1_SHOT` |

阶段 1 原有断言没有删，也没有放宽。原型仍是三波胜利、城堡满血、金币 154。

## 9. 尚未解决

- 哥布林没有可用的多帧动作。状态接口在，画面仍是静态图。
- 素材包的草地和道路不能拼接。现在的地块是程序生成的色块，不是手绘无缝图。
- 10 人混战时最小间距 34.3 像素，身体会有轻微交叠。
- 宽区域收进单格路口时，尾部会在路口外排队，不保证在城堡前的人停住之前全部通过。
- 单格通道里没有做对向穿行。测试覆盖的是同向排队。
- 1×1 城堡只有少数邻格能同时攻击。其余的人在旁边等，不会人人同时砍城堡。
- 格子线上仍留了一层淡线，方便对准建造。

## 10. 完成程度

| 项 | 状态 |
| --- | --- |
| 寻路、群体移动、地形逻辑、动画状态接口 | 已编写 |
| 阶段 0、阶段 1、寻路、群体、地形、全部脚本解析 | 自动化测试通过 |
| 主场景窗口启动并拍到带道路的地面和单位 | 游戏窗口实际验证 |
| 人手打一局、走路动画、手绘道路替换程序色块 | 仍需人工验收 |
