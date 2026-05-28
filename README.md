# TimeChain（时序录）

国风唯美仙侠 · 时间轴卡牌构筑 · 自动战斗 · Roguelike 爬塔

**引擎**：Godot 4.6 · **语言**：GDScript · **平台**：Steam PC (Windows / Linux / macOS)

---

## 快速启动

### 前置条件

- [Godot 4.6](https://godotengine.org/download) (Forward+ 后端)
- Python 3.11+（工具脚本）
- Git
- `animal-mediakit` skill（美术生图用）

### 克隆 & 打开

```bash
git clone <repo_url>
cd timechain
```

用 Godot 编辑器打开 `project.godot`，或直接运行：

```bash
godot --path project/
```

### 启用 gut 测试框架

gut 已内置于 `addons/gut/`，在 Godot 编辑器中启用：

> Project → Project Settings → Plugins → GUT → ✅ Enable

### 中文字体（首次设置）

Cormorant（英文）已包含在 `assets/fonts/`，思源宋体需手动下载后子集化：

```bash
# 1. 下载思源宋体 SC（约 20MB）
# https://github.com/adobe-fonts/source-han-serif/releases
# 保存为：assets/fonts/source_han_serif_sc_regular.otf

# 2. 子集化（输出约 3-5MB）
pip install fonttools
python3 tools/font_subset.py
```

### 运行测试

```bash
cd project/

# 单元测试
godot --headless --path . \
  --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -gexit

# 集成测试
godot --headless --path . \
  --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests/integration -gexit

# 全部测试
godot --headless --path . \
  --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests -gexit
```

### i18n 校验

```bash
cd project/
python3 tools/i18n_check.py        # 检查缺失 key + 占位符一致性
python3 tools/i18n_no_hardcode.py  # 检查硬编码字符串
```

### 验收命令（阶段 1 工程 Gate）

```bash
cd project/

# 1. 平衡基线跑批（1000 局/敌人 × 5 个敌人）
godot --headless --path . --script tests/baseline_runner.gd -- \
  --count 1000 --out reports/baseline/baseline_v1.json

# 2. 平衡 gate（200 局/敌人小批量，对比 baseline；CI 自动跑）
godot --headless --path . --script tests/balance_gate.gd

# 3. 战斗逻辑 4x 性能基准（1000 tick wall clock < 1s）
godot --headless --path . --script tests/perf_battle_4x.gd

# 4. 多分辨率 UI 巡检（4 档 × 4 场景 = 16 张截图 + overflow 检测）
#    注意：不能 headless，需要真实渲染
godot --path . --script tools/ui_resolution_check.gd
```

每条命令退出码 0 即通过；产物分别在 `reports/baseline/`、`reports/perf/`、`reports/ui_audit/`。

### 生成 AI 美术

> 需要先登录 animal-mediakit skill：
> `uv run ~/.config/opencode/skills/animal-mediakit/scripts/cli.py auth login`

```bash
cd project/

# 生成 8 张风格锚点图（阶段 0 必做，团队评审固化风格基准）
python3 tools/art_pipeline/generate_card.py --style-anchors

# 生成单张卡牌图
python3 tools/art_pipeline/generate_card.py --card tools/art_pipeline/card.yaml

# 查看待入库图片
python3 tools/art_pipeline/generate_card.py --list-pending
```

详细说明见 `tools/art_pipeline/README.md`。

---

## 目录结构

```
project/
├── src/
│   ├── core/          # 核心战斗系统（无 UI 依赖，Headless 可运行）
│   ├── data_models/   # Resource 定义（CardData / EnemyData / Tuning）
│   ├── meta/          # 爬塔 / 存档 / 商店 / 事件
│   ├── ui/            # UI 节点脚本
│   ├── input/         # 输入抽象层（键鼠/触屏/手柄统一）
│   └── globals/       # AutoLoad 单例
├── data/              # 数据驱动资源（.tres 文件）
├── assets/            # 美术资源
├── tests/             # gut 测试代码
├── tools/             # 开发工具（生图 / i18n 校验 / 平衡回归）
├── translations/      # i18n CSV 文件
├── reports/           # 验收报告（baseline / perf / ui_audit / e2e）
└── .github/workflows/ # GitHub Actions CI
```

### reports/ 目录

| 子目录 | 内容 | 何时刷新 |
|---|---|---|
| `baseline/` | 平衡基线 JSON（1000 局/敌人）+ README | 卡牌/敌人/调参变更后重跑 `tests/baseline_runner.gd` |
| `perf/` | 战斗逻辑性能基准（1000 tick wall clock） | 战斗核心代码改动后重跑 `tests/perf_battle_4x.gd` |
| `ui_audit/` | 4 分辨率 × 4 场景截图 + overflow 检测 + README | UI 改动后本地重跑 `tools/ui_resolution_check.gd` |
| `e2e/` | 完整 11 节点通关日志（gut 集成测试副产物） | 战斗/地图/存档变更后通过 gut 自动产出 |

---

## 开发规范

- **i18n 强制**：所有 UI 字符串必须走 `tr("key")`，禁止硬编码 → CI 会自动检查
- **核心与 UI 分离**：`src/core/` 不允许 import 任何 UI 节点
- **测试覆盖**：每个核心类必须有对应的 `tests/unit/test_*.gd`
- **命名规范**：节点/类 `PascalCase`，脚本文件 `snake_case.gd`，信号 `past_tense`
- **翻译工作流**：修改文本 → 更新 `translations/_source.csv` → Google Sheet 同步

## 翻译协作

翻译 Google Sheet（中英双语，含 Glossary 修仙术语表）：
**https://docs.google.com/spreadsheets/d/1_timechain_i18n_placeholder**
> ⚠️ 正式 Sheet 创建后替换此链接

工作流：修改 `translations/_source.csv` → Sheet 同步 → 导出 `zh_CN.csv` / `en.csv` → CI 校验 → 合入

---

## 阶段进度

| 阶段 | 状态 | 目标 |
|------|------|------|
| 0 · 地基 | ✅ 完成 | 项目骨架 + CI + 美术 Pipeline + i18n |
| 1 · 核心循环 MVP | ✅ 工程层完成 | 可玩一场完整战斗（PC 键鼠）；玩法体感由用户人工试玩验证 |
| 2 · 构筑深度 | 🟡 UI 接入完成 | BuildScene 多底座 + 词条挂载 + 篝火修炼已通；词条/卡池铺量与 baseline 重做下一批 |
| 3 · Roguelike 外壳 | ⏳ 待启动 | 完整爬塔 + Act 1+2 |
| 3.5 · EA 准备期 | ⏳ 待启动 | Steam 集成 + 商店页 + 体验抛光 |
| 🚀 Steam EA | ⏳ 待启动 | - |

---

## 许可证

*(待确定)*
