# AI 美术工作流（v0.2）

> 配套文档：[游戏设计文档.md](./游戏设计文档.md) · [技术设计文档.md](./技术设计文档.md)
>
> 主力模型通道：**animal-mediakit**（Seedream / Gemini / Imagen / Nano Banana 等）
>
> 美术风格：**国风唯美仙侠**（GDD §8）
>
> 范围：从 Prompt 到 Godot 资源入库的完整流水线，**含 Steam 商店页素材**

> **v0.2 变更**：因 EA 走 Steam（PC 主），卡牌图分辨率从 512×768 提升到 **1024×1536**（4K 显示器下不糊），新增 §11 Steam 商店页素材章节。

---

## 一、为什么不能只靠"想生啥生啥"

国风唯美仙侠 + 卡牌 Roguelike 的素材量级：

| 资产类型 | MVP 数量 | 完整版数量 |
|---------|---------|----------|
| 卡牌图标 | 15 | 80-150（含 +版本） |
| 角色立绘 | 1（剑修） | 4 + 多套表情 |
| 敌人立绘 | 5 | 30-50 |
| 底座纹样 | 2 | 10 |
| 遗物图标 | 0（MVP 砍掉） | 30-50 |
| 事件插画 | 0 | 20-30 |
| UI 元素 | 20 | 80+ |
| **合计** | **~50** | **~300** |

→ 必须有**统一风格 + 流水线 + 命名规范**，否则后期补图、改风格、做品控会失控。

---

## 二、核心原则

1. **风格优先于速度**：第一周必须固化 5-8 张「风格基准图」，之后所有图都对齐这套基准
2. **Prompt 模板化**：同类资产共用同一份 Prompt 骨架，仅替换语义槽
3. **生图与入库分离**：先批量生图入临时区，由人审核 → 后处理 → 才进 `assets/` 正式资源
4. **可追溯**：每张图保留 prompt + 模型 + seed + 调用时间，便于复现与同风格扩展
5. **优先用 animal-mediakit**：复用现有网关，不引入新依赖

---

## 三、风格统一策略

### 3.1 风格锚点（Style Anchors）

第一周需产出的「风格基准图」集合：

| 锚点 | 用途 | 数量 |
|------|------|------|
| 卡牌正面（攻击系） | 「斩」类卡的视觉基准 | 1 |
| 卡牌正面（控制系） | 「符箓」类卡的视觉基准 | 1 |
| 卡牌正面（蓄力/buff） | 「聚气」类卡的视觉基准 | 1 |
| 角色立绘（剑修） | 主角风格基准 | 1 |
| 杂兵敌人 | 敌人风格基准 | 1 |
| 底座纹样（六芒阵盘） | UI 底座基准 | 1 |
| 时间轴卷轴 | UI 主视觉基准 | 1 |
| 状态图标（道伤） | 图标类基准 | 1 |

→ 这 8 张图通过后，作为 `assets/style_anchors/` **永久参考**，每次生新图前先读它们。

### 3.2 风格锚定 Prompt 关键词

固定写入所有 Prompt 的"风格头部"：

```
国风唯美仙侠风格，精致游戏卡牌插画风格，
色彩绚丽，仙气十足，灵气光效，云雾缭绕，
参考原神璃月美学，飘逸仙衣，仙山背景，
金色灵气光芒，精致细腻，高品质商业插画
```

英文版（部分模型英文效果更稳定）：

```
Chinese xianxia fantasy art, beautiful immortal cultivation aesthetic,
vibrant colors, ethereal spiritual energy aura, misty mountain peaks,
golden qi light effects, flowing immortal robes, jade and gold palette,
detailed game card illustration style, Genshin Impact Liyue inspired,
high quality commercial illustration, vertical composition
```

每张图根据用途追加"主题"和"约束"。

### 3.3 反向 Prompt（Negative）

```
低质量，模糊，水墨风格，简笔画，文字，水印，西方风格，
赛博朋克，霓虹灯，现代服装，3D渲染，照片写实
```

英文版：

```
low quality, blurry, ink wash style, sketch, text, watermark,
Western fantasy, cyberpunk, neon, modern clothing, 3D render,
photorealistic, signature, multiple panels
```

---

## 四、Prompt 模板库

### 4.1 卡牌图标（最大需求量）

