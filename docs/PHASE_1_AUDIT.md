# 阶段 1 独立验收审计

审计日期：2026-10-13。  
审计对象：`F:\xufeng\games` 的工作区，不是 `docs/PHASE_1_ACCEPTANCE.md` 里的完成声明。  
审计范围：阶段 1 战斗原型是否真的能打完一次防守。本次没有修改游戏脚本、场景、配置、测试或原有文档，也没有创建提交。

状态用词：

| 状态 | 含义 |
| --- | --- |
| 已验证 | 本次审计有命令输出、退出码，或探针里观察到的状态变化 |
| 已实现但未验证 | 有代码，本次没有运行到那条路径，或没有量到声称的数值 |
| 未实现 | 没有这条行为 |
| 存在问题 | 已发现错误、缺陷，或测试声称覆盖了但断言并没有钉住 |

`docs/PHASE_1_ACCEPTANCE.md` 和 `docs/DEVELOPMENT_PLAN.md` 里的运行记录只当作待核对的说法。下面的命令都是本次重新执行的。探针脚本放在本机临时目录，没有进入仓库。

## 1. 审计结论

**通过。**

本次用 Godot 4.7.2 实际跑完了正式关卡的三波防守：结果是胜利，城堡保持 300/300，金币为 154。同一布局在重新开始后再跑一遍，结果相同。完全不建造时，城堡按每次 9 点被打到 0，进入失败，之后金币和生命不再变化。这些是物理帧里的状态变化，不是验收文档的摘录，也不是只看了开局截图。

没有发现 P0 或 P1。没有必须先改才能打完这一局的缺陷。

通过范围不包括操作系统鼠标。测试和探针调用的是放置函数、按钮信号或 `_unhandled_input()`，没有向窗口发送系统光标事件。这一项记在第 12 节，不把它算成已经亲手点过。

可以进入阶段 2。依据见第 13 节。

## 2. 当前版本和 Git 工作区状态

| 项 | 实际结果 |
| --- | --- |
| 项目根目录 | `F:\xufeng\games` |
| 引擎 | Godot 4.7.2.stable.official.ed1daf0bf。可执行文件在本机 `%LOCALAPPDATA%\Godot\4.7.2-stable\`，不在仓库内 |
| 工作区版本 | `project.godot` 中 `config/version="0.2.0"`，`run/main_scene="res://scenes/combat/defense_match.tscn"` |
| 已提交版本 | HEAD 里仍是 `config/version="0.1.0"`，主场景仍是 `res://scenes/main/tech_demo.tscn` |
| 分支 | `main` |
| HEAD | `4991a72`，说明「记录阶段 0 审计结果，并修正开发计划里已过时的仓库说明。」，时间 2026-10-13 17:44:31 +0800。其上一次是 `e2e1eb5`，说明 `first commit`。本报告不摘录作者邮箱 |
| 工作区 | 不干净。阶段 1 的脚本、场景、配置和文档修改都还没有提交。本次审计开始前就是这样，审计过程没有改这些文件 |
| 渲染 | 窗口运行日志为 OpenGL 3.3 Compatibility，设备 NVIDIA GeForce GTX 1060 3GB |
| 敏感配置 | 抽查源码、JSON、`project.godot` 和本次日志，未发现密钥、口令或访问令牌 |

阶段 1 相对 HEAD 的已跟踪修改：`CHANGELOG.md`、`README.md`、`docs/ARCHITECTURE.md`、`docs/DATA_SCHEMA.md`、`docs/DEVELOPMENT_PLAN.md`、`docs/GDD.md`、`project.godot`、`scripts/content/building_definition.gd`、`scripts/content/content_loader.gd`、`scripts/world/placement_grid.gd`。其余战斗文件目前是未跟踪文件。写入本报告后会再增加 `docs/PHASE_1_AUDIT.md`。

## 3. 实际文件清单

阶段 0 的技术验证场景、占位建筑、临时领主和 `stage0_checks.gd` 都还在。下面是阶段 1 新增或实质修改、并且和本次验收有关的文件。

