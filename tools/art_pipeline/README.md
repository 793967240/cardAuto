# 美术 Pipeline

通过 `animal-mediakit` skill CLI 生成水墨修仙风格美术资产。

## 前置条件

1. 已安装 `animal-mediakit` skill（路径 `~/.config/opencode/skills/animal-mediakit/`）
2. 已完成 SSO 登录：
   ```bash
   uv run ~/.config/opencode/skills/animal-mediakit/scripts/cli.py auth login
   ```

## 生成风格锚点图（阶段 0 必做）

```bash
cd project/
python3 tools/art_pipeline/generate_card.py --style-anchors
```

生成 8 张风格锚点图到 `assets/_pending/`，团队评审后固化风格基准。

## 生成单张卡牌图

```bash
python3 tools/art_pipeline/generate_card.py --card tools/art_pipeline/card.yaml
```

修改 `card.yaml` 中的 `prompt` 字段来定制内容。

## 资产入库

```bash
python3 tools/art_pipeline/ingest.py --pending-all --dest cards/sword
python3 tools/art_pipeline/ingest.py --file assets/_pending/xxx.png --dest cards/sword
```

## 直接调用 skill CLI

```bash
SKILL=~/.config/opencode/skills/animal-mediakit

uv run $SKILL/scripts/cli.py generate image \
  "水墨修仙风格，剑修挥剑，剑气横斩" \
  --model doubao-seedream-5-0-260128 \
  --size 1024x1536 \
  --negative-prompt "低质量，模糊，3D渲染，文字" \
  -o /Users/happyelements/Documents/卡牌/project/assets/_pending/test.png
```

## 风格参数

| 参数 | 值 |
|------|-----|
| 模型 | `doubao-seedream-5-0-260128` |
| 尺寸 | `1024x1536`（卡牌竖版） |
| 风格关键词 | 水墨修仙、留白、笔触质感、墨色晕染、卷轴纸纹 |
| 负面提示词 | 低质量、3D渲染、照片写实、西方奇幻、文字水印 |
