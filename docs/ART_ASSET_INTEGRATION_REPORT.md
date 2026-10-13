# 美术素材接入记录

记录日期：2026-10-13。  
引擎：Godot 4.7.2.stable.official.ed1daf0bf。  
可执行文件：`%LOCALAPPDATA%\Godot\4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`。

这次把两个素材包里检查过的图片接进阶段 1 防守场景。网格仍是 64×64 方格。造价、生命、伤害、波次和寻路没有改。

截图能看到的画面，和自动化测试通过，不是同一件事。下面分开写。

## 1. 素材包位置

两个包都在本机下载目录，不是压缩包。原始目录没有改、没有删。

| 包 | 路径 |
| --- | --- |
| A：Frontier Wardens — AI Art Asset Pack | `C:\Users\yanghuisong\Downloads\frontier_wardens_art_asset_pack` |
| B：《边境守望》AI 游戏美术资产包（第一批） | `C:\Users\yanghuisong\Downloads\Frontier_Wardens_AI_Art_Pack_v1` |

项目里的副本：

- 包 A 全部文件：`assets/source/art_pack_a/`
- 包 B 的三张参考海报：`assets/reference/`

## 2. 原始图片数量

包 A 有 43 张 PNG，外加 `README.md` 和 `asset_manifest.json`。其中 `source/generated_asset_atlas_reference.png` 是 1536×1024 的整张图集，不是独立游戏图。

包 B 有 3 张参考海报（RGB，没有可用的透明通道），以及提示词、`docs/ART_ASSET_PIPELINE.md` 和一份清单示例。没有已经切开的角色或建筑 PNG。

## 3. 已经接到游戏里的素材

这些图会被运行中的场景加载。窗口截图里实际出现的，见第 8 节。

| 游戏文件 | 画面 |
| --- | --- |
| `assets/sprites/buildings/castle.png` | 城堡。按 2×2 格的宽度缩放，底边对齐，生命仍是 300 |
| `assets/sprites/buildings/wooden_wall.png` | 城墙。源文件名是 `wooden_palisade.png`。造价仍是 10，占地仍是 1×1 |
| `assets/sprites/buildings/archer_tower.png` | 弓箭塔。造价仍是 50。图可以高出格子 |
| `assets/sprites/characters/enemies/goblin.png` | 劫掠者。静态单帧，仍走原来的移动和攻击 |
| `assets/sprites/projectiles/arrow_projectile.png` | 箭。绕贴图中心旋转，伤害和弹速不变 |
| `assets/sprites/effects/impact_spark.png` | 命中后约 0.16 秒的闪光。不改伤害，不额外给金币 |
| `assets/sprites/ui/icons/icon_gold.png` | 金币文字旁边的图标 |
| `assets/sprites/ui/icons/icon_health.png` | 城堡生命文字旁边的图标 |
| `assets/sprites/ui/icons/icon_shield.png` | 城墙按钮上的图标。按钮文字仍是「城墙（10 金）」 |

对应关系在 `assets/sprite_manifest.json`。

## 4. 复制进项目但没有用在关卡里的图

| 文件 | 原因 |
| --- | --- |
| `stone_wall.png`、`lookout_tower.png`、`farm.png`、`house.png`、`lumber_camp.png`、`workshop.png` | 抠图完整，但阶段 1 没有这些建筑 |
| `default_lord.png` | 只是一张静态领主。没有待机、行走、攻击帧，也没有接到临时领主场景 |
| `icon_wood.png`、`icon_stone.png`、`icon_food.png`、`icon_sword.png` | 图标可用，但当前界面没有木材、石材、食物或近战 |
| `grass_tile_01.png` 到 `grass_tile_04.png` | 斜俯视菱形，画布分别是 81×66、99×76、97×70、99×69，对不齐 64×64 方格，也没有验证过拼接 |
| `bush.png`、`rock_cluster.png` | 单株装饰。没有放进关卡，避免挡住出兵点、城堡和建造格 |

只留在 `assets/source/art_pack_a/`、没有放进 `assets/sprites/` 的，包括：

- 全透明：`dead_tree.png`、`deciduous_tree.png`、`dirt_tile.png`、`stone_tile.png`，以及包 A 的 `ui/icons/food.png`、`health.png`、`shield.png`、`sword.png`
- 裁切失败：道路四张只剩几个像素或文字残片；`pine_tree.png` 不是树；`arrow.png` 和 `large_arrow.png` 不是箭；`magic_bolt.png`、`explosion.png`、`green_death_effect.png` 几乎是空的
- `ui/icons/gold.png`、`wood.png`、`stone.png`、`quest.png` 是文字或标签残片
- `dust_cloud.png`、`fireball.png` 能看出形状，但当前弓箭塔不用火球，尘土也不作为死亡动画
- 整张图集和包 B 的三张海报

## 5. 处理过的 PNG

原下载目录没有改。处理结果是新文件：