| 路径 | 实际作用 |
| --- | --- |
| `project.godot` | 主场景改为防守原型，版本号改为 0.2.0。没有输入映射段 |
| `scenes/combat/defense_match.tscn` | 当前主场景。根节点脚本是 `scripts/combat/defense_match.gd` |
| `scenes/combat/enemy_unit.tscn` | 敌人场景，脚本 `scripts/combat/enemy_unit.gd` |
| `scenes/buildings/combat_building.tscn` | 城墙和弓箭塔共用的场景，脚本 `scripts/buildings/combat_building.gd` |
| `scenes/main/tech_demo.tscn` | 阶段 0 技术验证场景，不再是主场景 |
| `scripts/combat/defense_match.gd` | 读关卡、放置、出兵、胜负、输入和绘制。约 680 行，是编排者 |
| `scripts/combat/defense_hud.gd` | 金币、城堡、波次、建造按钮、开始波次、重新开始和胜负界面 |
| `scripts/combat/wave_spawner.gd` | 按波次数量和间隔出兵 |
| `scripts/combat/grid_route.gd` | 四方向寻路。有路就绕，没路就攻击第一格阻挡 |
| `scripts/combat/enemy_unit.gd` | 移动、攻击城堡或阻挡、死亡和奖励 |
| `scripts/combat/ranged_weapon.gd` | 按间隔选择射程内最近的敌人 |
| `scripts/combat/projectile.gd` | 飞向目标并调用 `apply_damage` |
| `scripts/combat/blocker.gd` | 建筑生命。归零后通知棋盘拆掉占格 |
| `scripts/combat/castle_keep.gd` | 城堡绘制和生命 |
| `scripts/combat/health_pool.gd` | 通用扣血 |
| `scripts/economy/gold_wallet.gd` | 金币花费和奖励 |
| `scripts/buildings/combat_building.gd` | 按行为类型挂上阻挡，远程再挂武器 |
| `scripts/content/building_definition.gd` | 建筑校验。新增可选 `cost` 和 `behavior` |
| `scripts/content/enemy_definition.gd` | 敌人校验 |
| `scripts/content/wave_set.gd` | 波次校验。最多 10 波，每波最多 30 个 |
| `scripts/content/defense_match_config.gd` | 关卡校验，并加载建筑、敌人和波次 |
| `scripts/content/content_loader.gd` | 按调用方传入的路径读取 JSON。仍然不是目录扫描，也不是模组扫描 |
| `scripts/content/content_fields.gd` | 字段类型和 id 的共用检查 |
| `scripts/world/placement_grid.gd` | 阶段 0 的占地检查，新增 `reserve` / `release` |
| `data/combat/prototype_match.json` | 16×8、200 金、城堡 300、两处出兵点 |
| `data/combat/prototype_waves.json` | 三波，数量 4、6、8，敌人都是 `base.raider` |
| `data/buildings/wall.json` | `base.wall`，造价 10，行为 `blocker`，生命 100 |
| `data/buildings/archer_tower.json` | `base.archer_tower`，造价 50，行为 `ranged`，伤害 18，间隔 0.4 秒，射程 240，弹速 700 |
| `data/enemies/raider.json` | 生命 30，移速 70，接触伤害 9，攻击间隔 0.75 秒，赏金 8 |
| `tests/unit/stage1_checks.gd` | 阶段 1 自动化 |
| `tests/fixtures/defense/` | 短关卡、失败、破墙和故意写坏的关卡 |
| `tests/fixtures/invalid_building_unknown_behavior.json` | 未知行为 `flyer` |

场景引用是真实文件：三个战斗相关 `.tscn` 的脚本路径都能对上现存 `.gd`。城墙和弓箭塔的 JSON 都指向 `res://scenes/buildings/combat_building.tscn`。敌人指向 `res://scenes/combat/enemy_unit.tscn`。运行中这些场景被实例化过，不是只写在配置里。

没有发现只有 `pass`、空函数或未实现注释来冒充战斗的脚本。寻路、扣血、出兵、投射物和钱包都有实际状态变化，并且本次跑到了。

主场景没有把全部规则塞进一个脚本。生命、钱包、寻路、出兵、投射物、阻挡和界面各自有文件。`defense_match.gd` 仍然负责把它们接起来，并直接处理输入、胜负和放置。以阶段 1 的体量，这是编排，不是阶段 0 那种单脚本技术验证，也还没有拆成更细的应用服务。

## 4. 阶段 1 验收矩阵

