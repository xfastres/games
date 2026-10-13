# 边境守望（Frontier Wardens）

Godot 4 + GDScript 的单人 PC 游戏。当前可玩内容是阶段 1 的防守原型。技术验证场景还在，但已经不是主场景。

设计、架构和阶段边界在 `docs/`。给 AI 助手的开发约束在 `AGENTS.md`。

## 运行防守原型

1. 安装 [Godot 4.7.x 标准版](https://godotengine.org/download/windows/)（GDScript，不是 .NET 版）。
2. 用 Godot 打开本目录的 `project.godot`。
3. 运行主场景 `scenes/combat/defense_match.tscn`。直接按运行也会进这个场景。

操作：

- 点击「城墙」或「弓箭塔」，再在网格里用左键放置。右键取消选择。
- 城堡和深红色出兵点不能建造。金币不够、格子被占或点到网格外，会在上方显示原因。
- 准备好后点击「开始波次」。敌人从出兵点走向城堡；路被城墙堵住时会攻击城墙。
- 弓箭塔会自动射击射程内的敌人。击杀获得金币。
- 三波都清空后胜利。城堡生命降到 0 时失败。两种结果都可以「重新开始」。

地图仍是 64×64 的方形网格。城堡、木墙、弓箭塔、劫掠者和箭矢使用 `assets/sprites/` 里的图片，占地和战斗数值不跟图片尺寸走。金币和城堡生命旁边有图标，按钮文字仍由界面控件绘制。素材来源和未使用文件见 `docs/ART_ASSET_INTEGRATION_REPORT.md`。

阶段 0 的技术验证场景仍然可以单独打开：`scenes/main/tech_demo.tscn`。那里还是绿色网格、临时领主和测试哨所。

## 阶段 0 检查

在项目根目录执行，把 `godot` 换成实际的 Godot 4.7 可执行文件：

```text
godot --headless --path . --check-only --script res://tests/unit/stage0_checks.gd --quit
godot --headless --path . --script res://tests/unit/stage0_checks.gd
godot --path . res://scenes/main/tech_demo.tscn --quit-after 90
godot --path . res://scenes/main/tech_demo.tscn -- --shot
```

第一条只做脚本解析。第二条运行断言，退出码 0 且输出 `STAGE0_PASS` 才算自动化测试通过。后两条要显式打开技术验证场景，因为项目主场景已经是防守原型。第四条会先放下一座测试建筑，再把画面存到 `user://stage0_preview.png`，然后退出。

## 阶段 1 检查

在项目根目录执行，把 `godot` 换成实际的 Godot 4.7 可执行文件：

```text
godot --headless --path . --script res://tests/unit/stage1_checks.gd
godot --headless --path . --quit-after 30
godot --path . -- --shot
```

第一条退出码 0 且输出 `STAGE1_PASS`，才算阶段 1 自动化通过。第二条应打印 `DEFENSE_READY`。第三条会打开窗口，先把开局画面存到 `user://stage1_preview.png`，再放下一座城墙、一座弓箭塔、一个停住的敌人和一支不飞行的箭，并存到 `user://art_integration_preview.png`，然后退出。第二张图是为了看到素材，金币会变成 140，开始按钮会显示「等待清场」。项目里的副本在 `docs/screenshots/`。

阶段 0 的检查命令仍然有效，见上一节。主场景已经不再是技术验证场景，所以不带场景路径的 `--shot` 现在截的是防守原型。

## 现在还没有的东西

探索、农业、昼夜、肉鸽、存档、主菜单和模组扫描都还没做。金币目前只用于这一次防守的建造和击杀奖励。`mods/` 里的文件不会被加载。
