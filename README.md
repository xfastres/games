# 边境守望（Frontier Wardens）

Godot 4 + GDScript 的单人 PC 游戏。白天建设和探索，夜晚防守。当前仓库只完成了阶段 0：项目骨架和一个技术验证场景。

设计、架构和阶段边界在 `docs/`。给 AI 助手的开发约束在 `AGENTS.md`。

## 运行

1. 安装 [Godot 4.7.x 标准版](https://godotengine.org/download/windows/)（GDScript，不是 .NET 版）。
2. 用 Godot 打开本目录的 `project.godot`。
3. 运行主场景 `scenes/main/tech_demo.tscn`。

操作：

- WASD 或方向键移动蓝色临时领主。
- 在绿色网格内单击，放置配置里的「测试哨所」。
- 再单击同一格，或单击网格外面，会看到错误。
- 画面上方会显示一份故意写坏的配置为什么被拒绝。

## 阶段 0 检查

在项目根目录执行，把 `godot` 换成实际的 Godot 4.7 可执行文件：

```text
godot --headless --path . --check-only --script res://tests/unit/stage0_checks.gd --quit
godot --headless --path . --script res://tests/unit/stage0_checks.gd
godot --path . --quit-after 90
godot --path . -- --shot
```

第一条只做脚本解析。第二条运行断言，退出码 0 且输出 `STAGE0_PASS` 才算自动化测试通过。第三条启动主场景。第四条会先放下一座测试建筑，再把画面存到 Godot 的 `user://stage0_preview.png`，然后退出。

## 现在还没有的东西

战斗、资源经济、探索、肉鸽、存档、主菜单和模组扫描都还没做。`mods/` 里的文件不会被加载。