| 验收项 | 状态 | 证据 |
| --- | --- | --- |
| 阶段 0 的配置校验和网格放置仍然有效 | 已验证 | `stage0_checks.gd` 退出码 0，输出 `STAGE0_PASS`。日志里能辨认 `base.test_watchpost`、格子 `(2, 1)`。测试断言要求占用和网格外错误，失败会变成 `STAGE0_FAIL` |
| 城墙、弓箭塔通过建筑定义创建 | 已验证 | 探针放下 `base.wall`：金币 200 变为 190，子节点含 `blocker.gd`，没有远程武器，阻挡生命 100。弓箭塔金币变为 150。原型胜利的金币与 3 座塔、4 段墙的造价一致 |
| 核心逻辑不按建筑名字分支 | 已验证 | 战斗脚本里没有 `base.wall` 或「城墙」的条件分支。分支在 `behavior.type` 的 `blocker` / `ranged`。界面帮助文字写了这两种建筑的名字，见 P3 |
| 能选择并放置城墙 | 已验证（程序调用） | `select_building_id("base.wall")` 后 `place_at_cell` 成功。重启测试和原型测试也会放墙。不是操作系统点击 |
| 能选择并放置弓箭塔 | 已验证（程序调用，另有注入的鼠标事件） | 正式塔用 `place_at_cell`。短关卡测试把鼠标事件直接送进 `_unhandled_input()`，放下一座测试塔 |
| 放置成功后才扣钱，失败不扣钱、不留节点 | 已验证 | 见第 5 节 |
| 封路有明确处理 | 已验证 | 不拒绝封路。敌人攻击阻挡。破墙测试包含在 `STAGE1_PASS` 里；失败会打印 `FAIL:` 并以退出码 1 结束 |
| 三波敌人能打完并胜利 | 已验证 | 日志有 `DEFENSE_WAVE 1`、`2`、`3`，然后 `DEFENSE_VICTORY`。`PROTOTYPE_RESULT outcome=victory frames=1477 城堡 300/300 alive=0 gold=154` |
| 不建造会失败，并且伤害数值正确 | 已验证 | 探针：第 1543 帧 `outcome=defeat`，城堡 0/300，金币仍为 200。前 8 次掉血都是 9 点 |
| 失败或胜利后不再继续结算 | 已验证（本次运行的窗口） | 失败后再跑 180 帧和 120 帧，金币和城堡生命不变，补刀与放置返回「战斗已经结束」 |
| 重新开始后能再打完一局 | 已验证 | 出兵后重启：敌人从 1 变为 0，建筑清空，金币 200，城堡 300/300，波次 0/3。同一布局再次 `outcome=victory frames=1477 城堡 300/300 alive=0 gold=154` |
| 操作系统鼠标或键盘 | 未自动验证 | 见第 12 节 |
| 弓箭塔 0.4 秒的攻击间隔 | 已实现但未验证 | 代码在开火后把冷却设为 `attack_interval`。本次只量到第一发命中，没有记录第二发的帧号 |

## 5. 建造系统审计

放置入口在 `defense_match.gd` 的 `place_at_world_position()`。顺序是：战斗已结束或未选建筑则拒绝；金币不够则拒绝；坐标出界则拒绝；格子上有敌人则拒绝；`PlacementGrid.try_place()` 失败则拒绝；场景实例化或 `setup_combat()` 失败则回滚占用；最后才 `wallet.try_spend()`，成功后才 `add_child()`。

因此扣钱发生在实例已经建立之后。若扣钱失败，会释放节点并 `release()` 占用。网格拒绝发生在实例化之前，不会留下节点。

| 项 | 状态 | 证据 |
| --- | --- | --- |
| 1. 选择城墙后放到有效格子 | 已验证（程序调用） | 探针：`AUDIT_WALL select='' ok=true gold=200->190 buildings=1 id=base.wall weapon=false blocker_hp=100 children=Node:blocker.gd,Label:no_script`。造价 10 与 `wall.json` 一致。正式测试的重启和原型布防也成功放下 `base.wall` |
| 2. 选择弓箭塔后放到有效格子 | 已验证 | 探针：`AUDIT_TOWER ok=true gold=150`，即 200 减去造价 50。`stage1_checks.gd` 的 `_test_mouse_and_gold()` 对短关卡塔注入左键事件，断言金币从 40 变为 30，且只有 1 个战斗建筑，其 id 来自配置 |
| 3. 成功后才扣钱 | 已验证 | 上面两次成功扣款与配置造价一致。代码在 `add_child()` 之前调用 `try_spend()`，失败分支会回滚 |
| 4. 金币不足时失败且金币不变 | 已验证 | 短关卡测试把 4 座造价 10 的塔放完，第五座返回「金币不足」，金币保持 0，建筑数保持 4。探针在余额 40 时放造价 50 的塔：`AUDIT_POOR ok=false gold=40->40 nodes=1->1` |
| 5. 重复占用和地图外失败 | 已验证 | 探针：`AUDIT_REJECT overlap_ok=false outside_ok=false gold=190 occupied=7->7 nodes=1->1`。短关卡测试断言占用错误含「已被占用」、地图外错误含「不在地图网格内」，并且失败后金币仍是 30 |
| 6. 失败后没有残留节点或错误占用 | 已验证 | 见上两行的节点数和占用数。占用 7 等于城堡 4 格、两个出兵点、再加这一段墙 |
| 7. 阻断通路 | 已验证，采用攻击而不是拒绝 | `place_at_world_position()` 不检查封路。`grid_route.gd` 在有路时绕行，没有路时返回 `attack_blocker`。`_test_routes()` 断言绕墙走到城堡，以及贴墙时攻击墙。`_test_breach()` 在单行地图放墙，断言敌人不站进仍存活的墙格、墙被拆掉、敌人继续前进。整套测试 `STAGE1_PASS`、退出码 0 |