```
{STYLE_HEADER}

Subject: {CARD_NAME_EN} - {CARD_DESCRIPTION_EN}
Visual: centered composition, single focal element, vertical card frame,
subtle ink splatter background, {ELEMENT_COLOR_ACCENT} highlights
Camera: medium shot, eye-level, symmetric
Lighting: soft diffuse, slight ink glow on focal element

{NEGATIVE_HEADER}

Output: 1024x1536 portrait, transparent background preferred
```

**示例：**

```
Subject: Sword Strike (斩) - a single decisive sword slash cleaving through air
Visual: centered composition, single sword arc, subtle ink splatter background,
silver-grey highlights with one drop of red blood on tip
Camera: medium shot, eye-level, symmetric
Lighting: soft diffuse, slight ink glow on focal element
```

### 4.2 敌人立绘

```
{STYLE_HEADER}

Subject: {ENEMY_NAME_EN} - {ENEMY_LORE_EN}
Visual: full-body or 3/4 view, malevolent presence,
{ELEMENT_HINT} aura swirling around figure,
ink splatter feet to ground transition
Pose: {POSE_DESCRIPTION}
Lighting: dramatic, low-key, single rim light from upper-left

{NEGATIVE_HEADER}

Output: 1536x2048 portrait
```

### 4.3 角色立绘

```
{STYLE_HEADER}

Subject: {CHARACTER_ROLE} cultivator, {APPEARANCE_DETAILS}
Visual: full-body standing pose, traditional cultivation robes,
flowing hair and clothing as if in gentle wind,
sword/staff/talisman/fist as appropriate weapon held confidently,
distant misty mountains barely visible behind
Pose: heroic but contemplative, 3/4 turn
Lighting: morning mist diffuse light, soft shadow

{NEGATIVE_HEADER}

Output: 2048x3072 portrait
```

### 4.4 UI 元素

```
{STYLE_HEADER}

Subject: {UI_ELEMENT_NAME} - {FUNCTIONAL_DESCRIPTION}
Visual: tileable / nine-patch friendly,
parchment texture base, ink-drawn ornamental border,
no figurative content, pure decorative pattern
Style: minimalist, functional, low visual noise

{NEGATIVE_HEADER}

Output: {SIZE} as needed (e.g. 1920x200 banner)
```

### 4.5 底座（六芒阵盘 / 八卦盘）

```
{STYLE_HEADER}

Subject: mystical formation array (阵法), {SHAPE} pattern with {N} slots,
glowing nodes at slot positions, subtle qi flow lines connecting nodes,
ancient Chinese calligraphy / runes around perimeter
Top-down view, perfectly symmetric
Background: parchment texture, subtle gradient

{NEGATIVE_HEADER}

Output: 1024x1024 square
```

模板库存放路径：`tools/art_pipeline/prompts/`，每个模板一个 `.yaml` 文件。

---

## 五、生图 Pipeline

### 5.1 整体流程

```
策划填卡牌名/描述（CSV）
        ↓
Prompt 生成器（按模板填充）
        ↓
animal-mediakit 调用（Seedream/Imagen/Gemini）
        ↓
临时输出：assets/_pending/{type}/{id}.png + meta.json
        ↓
人工审核（GUI 工具：批量浏览、打勾通过 / 重生）
        ↓
后处理：去背景 / 裁切 / 压缩 / 加印章签名
        ↓
入库：assets/{type}/{id}.png + 自动生成 .import + 触发 Godot reimport
        ↓
（可选）写回数据资源：data/cards/{id}.tres 的 icon 字段
```

### 5.2 工具脚本规划

```
tools/art_pipeline/
├── prompts/
│   ├── card.yaml
│   ├── enemy.yaml
│   ├── character.yaml
│   ├── ui_element.yaml
│   └── base_array.yaml
│
├── inputs/
│   ├── cards.csv               # 策划维护：id, name_zh, name_en, description_en, element, ...
│   ├── enemies.csv
│   └── characters.csv
│
├── generate.py                 # 主生图脚本
├── review_gui.py               # 简易审核工具（可选，前期手动看也行）
├── postprocess.py              # 去背景 / 裁切 / 压缩
├── ingest.py                   # 入库 + 触发 Godot reimport
└── manifest.json               # 全局图片元数据索引
```

### 5.3 调用示例

