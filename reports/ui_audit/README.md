# UI Audit Reports

> 多分辨率 UI 巡检 - 4 档分辨率 × 4 个场景 = 16 张截图基线 + 越界检测。

## 重跑命令

```bash
cd project
godot --path . --script tools/ui_resolution_check.gd
```

⚠️ **注意**：本脚本**不能 headless 跑**（`--path` 而非 `--headless --path`），
因为截图需要真实渲染。CI 上跳过此 job，本地手动跑。

## 覆盖矩阵

| 分辨率 | 场景 |
|---|---|
| 1920×1080（标准 16:9） | main_menu / battle / build / map |
| 2560×1440（2K） | main_menu / battle / build / map |
| 1280×800（小笔记本） | main_menu / battle / build / map |
| 3440×1440（21:9 超宽） | main_menu / battle / build / map |

## 输出结构

```
reports/ui_audit/
├── README.md（本文件）
├── 1920x1080/
│   ├── main_menu.png
│   ├── battle.png
│   ├── build.png
│   ├── map.png
│   └── overflow.json
├── 2560x1440/...
├── 1280x800/...
└── 3440x1440/...
```

⚠️ 重跑前**不要** `rm -rf reports/ui_audit/*`（会删除本 README）。
脚本会覆盖各分辨率子目录下的 PNG 与 overflow.json，但不会动 README.md。

## 越界检测规则

`overflow.json` 列出所有「Control 节点 global_rect 超出 viewport」的节点。
**例外（合法越界，自动跳过）**：
- `ScrollContainer` 内部子节点 — 滚动内容理应可超出 viewport
- 不可见节点（`visible == false`）
- 空尺寸节点（`size.x <= 0` 或 `size.y <= 0`）

阈值：±1px 抗锯齿误差。

## 退出码

- `0` — 所有分辨率均无 overflow
- `1` — 任一分辨率检测到 overflow

## 关于 viewport size

项目使用 `canvas_items` stretch + `expand` aspect。`window_set_size()` 改变窗口大小，
viewport 实际 size 由 stretch 模式决定（基准 1920×1200，按比例拉伸）。
`overflow.json.actual_viewport` 字段记录实际 viewport size，便于排查。

观测：
- 1920×1080 → viewport 1920×1080（精确匹配）
- 2560×1440 → viewport 1920×1080（拉伸到窗口）
- 1280×800 → viewport 1920×1200（缩小到窗口）
- 3440×1440 → viewport 2580×1080（21:9 expand 横向扩展）

## 当前快照（v1）

- 16 张截图全部产出（每张 9.3–100.1 KB）
- 4 个 overflow.json 全部为 `"overflows": []`
- 退出码 0

## 视觉对比工作流（人工 review）

1. PR 改 UI 前：留存当前 `reports/ui_audit/`
2. PR 改 UI 后：重跑此脚本
3. 用 `git diff --stat reports/ui_audit/` 看哪些 PNG 变了
4. 肉眼对比变化是否符合预期
5. overflow.json 必须保持 `"overflows": []`（除非有意改）

> 图像 diff 自动化工具超出阶段 1 范围，留待阶段 3.5 EA 准备期。