「格子上有敌人」这个拒绝分支有代码，本次没有单独摆一个敌人再去放建筑，记为已实现但未验证。

阶段 0 的放置测试仍然通过：2×2 越界不占格、合法放置占用 4 格、重叠不改变占用、0 尺寸地图被拒绝。技术验证场景仍加载「测试哨所」，并拒绝缺少 id 的样本。

## 6. 战斗系统审计

调用路径是实际跑过的，不是只看了函数名。

1. `start_next_wave()` 调用 `WaveSpawner.start_next()`，把波次标为出兵中。
2. `DefenseMatch._physics_process()` 调用 `poll()`。生成成功后才 `commit_spawn()`。格子被占时不确认出兵，因此不会因为生成失败就把这只敌人算成已经清掉。
3. 敌人 `setup()` 后进入 `defense_enemy` 组，占当前格。
4. 每物理帧 `query_action()` 走 `GridRoute.choose()`。移动要先 `try_begin_step()`，走进阻挡格会被取消。
5. 贴城堡时 `apply_castle_damage(contact_damage)`。贴墙时对建筑 `apply_damage(contact_damage)`。
6. 远程武器按距离选最近的存活敌人，生成 `Projectile`。投射物距离目标不超过 8 像素时调用 `apply_damage(damage)`。
7. 敌人生命到 0 时 `_die()`：`alive=false`，移出 `defense_enemy`，`notify_enemy_died()` 清占格、减计数、加一次赏金，然后 `queue_free()`。

| 项 | 状态 | 证据 |
| --- | --- | --- |
| 1. 开始波次后实际生成敌人 | 已验证 | 正式测试打印 `DEFENSE_WAVE 1` 到 `3`。探针 `AUDIT_SPAWN frame=1 hp=30 cell=(15, 2) gold=150`。波次门闩探针 `saw=true alive=1` |
| 2. 敌人沿路线接近城堡 | 已验证 | 不建造的正式关卡从第 778 帧开始掉城堡血，说明敌人从右侧出兵点走到了城堡旁。失败测试同样在不放塔时把城堡打到 0。寻路单测覆盖了开阔步、贴城堡攻击、绕两格墙 |
| 3. 城墙阻挡或改变路线 | 已验证 | 破墙测试在 `STAGE1_PASS` 中通过，断言见第 5 节第 7 项。原型布局把 `(4,2)` 到 `(4,5)` 封上后仍能清完全部敌人，且城堡未掉血 |
| 4. 弓箭塔找到目标 | 已验证 | 一座塔放在 `(12, 2)`，出兵点 `(15, 2)` 在射程 240 内。敌人生命从 30 变为 12 |
| 5. 攻击间隔有效 | 已实现但未验证 | `ranged_weapon.gd` 在发射后执行 `_cooldown = attack_interval`，冷却大于 0 时不发射。配置是 0.4 秒。本次只记录到第 16 帧的第一发命中，击杀发生在第 30 帧之后，没有第二发的帧号，不能算出 0.4 秒 |
| 6. 投射物命中 | 已验证 | 第一发用了约 15 个物理帧。出兵点到塔约 192 像素，弹速 700，飞行时间约 0.27 秒，和默认 60 物理帧/秒下的 16 帧相符。命中后生命下降，不是瞬间结算 |
| 7. 命中后生命变化正确 | 已验证 | `AUDIT_HP frame=16 30->12`。弓箭塔伤害是 18，30 减 18 等于 12。击杀后金币增加 8，与 `gold_reward` 一致，对应第二次命中把剩余 12 点打到 0 |
| 8. 死亡后不再参与战斗 | 已验证 | 敌人是 `Node2D`，没有物理碰撞体。占格和分组才是「还在场上」的依据。第一只敌人清空时 `group=0`、`alive_count=0`。之后 90 帧金币保持 158，没有对这只已死敌人再发赏金。新的 `alive_enemies=2` 来自同一波还在出的后续敌人 |
| 9. 死亡奖励只发一次 | 已验证 | 短关卡断言金币为 39，即 40 减 10 再加 9。正式关卡两次跑到 154：200 减 3×50 减 4×10，再加 18×8。多发一次赏金就会变成 162 或更高。城堡保持 300/300，说明这 18 只是被击杀而不是漏到城堡 |
| 10. 到达城堡后造成正确伤害 | 已验证 | 不建造探针的掉血样本：`300->291`、`291->282`、`282->273`、`273->264`、`264->255`、`255->246`、`246->237`、`237->228`。每次 9 点，等于 `contact_damage`。相邻两次间隔 45 个物理帧，按默认 60 帧/秒是 0.75 秒，等于敌人的 `attack_interval`。中间夹着 9 帧的另一组掉血，符合第二个敌人在错开的节拍上攻击。共 34 次掉血后城堡为 0。`project.godot` 没有改物理帧率 |

