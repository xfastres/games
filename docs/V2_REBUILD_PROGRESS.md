# V2 重建进度

日期：2026-10-13。分支 `main`，HEAD `abcce0f`。开始时工作区已有未提交修改，本次没有还原、提交或清理它们。

## 阶段 A：审计和设计

代码已编写，并和场景一致。旧主场景仍是 `res://scenes/combat/defense_match.tscn`。

## 阶段 B：地图和寻路

代码已编写。自动化通过，见下方命令。窗口画面能看到草地和道路，见阶段 E。

## 阶段 C：群体移动

代码已编写。20 人、停住后放行、拆墙后续行的自动化通过。

## 阶段 D：战斗和状态

代码已编写。金币、伤害、三波胜利、失败和重新开始的自动化通过。旧阶段 0、阶段 1、阶段 1.5 回归通过。

## 阶段 E：动画、素材和界面

界面、锚点和现有单帧图已接上。窗口验证看到顶栏和战场。五段动作没有真实分帧，这一条验收没有通过，所以没有进入阶段 F 的主场景切换。

## 阶段 F：切换主场景

没有执行。`project.godot` 的主场景保持旧版。

## 本次实际运行

可执行文件：`%LOCALAPPDATA%\Godot\4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`。

| 命令 | 退出码 | 关键结果 |
| --- | --- | --- |
| `--headless --script res://tests/v2/path_checks.gd` | 0 | `V2_PATH_PASS` |
| `--headless --script res://tests/v2/terrain_checks.gd` | 0 | `V2_TERRAIN_PASS`，东向 `(64, 0)`，南向 `(0, 64)` |
| `--headless --script res://tests/v2/crowd_checks.gd` | 0 | `V2_CROWD_PASS` |
| `--headless --script res://tests/v2/combat_checks.gd` | 0 | `V2_COMBAT_PASS` |
| `--headless --script res://tests/unit/stage0_checks.gd` | 0 | `STAGE0_PASS` |
| `--headless --script res://tests/unit/stage1_checks.gd` | 0 | `STAGE1_PASS` |
| `--headless --script res://tests/unit/stage1_5_route_checks.gd` | 0 | `STAGE15_ROUTE_PASS` |
| `--headless --script res://tests/unit/stage1_5_terrain_checks.gd` | 0 | `STAGE15_TERRAIN_PASS` |
| `--headless --script res://tests/unit/stage1_5_crowd_checks.gd` | 0 | `STAGE15_CROWD_PASS` |
| `--path F:\xufeng\games res://scenes/v2/match.tscn --quit-after 4 -- --shot` | 0 | `V2_SHOT OK`，OpenGL 3.3 Compatibility |

20 人走廊：240 物理帧，全部存活，中心最小距 34.05，重叠帧 0，单帧最大位移 1.17，横向位置合计减少约 5387。前方停住时后方没有越过它，最小距 34.02；前方死亡后队伍继续前进。拆墙用了 679 帧，之后有敌人到达墙格以西，重叠帧 0。

三波战斗：742 帧，`waves=3`，`outcome=victory`，金币 144（18 次击杀 × 8），城堡仍是 300。不建造时的失败夹具在 46 帧内把 9 点生命打成 0，结果是 `defeat`。

这些是自动化和一次窗口截图。没有做人工逐点击的完整试玩。