```python
# tools/art_pipeline/generate.py
import yaml, csv, json
from pathlib import Path
from animal_mediakit import generate_image  # 假设 animal-mediakit 提供 Python SDK

ROOT = Path(__file__).parent
PENDING_DIR = Path("assets/_pending/cards")

def generate_card(card_row, model="seedream"):
    template = yaml.safe_load(open(ROOT / "prompts/card.yaml"))
    prompt = template["template"].format(
        STYLE_HEADER=template["style_header"],
        NEGATIVE_HEADER=template["negative"],
        CARD_NAME_EN=card_row["name_en"],
        CARD_DESCRIPTION_EN=card_row["description_en"],
        ELEMENT_COLOR_ACCENT=card_row["element_color"],
    )
    result = generate_image(
        prompt=prompt,
        model=model,
        size="1024x1536",
        seed=int(card_row["seed"]) if card_row.get("seed") else None,
    )
    out = PENDING_DIR / f"{card_row['id']}.png"
    out.write_bytes(result.image_bytes)
    meta = {
        "id": card_row["id"],
        "model": model,
        "prompt": prompt,
        "seed": result.seed,
        "generated_at": result.timestamp,
    }
    (PENDING_DIR / f"{card_row['id']}.meta.json").write_text(json.dumps(meta, indent=2))

if __name__ == "__main__":
    with open(ROOT / "inputs/cards.csv") as f:
        for row in csv.DictReader(f):
            if row["status"] == "pending":
                generate_card(row)
```

→ **关键**：每张图的 prompt + seed + 模型都落盘，要重生同风格图直接复用 seed。

### 5.4 模型选型策略（在 animal-mediakit 网关下）

| 用途 | 主力模型 | 备选 | 理由 |
|------|---------|------|------|
| 卡牌图标 | **Seedream** | Imagen | 中文风格理解最好，国内速度快 |
| 角色立绘 | **Imagen** | Seedream | 大图细节、人物比例好 |
| 敌人立绘 | **Seedream** | Gemini | 风格化能力强 |
| UI 纹样 | **Gemini** | Imagen | 简洁图形理解强 |
| 抽象概念图 | **Imagen** | - | 处理留白与构图最稳 |

策划/美术可在 CSV 中指定 `preferred_model`，pipeline 默认按上表。

---

## 六、入库到 Godot

### 6.1 目录映射

```
assets/_pending/cards/zhan.png
        ↓ ingest.py 处理后
assets/cards/sword/zhan.png
data/cards/sword/zhan.tres   ← 自动 patch icon 字段（如果文件已存在）
```

### 6.2 Godot Import 配置

每张图首次入库时，自动写一份 `.import` 配套文件：

```ini
# zhan.png.import
[remap]
importer="texture"
type="CompressedTexture2D"

[params]
compress/mode=0  # Lossless（卡牌图）或 1 = Lossy（背景图）
mipmaps/generate=false
process/fix_alpha_border=true
```

### 6.3 自动写回 .tres

```python
# tools/art_pipeline/ingest.py
def patch_card_resource(card_id, asset_path):
    tres_path = Path(f"data/cards/{card_id}.tres")
    if not tres_path.exists():
        # 首次创建：从模板生成
        tres_path.write_text(render_template("card_template.tres",
            id=card_id, icon=asset_path))
    else:
        # 已存在：仅替换 icon 字段
        content = tres_path.read_text()
        content = re.sub(r'icon = ExtResource\([^)]+\)',
                        f'icon = ExtResource("{asset_path}")', content)
        tres_path.write_text(content)
```

### 6.4 触发 Godot reimport

```bash
godot --headless --path . --import   # 让 Godot 重扫资源
```

---

## 七、后处理 Checklist

每张图入库前必经：

- [ ] **去背景**：用 `rembg` 或 Photoshop API（卡牌/角色/敌人需透明背景）
- [ ] **裁切**：统一画布比例（卡牌 1024×1536，敌人 1536×2048，角色 2048×3072）
- [ ] **压缩**：PNG 用 `pngquant`，目标 < 500 KB / 张（PC 4K 显示器下保质量优先）
- [ ] **加印章签名**（可选）：右下角加一个红色篆刻小章作为风格标记
- [ ] **风格一致性 spot check**：与风格锚点图肉眼比对
- [ ] **归档**：原始未处理图存到冷存储 `archive/raw_outputs/`，便于将来重处理

