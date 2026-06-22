# Xianxia UI Theme

清透新国风仙侠主题资产目录。新版口径聚焦淡彩厚涂、云海远山、仙宫、灵气光带和高级游戏概念图质感。

## Layout

- `backgrounds/`: full-screen and scene backgrounds.
- `bars/`: title bars, top bars, and long navigation strips.
- `buttons/`: source button PNGs, a cropped theme-ready jade button PNG, default jade `StyleBoxTexture` states, and importer-safe flat fallback states.
- `plaques/`: card slots, signboards, medallions, and framed plaques.
- `panels/`: reusable panel `StyleBoxFlat` resources.
- `tooltips/`: AI-generated tooltip frame source and UI-ready background style.
- `xianxia_theme.tres`: standalone Theme entry for screen-level opt-in or later global replacement.

## Migration Notes

Build scene currently loads PNG files through `Image.load_from_file()` to avoid the existing Godot `.ctex` import cache issue. The tooltip frame has an AI source image under `tooltips/_source_ai/` and a cleaned RGBA runtime asset at `tooltips/tooltip_frame_xianxia.png`.
