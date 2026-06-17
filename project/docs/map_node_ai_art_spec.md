# 爬塔地图节点 AI 出图规范

## 目标

为路线选择界面制作一套可替换当前程序绘制图标的独立节点素材。风格参考《杀戮尖塔》的爬塔地图可读性，但主题要贴合本项目的东方玄幻、纸卷地图、铜金法器质感。

## 通用规格

- 输出格式：PNG，透明背景。
- 单图尺寸：512 x 512 px。
- 安全区：主体图标控制在 380 x 380 px 内，外圈光效可到 460 x 460 px。
- 视角：正面微俯视，适合缩放到 64-96 px 后仍能辨认。
- 线条：厚描边，深褐或近黑外轮廓，避免细碎纹理。
- 光影：中心高光、边缘暗部，金色或玉色边缘光。
- 色彩：低饱和暗底，金、朱红、青绿、玄铁灰作为识别色。
- 禁止：文字、数字、水印、复杂背景、真实照片质感、过度写实人物。

## 节点清单

### 战斗节点 `map_node_battle.png`

- 图形：交叉飞剑或剑气符刃。
- 主色：朱红、玄铁、暗金。
- 氛围：危险、锐利、普通战斗。
- 缩小时识别点：两把交叉武器形成 X 形轮廓。

提示词：

```text
transparent background, game map node icon, crossed flying swords, xianxia fantasy, dark bronze rim, cinnabar red glow, thick readable silhouette, hand painted, stylized, high contrast, no text, no background, 512x512
```

### 篝火节点 `map_node_campfire.png`

- 图形：丹火、灵焰、简化石台。
- 主色：青绿、暖金、橙红。
- 氛围：恢复、修整、安全。
- 缩小时识别点：火焰外形清楚，底部有石台或木柴。

提示词：

```text
transparent background, game map node icon, spirit campfire on small stone altar, xianxia fantasy, jade green and warm gold flame, calm healing atmosphere, thick outline, readable at small size, hand painted, no text, no background, 512x512
```

### 宝箱节点 `map_node_chest.png`

- 图形：铜金宝匣、玉扣、符纹封条。
- 主色：暗金、琥珀、深棕。
- 氛围：奖励、稀有、可期待。
- 缩小时识别点：矩形箱体和中央锁扣。

提示词：

```text
transparent background, game map node icon, ornate bronze treasure chest, jade lock, talisman seal, xianxia fantasy, amber gold highlights, thick silhouette, hand painted, no text, no background, 512x512
```

### Boss 节点 `map_node_boss.png`

- 图形：魔冠、妖王面具、巨型兽首三选一，建议第一版用魔冠。
- 主色：暗紫红、熔金、黑铁。
- 氛围：压迫、终点、首领战。
- 缩小时识别点：冠冕或面具的尖角轮廓明显，体量比普通节点更重。

提示词：

```text
transparent background, game map boss node icon, demonic crown with sharp horns, xianxia fantasy, molten gold edge light, dark crimson core, intimidating final boss marker, thick readable silhouette, hand painted, no text, no background, 512x512
```

## 节点底座

如果图标和底座分开制作，额外输出：

- `map_node_ring_available.png`：金色外圈，轻微发光。
- `map_node_ring_locked.png`：灰蓝暗色外圈，无发光。
- `map_node_ring_completed.png`：青铜灰外圈，右上角可叠完成勾。
- `map_node_ring_boss.png`：更厚的熔金外圈，可带尖角。

底座提示词：

```text
transparent background, circular game map node frame, ancient bronze and gold, xianxia parchment map style, thick rim, subtle engraved talisman pattern, centered empty space for icon, no text, no background, 512x512
```

## 交付命名

- `project/assets/ui/map/map_node_battle.png`
- `project/assets/ui/map/map_node_campfire.png`
- `project/assets/ui/map/map_node_chest.png`
- `project/assets/ui/map/map_node_boss.png`
- 可选底座放在同目录，文件名使用 `map_node_ring_*.png`。

## 接入建议

第一版保持当前 `MapNodeButton` 的圆形底座和状态绘制，只把中央程序绘制图标替换为 PNG。这样按钮状态、可点击区域、路线连线不用改，风险最低。
