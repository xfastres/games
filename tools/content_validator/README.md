# 内容校验器

阶段 0 没有单独的命令行校验程序。

当前校验在游戏内完成：

- `scripts/content/building_definition.gd`
- `scripts/content/content_loader.gd`
- `tests/unit/stage0_checks.gd`

等格式稳定后，再决定是否做一个不启动游戏场景的独立校验入口。不要在这里放一份会和 GDScript 规则漂移的第二套实现。