失败测试本身只断言城堡最终为 0。那一关的接触伤害是 50，城堡只有 30，一击就致死，看不出每次扣多少。每次 9 点的证据来自本次探针，不是来自 `stage1_checks.gd` 的断言。

敌人攻击间隔因此是已验证的。弓箭塔的 0.4 秒间隔仍然没有量到。

## 7. 波次与胜负审计

胜利只在 `_check_victory()` 里设置。条件是还没有结局、`WaveSpawner.all_waves_committed()` 为真，且 `alive_enemies == 0`。`all_waves_committed()` 要求没有剩余波次，并且当前波次已经不在出兵。敌人离开画面不会减计数。地图上的敌人只有死亡通知会减计数。生成失败不会确认出兵，也就不会提前把波次算完。

下一波要同时满足：没有结局、出兵器空闲、还有剩余波次、场上存活数为 0。测试在循环里也是先看 `can_start_wave()` 再调用 `start_next_wave()`。

| 项 | 状态 | 证据 |
| --- | --- | --- |
| 1. 至少三波能开始并完成 | 已验证 | 正式关卡配置就是 4、6、8 共 18 只。日志依次出现 `DEFENSE_WAVE 1`、`DEFENSE_WAVE 2`、`DEFENSE_WAVE 3`、`DEFENSE_VICTORY`。结束时 `alive=0` |
| 2. 波次之间的状态切换 | 已验证 | 若第一波刚开始就胜利，`can_start_wave()` 会因为结局或存活数而拒绝后面的波次，日志里不会出现第 2、3 波。探针在第一波仍有敌人时再次开始：`AUDIT_WAVE_GATE first=true saw=true alive=1 busy=true early_ok=false`，错误文本是不能开始波次 |
| 3. 不能因为刚生成或离开画面就胜利 | 已验证 | 胜利条件要求全部波次已提交且存活数为 0。不建造的一局里敌人一直活着，直到城堡被打掉才是失败，不是胜利。短关卡胜利时金币必须是 39；若在击杀前就胜利，这项断言会失败 |
| 4. 全部波次完成且场上清空才胜利 | 已验证 | 同上。两次原型胜利都在三波日志之后，并且 `alive=0` |
| 5. 城堡生命归零后失败 | 已验证 | 短失败关卡打印 `DEFENSE_DEFEAT`，测试断言 `outcome=defeat`、城堡为 0、不是胜利、失败界面含「防守失败」和「重新开始」。不建造的正式关卡同样在 0/300 时失败 |
| 6. 结束后不再造成伤害或重复发奖 | 已验证 | 不建造失败后 180 帧：`AUDIT_POST gold=200->200 castle=0->0 outcome=defeat->defeat late_hit='战斗已经结束' late_place='战斗已经结束'`。另一场有塔的失败后 120 帧：金币停在 166，城堡保持 0，投射物数量为 0。166 等于 200 减一座塔的 50，再加两次击杀的 16，没有失败后再加 |
| 7. 胜利和失败不会互相覆盖 | 已验证 | 失败测试断言结局不是胜利。胜利原型的城堡保持满血，没有同时出现 `DEFENSE_DEFEAT` |

`notify_enemy_died()` 在加金币之前不看 `outcome`。冻结会关掉敌人战斗并 `queue_free()` 投射物。本次两场失败之后的帧里没有再看到赏金。这个缺口没有被跑成故障，记在 P3，不把它写成已经发生的重复发奖。

## 8. 重新开始与状态清理审计

`restart()` 要求当前节点有 `scene_file_path`，然后 `reload_current_scene()`。直接 `DefenseMatch.new()` 出来的短关卡没有场景路径，按钮重载不回夹具。这是代码里的明确失败，不是静默成功。正式主场景有路径。

| 项 | 状态 | 证据 |
| --- | --- | --- |
| 7. 清空旧敌人、旧建筑，并重置金币、生命、波次和状态 | 已验证 | 仓库测试在放下一座墙后重启，断言新场景金币回到开局、`combat_building` 组为空、城堡满血。它没有先出兵。探针先出兵再重启：`AUDIT_RESTART_SETUP enemies=1 gold=150`，随后 `AUDIT_RESTART_CLEAR enemies=0 buildings=0 gold=200 castle=城堡 300/300 wave=波次 0/3` |
| 8. 重新开始后能再完整游玩 | 已验证 | 重启后的新场景再次放下 3 座弓箭塔和 4 段墙，打完三波：`AUDIT_REPLAY outcome=victory frames=1477 城堡 300/300 alive=0 gold=154` |

