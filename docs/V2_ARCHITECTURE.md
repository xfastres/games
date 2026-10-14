# V2 架构

V2 是平行于旧版防守原型的可运行场景，代码在 `scripts/v2/`、`scenes/v2/`、`data/v2/`、`tests/v2/`。旧版 `scenes/combat/defense_match.tscn` 和 `scenes/main/tech_demo.tscn` 仍是原来的入口和回退场景。`project.godot` 的主场景没有改成 V2。

## 职责

| 层 | 代码 | 负责 | 不负责 |
| --- | --- | --- | --- |
| 地图表现 | `FwTerrainBoard`、`TileMapLayer` | 方格 TileSet、草地变体、道路四边地形连接 | 金币、生命、胜负 |
| 地图逻辑 | `FwLogicMap` | 尺寸、建筑和城堡占格、通行状态 | 画角色和建筑、把路过的敌人写成障碍 |
| 寻路 | `FwPathGrid` | 四方向最短路、不可达错误、缓存和失效 | 金币、UI、局部间距 |
| 实体 | `FwCastle`、`FwEnemy`、`FwStructure`、`FwProjectile` | 自己的生命、移动、攻击和信号 | 整局胜负和波次队列 |
| 对局 | `FwMatch`、`FwWaveDirector` | 把配置、建造、波次、伤害和胜负接起来 | 代替寻路或地形连接 |
| 经济与生命 | 复用 `GoldWallet`、`HealthPool` | 花费、击杀奖励、扣血 | 地图和动画 |
| 界面 | `FwHud` | 顶栏的金币、生命、波次、建造和重开 | 结算伤害或改寻路 |

坐标只有一套：逻辑格是整数 `(x, y)`，世界坐标只通过 `TileMapLayer.map_to_local` / `local_to_map` 转换。`data/v2` 里的 `cell_size` 仍要满足旧配置校验（32 到 96），V2 不拿它做第二套换算。当前 TileSet 是 64×64 方格，邻格中心距 64 像素。

## 战斗规则

与阶段 1 相同，写在 `data/v2/prototype_match.json` 和对应的建筑、敌人、波次文件里：

- 开局金币 200，城堡生命 300。
- 城墙 10 金，弓箭塔 50 金。
- 三波敌人，击杀奖励 8。
- 敌人攻击城堡，或攻击挡住去路的可破坏建筑。
- 胜利和失败互斥。重新开始会清掉敌人、建筑，并恢复生命、金币和波次。

`data/v2/defeat_match.json` 把城堡生命设为 9，只用于自动验证失败接线，不是正式关卡。

## 群体移动

全局路径和局部间距分开。敌人是 `CharacterBody2D`，碰撞层只给弓箭塔的 `Area2D` 做范围检测，碰撞掩码为 0，所以不会互相顶死。间距看谁更靠近城堡：48 像素内减速，34 像素内停下。低于 22 像素算重叠失败。敌人不会被写进 `AStarGrid2D` 的固体格。

## 动画

哥布林、城堡、城墙、弓箭塔和箭都是单帧 PNG。`FwActorView` 记录 idle、walk、attack、hurt、death 全部缺失，不用同一张图复制出多帧。伤害由攻击间隔结算，不由动画帧结算。
