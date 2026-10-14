# 数据格式

阶段 0 只实现建筑定义的一个子集。阶段 1 在同一份 `schema_version: 1` 上增加了可选的造价和行为，并新增了敌人、波次和防守关卡配置。领主、强化、遗物和内容包元数据都还不能加载。下面如果没有写「已实现」，就只是后续格式的约束，不是当前接口。

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

## 建筑定义（已实现）

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
| `sprite` | string | 若出现，必须是已存在的 `res://` `.png`。只决定画面，不改变占地、造价或行为 |
| `cost` | int | 若出现，不能为负。有 `behavior` 时必须大于 0 |
| `behavior` | object | 若出现，必须是下面两种行为之一 |

`footprint` 只允许 `width` 和 `height`。

没有 `behavior` 的建筑仍然合法。`data/buildings/test_watchpost.json` 就是这种，它只参与阶段 0 的放置验证。

`behavior.type` 目前只允许：

| type | 必填字段 | 行为 |
| --- | --- | --- |
| `blocker` | `max_health`（大于 0 的整数） | 占据格子，可被攻击，挡住敌人 |
| `ranged` | `max_health`、`range`、`attack_interval`、`damage`、`projectile_speed` | 同上，并自动射击射程内的敌人 |

`range`、`attack_interval`、`projectile_speed` 是大于 0 的数字。`damage` 是大于 0 的整数。未知的 `type` 或行为里的未知字段都是错误。远程建筑也会占格挡路，这是行为规则，不是按建筑名字判断。

阶段 1 的正式建筑是 `data/buildings/wall.json`（`blocker`）和 `data/buildings/archer_tower.json`（`ranged`）。两者使用同一个场景 `scenes/buildings/combat_building.tscn`。

阶段 0 的正式示例仍然是 `data/buildings/test_watchpost.json`：

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

价格、生命、射程和攻击间隔已经放进可选的 `cost` 与 `behavior`。没有这些字段的旧建筑配置仍然有效。

## 敌人定义（阶段 1 已实现）

必填，且不允许未知字段：`id`、`schema_version`、`name`、`scene`、`max_health`、`move_speed`、`contact_damage`、`attack_interval`、`gold_reward`。

可选：`sprite`。若出现，必须是已存在的 `res://` `.png`。它只替换敌人的占位图形，不改变生命、移速、伤害或击杀奖励。没有这个字段时仍用场景里的占位绘制。

`max_health` 和 `contact_damage` 必须大于 0。`move_speed` 和 `attack_interval` 必须大于 0。`gold_reward` 不能为负。示例：`data/enemies/raider.json`。

## 波次（阶段 1 已实现）

必填：`id`、`schema_version`、`waves`。每一波必填 `enemy_id`、`count`、`spawn_interval`。`count` 为 1 到 30。整个列表最多 10 波。超出范围会报错，不会静默截断。示例：`data/combat/prototype_waves.json`。

## 防守关卡（阶段 1 已实现）

`data/combat/prototype_match.json` 引用建筑、敌人和波次文件。必填字段包括地图列行、`cell_size`、`starting_gold`、城堡矩形和生命、出兵点、建筑路径、敌人路径、波次路径。

加载时会检查：城堡和出兵点在地图内且不重叠，建筑 id 不重复，建筑带有已支持的行为且造价大于 0，场景含对应的 `setup_combat` 或 `setup`，波次里的敌人都已加载。重复 id、未知敌人和缺少场景方法都会失败，并且不返回关卡对象。

地面贴图不在这份 JSON 里。道路、草地和泥土只影响 `TileMapLayer` 的画面。能否通行仍由城堡和建筑占地决定，换一种地形图不会改变寻路。

## 错误示例

| 输入 | 错误要点 |
| --- | --- |
| 缺少 `id` | `缺少字段：id` |
| `schema_version` 为 2 | `schema_version 必须为 1` |
| 占地宽为 0 | `宽高必须大于 0` |
| 根上有 `surprise` | `未知字段：surprise` |
| `behavior.type` 为 `flyer` | `未知行为类型：flyer` |
| 波次引用了没有加载的敌人 | `未加载的敌人` |
| `scene` 指向不存在的文件 | `资源不存在` |
| 文件不是 JSON | `JSON 解析失败` |
| 路径包含 `..` 或不是 `res://` | `拒绝读取` |

对应夹具在 `tests/fixtures/`。

## 以后才会出现的格式

这些对象以后也要有唯一 id、`schema_version` 和内容包来源。除了阶段 1 已经加载的敌人和波次字段，下面这些还没有解析器。

- 领主：场景、生命、移动、攻击、主动技能、被动特性、标签
- 敌人：移动方式、攻击目标、是否能飞越或拆建筑。阶段 1 只加载了上面的敌人字段，没有飞行或特殊拆塔规则。
- 强化：效果组件 id 和数值，而不是一段可执行脚本
- 内容包 `mod.json`：包 id、版本、`game_api_version`、依赖和内容清单

`game_api_version` 是本游戏的模组接口版本，不是 Godot 版本。阶段 0 还没有读取它。