仓库里的 `_test_restart()` 没有覆盖「场上已有敌人」和「重启后再打完」。这两项的证据是本次探针，不是 `stage1_checks.gd` 的断言。

## 9. 自动化测试质量审计

自动化测试只有两个文件，没有 GdUnit 或其他测试框架。

| 文件 | 跑的是什么 | 本次结果 |
| --- | --- | --- |
| `tests/unit/stage0_checks.gd` | 无头 `SceneTree`。检查路径、建筑 JSON、放置网格，并实例化技术验证场景，用 `scripted_direction` 推动临时领主 | 退出码 0，`STAGE0_PASS` |
| `tests/unit/stage1_checks.gd` | 无头 `SceneTree`。前半是解析和纯数据；后半会把 `DefenseMatch` 加进树，并 `await physics_frame` | 退出码 0，`STAGE1_PASS` |

`stage1_checks.gd` 各段实际断言：

| 函数 | 实际覆盖 | 没有覆盖 |
| --- | --- | --- |
| `_test_content` | 测试哨所仍然没有行为和造价；城墙是 `blocker`，塔是 `ranged`，二者共用场景；未知行为、负造价、有行为却没有造价、缺少弹速、未知字段、重复 id、缺失敌人、缺少 `setup_combat`、城堡宽度 0、接触伤害 0 都会失败且不返回定义 | 不运行战斗 |
| `_test_wallet_health_and_grid` | 余额不足不变、花费、负奖励被拒绝、伤害从 15 到 10 再到 0、第二次攻击被拒绝、预留格不能放置、释放后可以放置 | 不生成敌人 |
| `_test_routes` | 一步移动、贴城堡攻击、地图外失败、接近墙、攻击墙、绕开两格墙走到城堡且不踏进墙 | 不移动真实敌人节点 |
| `_test_bad_scene` | 损坏 JSON 不会把防守标为就绪，并出现含 JSON 的致命文本 | 只测这一份坏文件 |
| `_test_mouse_and_gold` | 直接 `emit` 建造按钮；把鼠标事件送进 `_unhandled_input()`；右键清空选择后不再放置；地图外和占用失败不继续扣钱；四座塔花光 40 金，第五座不产生节点 | 不是操作系统输入。没有点正式关卡的「城墙」按钮 |
| `_test_victory_shot` | 短关卡一座塔，最多 240 物理帧。断言胜利、城堡生命与开打前相同、金币正好 39、界面标题是「防守成功」 | 伤害是 100、敌人生命 20，一击致死，看不出扣血余数，也看不出 0.4 秒间隔 |
| `_test_defeat` | 不放建筑。断言失败、城堡为 0、不是胜利、有失败标题和重新开始按钮 | 不断言每次扣多少。不继续跑失败后的帧 |
| `_test_breach` | 单行地图一堵墙。断言活墙格上没有敌人、墙消失、敌人走到墙的另一侧 | 不打印墙的生命变化。通过与否体现在整套测试是否 `STAGE1_PASS` |
| `_test_restart` | 从正式场景实例重启。断言新场景、金币回到开局、建筑组为空、城堡满血 | 重启前没有敌人，也没有再打一局 |
| `_test_prototype_defense` | 指定 3 塔 4 墙，有空位就开下一波，最多 5000 帧。断言结局是胜利且城堡生命大于 0。打印金币和帧数 | 不断言金币等于 154，也不断言城堡仍是 300。若漏掉一只敌人但城堡还活着，这项测试仍会通过 |

本次打印出来的原型结果是满血和 154 金，所以这一局的数值是对的。测试本身没有把这两个数写成断言。这是测试缺口，不是这一局打错了。见 P2。

脚本级和场景级要分开：

- 纯数据或纯对象：内容校验、钱包、生命池、占用格、寻路函数。
- 真正跑了场景和物理帧：坏关卡加载、短关卡放置与胜负、失败、破墙、正式场景重启、正式关卡三波。后一类会实例化场景、推进 `physics_frame`，敌人会移动和掉血。
- 两者都不是操作系统输入。

本次另外在临时目录运行了 `frontier_wardens_phase1_audit_probe.gd`，退出码 0。它不是仓库测试。它补上了仓库测试没断言的部分：墙的组件构成、失败放置的节点数、30 减到 12、波次门闩、不建造时每次 9 点伤害、失败后的 180 帧、出兵后重启，以及重启后的第二局胜利。

还没有被仓库测试钉住的关键行为：

- 正式关卡的金币 154 和城堡 300/300。
- 弓箭塔两次射击之间的 0.4 秒。
- 敌人每次对城堡造成 9 点伤害。探针补了观察，仓库测试没有断言。
- 场上已有敌人时重启。探针补了观察。
- 重启后的第二局。探针补了观察。
- 建造按钮、开始波次和重新开始的操作系统点击。
- 格子上有敌人时拒绝放置。

