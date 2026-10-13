# 数据格式

阶段 0 只实现建筑定义的一个子集。领主、敌人、强化、遗物、波次和内容包元数据都还不能加载。下面如果没有写「阶段 0 已实现」，就只是后续格式的约束，不是当前接口。

JSON 用来给人和外部内容包编辑。游戏内先校验，再变成 `BuildingDefinition`。不要把未校验的字典直接交给放置或战斗逻辑。

## 通用规则

- 编码：UTF-8，无 BOM。
- 每个内容对象有全局唯一 id。阶段 0 只检查单份文件内部的 id 格式，还没有跨文件查重。
- id 形式：`命名空间.对象名`，至少两段。每段以小写字母开头，之后只能是小写字母、数字或下划线。示例：`base.test_watchpost`。
- `schema_version` 当前只接受整数 `1`。`true`、`1.5` 和 `2` 都是错误。
- 未知字段是错误，不能忽略。这样拼写错误不会静默失效。
- 资源路径只能是项目内的 `res://` 文件。拒绝绝对路径、`user://`、空目录段和 `..`。
- 引用的场景或图标必须存在。
- 失败时返回明确错误文本，并且不返回定义对象。

## 建筑定义（阶段 0 已实现）

必填：

| 字段 | 类型 | 规则 |
| --- | --- | --- |
| `id` | string | 见上面的 id 规则 |
| `schema_version` | int | 必须为 1 |
| `name` | string | 不能为空白 |
| `scene` | string | `res://` 下已存在的 `.tscn` |
| `footprint.width` | int | 大于 0 |
| `footprint.height` | int | 大于 0 |

可选：

| 字段 | 类型 | 规则 |
| --- | --- | --- |
| `description` | string | 可以是空字符串 |
| `icon` | string | 若出现，必须是已存在的 `res://` 文件 |

`footprint` 只允许 `width` 和 `height`。

阶段 0 的正式示例是 `data/buildings/test_watchpost.json`：

```json
{
  "id": "base.test_watchpost",
  "schema_version": 1,
  "name": "测试哨所",
  "description": "阶段 0 用于验证网格放置的占位建筑。",
  "scene": "res://scenes/buildings/placeholder_building.tscn",
  "footprint": {
    "width": 1,
    "height": 1
  }
}
```

价格、生命、射程、攻击间隔和行为类型先不放进这份格式。等经济和战斗需要时再加，并同时补校验和测试。不要提前把未实现的字段写进可用配置。

## 错误示例

| 输入 | 错误要点 |
| --- | --- |
| 缺少 `id` | `缺少字段：id` |
| `schema_version` 为 2 | `schema_version 必须为 1` |
| 占地宽为 0 | `宽高必须大于 0` |
| 根上有 `surprise` | `未知字段：surprise` |
| `scene` 指向不存在的文件 | `资源不存在` |
| 文件不是 JSON | `JSON 解析失败` |
| 路径包含 `..` 或不是 `res://` | `拒绝读取` |

对应夹具在 `tests/fixtures/`。

## 以后才会出现的格式

这些对象以后也要有唯一 id、`schema_version` 和内容包来源。阶段 0 的加载器遇到它们不会注册，因为对应目录和解析器都不存在。

- 领主：场景、生命、移动、攻击、主动技能、被动特性、标签
- 敌人：移动方式、攻击目标、是否能飞越或拆建筑
- 强化：效果组件 id 和数值，而不是一段可执行脚本
- 内容包 `mod.json`：包 id、版本、`game_api_version`、依赖和内容清单

`game_api_version` 是本游戏的模组接口版本，不是 Godot 版本。阶段 0 还没有读取它。