- 哥布林、领主、箭、金币、生命、盾、木材、石材、食物、剑：从 `generated_asset_atlas_reference.png` 按连通区域裁出，去掉深色海报背景。图集里这些像素大多不是完全不透明，主体 alpha 被提升到 255，边缘半透明保留。
- `impact_spark.png`：去掉脱离主体的小碎块。
- `wooden_wall.png`：像素与 `wooden_palisade.png` 相同，只改了文件名。
- 城堡、弓箭塔和其他直接复制的建筑、草地、灌木、石堆：没有改像素。

## 6. 仍需要人工看的地方

- 建筑 PNG 来自自动抠图。洋红底上没有大块背景，但边缘仍可能有细的深色残留。
- 哥布林、箭和图标是从图集上拆下来的，暗色描边可能被背景判定吃掉一点。
- 木墙和弓箭塔是斜俯视，关卡是方格。墙被缩进 64 像素宽的一格里，看起来是一小段栅栏，不是沿格子连成的城墙线。
- 命中闪光没有出现在下面两张截图里，所以不能算已经目视确认。
- 没有人用鼠标打完一局。自动化胜利不能代替这个。

## 7. 改过的场景、脚本和配置

场景文件 `defense_match.tscn`、`enemy_unit.tscn`、`combat_building.tscn` 没有改节点。画面改在脚本里。

- `scripts/combat/castle_keep.gd`
- `scripts/combat/defense_match.gd`：`--shot` 会多存一张摆好素材的图
- `scripts/combat/defense_hud.gd`
- `scripts/combat/enemy_unit.gd`
- `scripts/combat/projectile.gd`
- `scripts/buildings/combat_building.gd`
- `scripts/content/building_definition.gd`：可选 `sprite`
- `scripts/content/enemy_definition.gd`：可选 `sprite`
- `data/buildings/wall.json`、`data/buildings/archer_tower.json`
- `data/enemies/raider.json`
- `tests/unit/stage1_checks.gd`：锁住造价、城堡生命、初始金币和图片路径；缺少图片必须报「资源不存在」
- `docs/DATA_SCHEMA.md`、`docs/ART_ASSET_PIPELINE.md`、`README.md`

没有 `sprite` 的旧建筑和测试夹具仍用色块。短关卡里的测试塔、测试墙就是这样。

## 8. 窗口截图

命令：

```text
Godot_v4.7.2-stable_win64_console.exe --path F:\xufeng\games -- --shot
```

退出码 0。OpenGL 3.3 Compatibility，NVIDIA GeForce GTX 1060 3GB。

| 文件 | 内容 |
| --- | --- |
| `user://stage1_preview.png`，副本 `docs/screenshots/stage1_preview.png` | 开局。金币 200，城堡 300/300，波次 0/3。能看到城堡、金币图标、生命图标、城墙按钮上的盾。没有墙、塔、敌人和箭 |
| `user://art_integration_preview.png`，副本 `docs/screenshots/art_integration_preview.png` | 脚本摆上去的：一格木墙、一座弓箭塔、一个停住的哥布林、一支不飞行的箭。金币是 140（200 减去 10 和 50）。因为场上有敌人，开始按钮变成「等待清场」 |

这张摆放图里的箭没有飞，也没有命中。它只说明箭的图片和朝向能画出来。

## 9. 回归测试

工作目录：`F:\xufeng\games`。

| 检查 | 结果 |
| --- | --- |
| 全局类登记 | `--headless --editor --quit`，退出码 0 |
| 脚本解析 | 26 个 `.gd` 分别 `--check-only`，`CHECK_DONE count=26 failed=0` |
| 阶段 0 | `--script res://tests/unit/stage0_checks.gd`，退出码 0，`STAGE0_PASS` |
| 阶段 1 | `--script res://tests/unit/stage1_checks.gd`，退出码 0，`STAGE1_PASS` |
| 无头启动 | `--headless --path . --quit-after 30`，退出码 0，`DEFENSE_READY base.defense_prototype gold=200 waves=3` |
| 窗口 | 上一节，退出码 0 |

`STAGE1_PASS` 里能看到：短关卡胜利和失败、封路后拆墙、重新开始后金币回到 200，以及正式关卡 `PROTOTYPE_RESULT outcome=victory frames=1477 城堡 300/300 alive=0 gold=154`。加载故意损坏的 JSON 时会打印 `DEFENSE_LOAD_FAIL`，这是原有的失败路径，测试最后仍是 `STAGE1_PASS`。

阶段 1 测试是在最后一次改建筑名称标签位置之后又跑过的。窗口截图也是这次标签位置下重新截的。

## 10. 还没有的素材

- 领主和敌人的待机、行走、攻击、受击、死亡动画
- 与 64×64 方格对齐、并且拼合过的草地、泥土和道路
- 可用的树
- 包 A 里失败的那些独立 PNG 没有合格替代，除了从图集重新裁出的箭、哥布林和图标
- 农场、住宅、伐木场、工坊、石墙、瞭望塔只有图片，没有玩法

## 已知限制

斜俯视图片叠在方格上，高塔会伸进上面的格子。敌人绘制顺序仍高于建筑，所以敌人会盖住塔身。这是画面问题，寻路和占地没有改。