---

## 八、命名规范

### 8.1 资产 ID

| 资产 | ID 规范 | 示例 |
|------|---------|------|
| 卡牌 | `{character}_{snake_case_name}` | `sword_zhan`, `talisman_shu_jin` |
| 卡牌+版本 | `{id}_plus` | `sword_zhan_plus` |
| 敌人 | `enemy_{snake_case_name}` | `enemy_yao_qi`, `enemy_boss_act1` |
| 底座 | `slot_{type}_{size}` | `slot_basic_6`, `slot_extension_3a` |
| UI 元素 | `ui_{category}_{name}` | `ui_button_primary`, `ui_scroll_bg` |
| 状态图标 | `status_{name}` | `status_dao_shang`, `status_burn` |
| 遗物 | `relic_{name}` | `relic_ming_yu_pei` |

### 8.2 文件命名

```
assets/cards/sword/sword_zhan.png            # ID 直接作为文件名
assets/cards/sword/sword_zhan.png.import
data/cards/sword/sword_zhan.tres
```

→ ID = 文件名 = data 资源名 = 代码引用 key（`StringName(&"sword_zhan")`）

---

## 九、版权与合规

| 风险 | 应对 |
|------|------|
| 模型输出版权归属不清 | 优先使用 Seedream/Imagen/Gemini 等大厂明确声明可商用的模型 |
| 训练集涉及艺术家作品 | 不在 prompt 中使用具体艺术家名 |
| AI 生图可商用声明 | 在 README 中明确：本项目美术资产由 AI 生成，已通过 [model_name] 的商用授权 |
| LoRA 权重来源（如果后期引入） | 仅使用自己训练或明确开源可商用的 LoRA |

---

## 十、与 GDD 的衔接

GDD §8 定义的视觉语言映射表（卷轴/六芒阵/水墨晕染等）→ 直接作为本工作流 Prompt 库的"主题语义槽"。

新增视觉概念时，工作流：

```
GDD §8 表格新增一行 → AI 美术工作流 prompt 模板新增对应 yaml → 生图 → 入库
```

保持 GDD 是设计真理，本文档是执行手册。

---

## 十一、Steam 商店页素材（阶段 3.5 EA 准备期）

> Steam 商店页直接决定 EA 流量转化。所有素材必须在 EA 上线前 2 周交付（留 Valve 审核时间）。

### 11.1 必备素材清单（Valve 强制要求）

| 类型 | 尺寸 | 用途 | Prompt 风格 |
|------|------|------|-----------|
| **Capsule (Header)** | 460×215 | 商店列表主图 | 主角立绘 + LOGO，留白少 |
| **Capsule (Small)** | 231×87 | 推荐位列表 | LOGO 为主，简洁 |
| **Capsule (Main)** | 616×353 | 商店首页大图 | 含游戏氛围与角色 |
| **Capsule (Vertical)** | 374×448 | 移动端商店 | 竖版构图 |
| **Library Hero** | 1920×620 | 玩家库背景 | 全宽水墨场景 + 角色 |
| **Library Capsule** | 600×900 | 玩家库竖图 | 竖版主视觉 |
| **Library Logo** | 1280×720 透明 | 玩家库 LOGO 叠加 | 仅 LOGO，透明背景 |
| **截图 5-10 张** | 1920×1080 | 商店截图轮播 | 真实游戏画面（PrtSc 截取） |
| **预告片** | 1920×1080 mp4 | 商店预告 | OBS 录制 + 简单剪辑 |
| **GIF 动图 1-2 个** | ≤ 8MB | 社交媒体推广 | 战斗高光时刻 |

### 11.2 Capsule / Library Hero 的 Prompt 模板

```
{STYLE_HEADER}

Subject: TimeChain video game cover art -
sword cultivator hero in heroic pose, ink wash mountains background,
floating cards / talismans circling around with qi energy,
glowing timeline scroll horizontally cutting through composition,
dramatic mist and floating petals, cinematic lighting

Composition: rule of thirds, hero on left third, title space on right
Color: muted ink palette with strategic vermillion accents and gold timeline glow
Style: AAA game cover art quality, painterly, professional

{NEGATIVE_HEADER} + photorealistic faces, text, logos, frames, borders

Output: 1920x1080 (Library Hero base, will crop down to other sizes)
```

