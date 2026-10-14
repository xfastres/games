# V2 验收

## 通过

- 方格 `TileMapLayer` 坐标往返，邻格偏移是 `(64, 0)` 和 `(0, 64)`。
- TileSet 四边地形连接：直线、转角、T 字、十字的邻接位与预期一致。草地格没有被改成道路。拆掉建筑后阻挡消失，地形种类不变。
- `AStarGrid2D` 空图最短路、绕墙、重复搜索稳定、禁止对角、不可达有错误、两个出兵点、拆墙后路径变短。搜索不改写阻挡表，也不把敌人当固体。
- 20 名敌人同时沿单格走廊移动，没有永久堵住，中心距不低于 34，没有低于 22 的重叠帧，也没有单帧跳到终点。
- 前方停下时后方等待；前方死亡后后方继续走。
- 敌人打掉挡路城墙后继续前进。
- 正式配置：金币 200、城堡 300、城墙 10、弓箭塔 50、三波。击杀只加一次 8 金。四座塔清完三波后胜利，城堡仍是 300，金币 144。失败和胜利不同时成立。重新开始恢复金币、生命、敌人和波次。
- 窗口启动并写出 `docs/screenshots/v2_match.png`。顶栏显示金币、城堡和波次，战场在顶栏下面。地面是无缝草地变体，道路能看出直线和路口，城堡使用现有 PNG。
- 旧阶段 0、阶段 1、阶段 1.5 测试退出码都是 0。

## 未通过

角色没有 idle、walk、attack、hurt、death 的不同帧。`FwActorView.uses_frame_animation` 为 false，缺失名单包含这五个动作。因此没有把主场景改到 V2。

## 怎么运行

```
Godot_v4.7.2-stable_win64_console.exe --path F:\xufeng\games res://scenes/v2/match.tscn
```

旧版仍然是默认主场景：

```
Godot_v4.7.2-stable_win64_console.exe --path F:\xufeng\games
```

不需要回退命令。V2 场景是另存的，旧的 `scenes/combat/defense_match.tscn` 和 `scenes/main/tech_demo.tscn` 都还在。
