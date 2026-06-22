# 美术 Pipeline

通过 `animal-mediakit` skill CLI 生成清透新国风仙侠风格美术资产。

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
  "清透新国风仙侠风格，淡彩数字厚涂，剑修挥剑，剑气横斩，柔和云海，梦幻灵气光带" \
  --model doubao-seedream-5-0-260128 \
  --size 1024x1536 \
  --negative-prompt "低质量，模糊，水墨画，羊皮纸，卷轴纸纹，泛黄纸张，3D渲染，文字，水印" \
  -o /Users/happyelements/Documents/卡牌/project/assets/_pending/test.png
```

## 风格参数

| 参数 | 值 |
|------|-----|
| 模型 | `doubao-seedream-5-0-260128` |
| 尺寸 | `1024x1536`（卡牌竖版） |
| 风格关键词 | 清透新国风仙侠、淡彩数字厚涂、柔和云海、远山仙宫、灵气光带、清透空气感、高级游戏概念图 |
| 负面提示词 | 低质量、水墨画、羊皮纸、卷轴纸纹、泛黄纸张、3D渲染、照片写实、西方奇幻、文字水印 |