→ 一张高分辨率原图，用 Photoshop / Affinity 后期裁切派生其他尺寸。

### 11.3 LOGO 设计

LOGO **不能完全靠 AI 生**（字形可控性差）。建议：

1. AI 生概念草图（文字+纹饰组合方案 5-10 张）
2. 设计师用矢量软件（Affinity Designer / Inkscape）按草图重制可控版
3. 输出 SVG + 透明 PNG（中英双语 LOGO 都要）

### 11.4 截图策略（影响转化率最大的素材）

按以下顺序排列商店截图（玩家从左往右浏览）：

1. **战斗主视觉**：时间轴满速 + 协同高亮（最具识别度）
2. **构筑界面**：拖拽过程中 + 协同水墨连线
3. **甘特图对比**：玩家 vs Boss 的链条对比
4. **协同爆发**：火系共鸣的视觉爆发瞬间
5. **爬塔地图**：水墨风地图全景
6. **多角色**：4 角色合影（待阶段 4）
7. **遗物 / 词条系统**：信息丰富的构筑界面
8. **Boss 战**：水墨晕染下的紧张感

### 11.5 预告片结构（30-60 秒）

```
0-3s    LOGO 出现 + 标语 "时序录"
3-10s   战斗时间轴运转 + 协同爆发瞬间
10-20s  构筑界面拖拽演示 + 词条加成数字滚动
20-30s  爬塔节点选择 + 商店 / 事件快速切
30-40s  Boss 战 + 打断瞬间
40-50s  多角色快速展示（如有）
50-58s  好评 / 媒体引言（如有）/ 标语
58-60s  Steam EA 标 + 上线日期
```

工具：OBS 录游戏画面 → DaVinci Resolve（免费）剪辑 → 加古风 BGM。

### 11.6 商店页 ART 任务清单

| 任务 | 工时估计 | 优先级 |
|------|--------|------|
| Library Hero 主图（1920×1080 高质原图） | 1 天生图 + 1 天精修 | P0 |
| 各尺寸 Capsule 派生 | 1 天 | P0 |
| Library Logo（设计师参与） | 2 天 | P0 |
| 商店截图 8-10 张 | 2 天（含游戏调色） | P0 |
| 预告片剪辑 | 3 天 | P0 |
| 社交媒体推广动图 | 1 天 | P1 |
| 公告封面模板（用于 Devlog） | 1 天 | P2 |

---

## 十二、第一周可落地清单

- [ ] 确定 8 张风格锚点图（连续生 30 张选 8 张）
- [ ] 固化 `style_header` / `negative_header` 文本
- [ ] 写 `card.yaml` / `enemy.yaml` / `ui_element.yaml` 三份模板
- [ ] 跑通 `generate.py` 单卡牌生图链路（**1024×1536 分辨率**）
- [ ] 跑通 `ingest.py` 入库链路（含 .import + 资源 patch）
- [ ] 用 MVP 阶段需要的 15 张卡牌验证整条 pipeline

---

## 十三、风险与对策

| 风险 | 严重度 | 对策 |
|------|------|------|
| 风格漂移（不同时段生的图风格不一致） | 高 | 锚点图 + 固定 style_header + 同 seed 复用 |
| 中文 prompt 失败率 | 中 | 全部使用英文 prompt（中文留作内部注释） |
| 卡牌透明背景去得不干净 | 中 | rembg + 人工补刀；前期可保留底纹背景 |
| AI 生图与游戏数据不同步 | 中 | manifest.json 作为 source of truth，CI 校验"data 引用的 icon 必须存在于 assets" |
| 大模型 API 调用费用失控 | 低 | manifest 内记录每次调用，月底统计；优先 Seedream（国内便宜） |

---

## 文档版本

- v0.1 (2026-04-30) - 初稿，主力模型走 animal-mediakit（Seedream/Gemini/Imagen）
- v0.2 (2026-04-30) - 适配 Steam EA + PC 优先：
  - 卡牌图分辨率 512×768 → **1024×1536**
  - 敌人 768×1024 → **1536×2048**
  - 角色 1024×1536 → **2048×3072**
  - 压缩目标 200KB → 500KB
  - 新增 §11 Steam 商店页素材（Capsule / Library Hero / 截图 / 预告片）