退出码 0 只说明这些已写的断言通过。`_test_prototype_defense()` 的断言弱于它打印出来的数字，不能从退出码推出「任意摆法都正确」或「攻击间隔已测量」。

## 10. 可扩展性和硬编码风险

战斗不比较建筑显示名，也不比较 `base.wall` 或 `base.archer_tower`。`combat_building.gd` 只区分 `blocker` 和 `ranged`。未知行为在解析关卡时失败，不生成定义。放置和寻路用的是占地、占用和「这一格有没有阻挡」，不是建筑 id。

因此再加一座同类型的墙或塔，应是新的 JSON，并把它列进关卡的 `buildings` 数组。加载器仍然不会扫描 `data/buildings/`。这和阶段 0 的决定一致，注册表仍在开发计划的阶段 5。

需要新代码的情况也明确：第三种行为要改 `BuildingDefinition` 的允许字段，并在 `combat_building.gd` 里挂新组件。现在只有这两种类型，不是按名字越写越长的分支。

远程建筑同时占格挡路。这是 `ranged` 的当前规则，不是把「弓箭塔」写进寻路。以后若要做不挡路的塔，需要新的行为或新的阻挡标志，不能只改名字。

界面帮助文字写死了「城墙」和「弓箭塔」。那是说明，不参与伤害和寻路。见 P3。

`match.castle` 和 `match.spawn` 是占用表里的保留 id，用来挡住建造。它们不是内容分支。

阶段 1 没有提前做模组扫描、存档、探索或肉鸽。内置内容仍走同一套 JSON 校验。没有第二套校验器。

## 11. 问题清单

### P0

无。正式关卡能胜利，不建造能失败，重启后能再胜利。

### P1

无。没有发现会让这一局无法打完、敌人穿墙或永远卡住的已复现故障。脚本化布局和完全不建造的两极都在有限帧数内结束。

### P2

1. **正式关卡测试没有断言它打印出来的关键数字。** `_test_prototype_defense()` 只要求 `outcome == "victory"` 且城堡生命大于 0。本次输出确实是 `城堡 300/300` 和 `gold=154`，但金币算错或漏伤仍可能让这项测试通过。短关卡的 39 金和城堡不掉血是有断言的，不能代替这一局。

### P3

1. **操作系统鼠标和键盘没有验证。** 防守场景没有键盘操作。阶段 1 的操作说明也只要求鼠标。鼠标处理函数和按钮信号存在，本次没有用系统光标点过。
2. **击杀加钱不检查结局。** `notify_enemy_died()` 直接 `wallet.add()`。冻结会停止敌人并排队释放投射物。本次失败后的 120 帧和 180 帧都没有再加钱，也没有再扣城堡血。同一帧里尚未处理的投射物仍有一次结算窗口，本次没有碰到。
3. **帮助文字写死了两种建筑的名字。** 不影响规则。新建筑不会自动改这句说明。
4. **阶段 1 全部还在工作区里，没有提交。** HEAD 的主场景和版本号仍是阶段 0。功能不受影响，但仓库快照不能代表现在能玩的版本。
5. **没有场景路径的 `DefenseMatch` 不能用重启按钮重载回夹具。** 正式场景可以。测试已经改用打包场景来重启。

封路后敌人拆墙，是当前设计，不是缺陷。远程塔挡路也是当前设计。

## 12. 尚未验证的项目

| 项目 | 原因 |
| --- | --- |
| 用系统光标点击「城墙」「弓箭塔」、格子、「开始波次」和「重新开始」 | 自动化把事件送进函数，或直接调用 `place_at_cell()`、`start_next_wave()`、`restart()`。没有发送操作系统输入 |
| 键盘操作 | 防守场景没有读取键盘。阶段 1 不依赖键盘 |
| 弓箭塔攻击间隔正好是 0.4 秒 | 只确认了冷却字段会被赋给 `_cooldown`，以及第一发投射物的飞行时间。没有第二发的时间戳 |
| 敌人站在格子上时放置会被拒绝 | `place_at_world_position()` 有这个判断。本次没有制造这个局面 |
| 在 Godot 编辑器里按运行按钮 | 本次只用命令行。窗口命令能打开并截第一帧 |
| 任意手摆布局都守得住 | 只验证了文档中的 3 塔 4 墙，以及完全不建造时会失败。其他摆法没有跑 |
| 失败后同一帧的在途投射物是否还能发一次赏金 | 代码窗口存在。本次采样时投射物数量已经是 0，随后金币不变 |

手工核对操作系统输入时，用 Godot 4.7 打开 `F:\xufeng\games\project.godot` 并运行主场景，然后：

