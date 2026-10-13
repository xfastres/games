# ART_ASSET_PIPELINE.md

## 目标
为《边境守望》建立可扩展、适用于 Godot 4 的 2D 手绘卡通斜俯视资产规范。

## 重要原则
1. AI 输出先作为源素材；透明通道、帧尺寸和画面边界必须检查。
2. 不把展示海报或资产总览图当作可直接导入游戏的独立素材。
3. 资产逻辑占地与图像画布大小分离。
4. 角色锚点统一在脚底接触点；建筑锚点一般在底部中心；投射物锚点按旋转枢轴定义。
5. 人物与需要相互遮挡的对象，应在 Godot 中使用一致的 Y-sort 或分层规则。
6. 新素材必须在实际游戏窗口中检查比例、锚点、透明边缘和遮挡。

## 建议尺寸（需结合现有项目核对）
- 等距地面图块：128×64 px
- 小型地面装饰：64×64 或 128×128 px
- 城墙：128×128 px
- 弓箭塔：192×224 px
- 农场、住宅、工坊：192×192 px
- 城堡：384×384 px
- 普通角色帧：96×96 px
- 领主角色帧：128×128 px
- 投射物：32×32 px
- 特效帧：64×64 px
- UI 图标：64×64 px

这些是建议值，不是 Godot 强制规格。正式使用前，核对项目地图格子、坐标转换和显示缩放。

## 动画建议
- idle：4–6 帧，4–6 FPS，循环
- walk：6–8 帧，8–10 FPS，循环
- attack：5–8 帧，10–12 FPS，不循环
- hurt：2–3 帧，8–10 FPS，不循环
- death：6–8 帧，8–10 FPS，不循环
每帧画布一致，脚底基准一致。伤害命中时机由游戏逻辑控制。

## 命名
- `castle.png`
- `archer_tower.png`
- `wooden_wall.png`
- `default_lord_idle.png`
- `default_lord_walk.png`
- `default_lord_attack.png`
- `default_lord_hurt.png`
- `default_lord_death.png`
- `goblin_idle.png`
- `goblin_walk.png`
- `grass_tile.png`
- `arrow_projectile.png`

## 建议目录
`assets/source/` 保留 AI 原始输出；`assets/sprites/` 存放经校验的游戏素材；按 buildings、characters、terrain、projectiles、effects、ui 分类。

## Godot 导入与排序
- 规则 spritesheet 可用 `AnimatedSprite2D` 和 `SpriteFrames`。
- 单帧 PNG 也可通过逐帧加载构建动画。
- 地面先绘制；人物和需要互相遮挡的对象使用一致排序策略。
- 高塔、城堡等高大建筑可按实际结构分层，避免仅靠一个全局 `z_index` 导致遮挡错误。
- 缺失素材、帧尺寸不一致、配置引用错误应报告为明确错误。

## 验收清单
- [ ] 真实透明背景，而不是绘制出来的棋盘格
- [ ] 实际画布尺寸正确
- [ ] 无意外裁切和白边
- [ ] 动画帧一致且可循环
- [ ] 接地点和锚点稳定
- [ ] 与当前地图视角一致
- [ ] Godot 内显示和排序正确
- [ ] 资源 ID、文件名和配置引用一致