1. 点「城墙（10 金）」，再点一格空地。金币应从 200 变为 190。再点同一格，金币应不变。
2. 点「弓箭塔（50 金）」并放到另一格。金币应再减 50。
3. 点「开始波次」。应看到敌人从两处深红色「出兵」格走向左侧城堡。路被墙挡住时应拆墙或绕路，不应穿进仍存在的墙。
4. 清完一波后才能点下一波。三波都清空后应出现「防守成功」。
5. 另开一局，什么都不造，直到城堡归零。应出现「防守失败」，并且之后金币不再增加。
6. 在失败或胜利界面点「重新开始」。旧敌人和旧建筑应消失，金币回到 200，城堡回到 300/300，波次回到 0/3。然后再打一局。

开局截图不能代替上面的点击。本次截图只证明窗口能画出初始界面。

## 13. 是否可以进入阶段 2

可以进入阶段 2。

依据是本次运行已经覆盖阶段 1 的核心循环：按配置放置城墙和弓箭塔、扣钱和拒绝非法放置、三波敌人、击杀奖励、城堡受伤与失败、胜利，以及重启后的第二局。阶段 0 的校验和放置回归通过。没有 P0 或 P1。

进入阶段 2 时建议守住这三条：

1. 农场、伐木场、住宅和工坊继续用建筑定义和行为类型。不要为了新建筑在经济或战斗里写名字分支。
2. 补测试时优先把正式关卡的金币和满血写成断言。这是 P2，不是阶段 2 的功能。
3. 真实鼠标仍可由人点一局确认手感。没有这次点击，也不构成必须先改代码的阻塞。

阶段 2 仍然不要做探索、肉鸽、存档或模组扫描。

## 14. 本次命令和结果

环境：Windows 10.0.19045，PowerShell，工作目录 `F:\xufeng\games`。  
可执行文件：`%LOCALAPPDATA%\Godot\4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`。  
日志在本机临时目录 `fw_phase1_audit`，没有写入仓库。探针脚本在临时目录，没有写入仓库。

| 命令 | 退出码 | 关键输出 |
| --- | --- | --- |
| `--version` | 0 | `4.7.2.stable.official.ed1daf0bf` |
| 对 26 个 `.gd` 分别执行 `--headless --path F:\xufeng\games --check-only --script <脚本> --quit` | 每个都是 0 | `CHECK_DONE count=26 failed=0` |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage1_checks.gd` | 0 | 预期的坏 JSON 会 `push_error` 并打印 `DEFENSE_LOAD_FAIL`。随后有短关卡的 `DEFENSE_WAVE 1` 与 `DEFENSE_VICTORY`，失败关卡的 `DEFENSE_DEFEAT`，破墙关卡的 `DEFENSE_WAVE 1`，`DEFENSE_RESTART`，以及正式关卡的 `DEFENSE_WAVE 1`、`2`、`3`、`DEFENSE_VICTORY`。`PROTOTYPE_RESULT outcome=victory frames=1477 城堡 300/300 alive=0 gold=154`。最后一行 `STAGE1_PASS` |
| `--headless --path F:\xufeng\games --script res://tests/unit/stage0_checks.gd` | 0 | `STAGE0_PASS`。日志含 `base.test_watchpost` 和格子 `(2, 1)`。PowerShell 把输出存成 UTF-16，中文句子在转写里乱码；若占用或越界文本缺失，测试会打印 `STAGE0_FAIL` 并以退出码 1 结束 |
| `--headless --path F:\xufeng\games --quit-after 30` | 0 | `DEFENSE_READY base.defense_prototype gold=200 waves=3` |
| 临时探针 `--headless --path F:\xufeng\games --script <临时探针>` | 0 | `AUDIT_PROBE_DONE`。墙、拒绝放置、30 到 12 的伤害、波次门闩、不建造失败、失败后冻结、重启清理和第二次胜利都打印在探针日志里 |
| `--path F:\xufeng\games -- --shot` | 0 | OpenGL 3.3 Compatibility，NVIDIA GeForce GTX 1060 3GB。`DEFENSE_READY base.defense_prototype gold=200 waves=3`。`STAGE1_SHOT` 指向 `%APPDATA%\Godot\app_userdata\Frontier Wardens\stage1_preview.png`。文件 50739 字节，1280×720，时间 2026-10-13 19:00:36。画面是开局：金币 200、城堡 300/300、波次 0/3、城墙和弓箭塔按钮、开始波次、重新开始、左侧城堡、右侧两处出兵。没有敌人，也没有已放置的塔或墙 |

`--check-only` 只说明脚本能被解析。`STAGE1_PASS` 说明已写断言通过，不说明第 9 节里列出的未断言行为已经被测试锁死。开局截图只说明窗口能画出来。
