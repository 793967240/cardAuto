# AI 自动化集成测试方案（v0.1）

> 配套文档：[游戏设计文档.md](./游戏设计文档.md) · [技术设计文档.md](./技术设计文档.md)
>
> 范围：**Headless 战斗模拟 + 平衡性回归**（MVP 起步层级）
>
> 不在本期范围：UI E2E 自动化点击、截图比对回归（留待阶段 4 后评估）

---

## 一、测试目标

### 1.1 为什么必须自动化测试

卡牌 Roguelike 的复杂度来自**组合爆炸**：

| 维度 | 量级（MVP 完成时） |
|------|------------------|
| 卡牌种类 | 50-80 张（×2，含 +版本） |
| 底座词条 | ~30 个独立 + ~15 个共享 |
| 协同机制类型 | 8 种（GDD §3.5） |
| 敌人种类 | 20+ |
| 单次 Run 决策点 | 节点数 × 奖励三选一 ≈ 100 选择 |

→ **手动测穷举不可能**。必须用 AI 跑战斗模拟，在 CI 上每次合码都跑一遍数据回归。

### 1.2 测试金字塔

```
       ┌──────────────┐
       │ E2E (人工)    │  阶段 4+ 才考虑，靠玩测
       └──────────────┘
      ┌────────────────┐
      │ 平衡性回归       │  本期重点：跑万局战斗，对比胜率分布
      └────────────────┘
    ┌────────────────────┐
    │ 集成测试（Headless）│  完整战斗 / 完整 Run 模拟
    └────────────────────┘
  ┌────────────────────────┐
  │ 单元测试（gut + GDScript）│  Timeline、Chain、Effect、Status 各自隔离
  └────────────────────────┘
```

---

## 二、测试基础设施

### 2.1 单元测试：gut 框架

**为什么用 gut**：
- Godot 4.x 社区最成熟的 GDScript 测试框架
- 支持 mock / spy / 参数化测试
- CLI 友好：`godot --headless --script addons/gut/gut_cmdln.gd`

**安装**：

```bash
# 方式一：Asset Library 直装
# 方式二：git submodule
git submodule add https://github.com/bitwes/Gut.git addons/gut
```

**测试目录约定**：

```
tests/
├── unit/
│   ├── test_timeline.gd
│   ├── test_chain.gd
│   ├── test_card_runtime.gd
│   ├── test_effect_attack.gd
│   ├── test_effect_charge.gd
│   ├── test_effect_interrupt.gd
│   └── test_status_system.gd
└── integration/
    ├── test_battle_simulator.gd
    ├── test_synergy_charge_burst.gd
    └── test_synergy_resonance_fire.gd
```

**示例：单元测试**

```gdscript
# tests/unit/test_timeline.gd
extends GutTest

func test_tick_advances_at_correct_rate() -> void:
    var timeline := Timeline.new()
    var tick_count := 0
    timeline.tick_advanced.connect(func(_t): tick_count += 1)

    # 模拟 1 秒（应当推进 2 tick，因为 1 tick = 0.5 秒）
    timeline.update(1.0)
    assert_eq(tick_count, 2, "1 second should advance 2 ticks at 1x speed")

func test_speed_multiplier_doubles_tick_rate() -> void:
    var timeline := Timeline.new()
    timeline.set_speed_multiplier(2.0)
    var tick_count := 0
    timeline.tick_advanced.connect(func(_t): tick_count += 1)

    timeline.update(1.0)
    assert_eq(tick_count, 4, "1 second at 2x should advance 4 ticks")
```

### 2.2 集成测试：Headless 战斗模拟器

#### 设计原则

`BattleSimulator` 是 `core/` 中**完全独立于 UI** 的类，可在 CLI 下直接驱动。

```gdscript
# src/core/battle_simulator.gd
class_name BattleSimulator extends RefCounted

func simulate(
    player_build: PlayerBuild,
    enemies: Array[EnemyData],
    seed: int = 0,
    max_ticks: int = 600,
    ai_strategy: AIStrategy = AIStrategy.NONE
) -> BattleResult:
    var ctx := BattleContext.new(player_build, enemies, seed)
    var tick := 0
    while not ctx.is_finished() and tick < max_ticks:
        ctx.advance_one_tick()
        tick += 1

    return BattleResult.new({
        "winner": ctx.get_winner(),
        "ticks_elapsed": tick,
        "player_hp_remaining": ctx.player.hp,
        "damage_dealt": ctx.stats.damage_dealt,
        "damage_taken": ctx.stats.damage_taken,
        "cards_fired": ctx.stats.cards_fired,
        "interrupts_landed": ctx.stats.interrupts_landed,
    })
```

**关键属性**：
- 完全确定性：同一 `seed` + 同一 build 永远产生同一结果
- 单次模拟 < 50ms（GDScript 实现），跑 1 万局 < 10 分钟

#### 使用示例

```gdscript
# tests/integration/test_battle_simulator.gd
extends GutTest

func test_starter_card_repository_can_beat_first_wave() -> void:
    var build := PlayerBuild.starter_sword()
    var enemies := [Loader.enemy(&"slime"), Loader.enemy(&"slime")]
    var sim := BattleSimulator.new()
    var result := sim.simulate(build, enemies, 0)
    assert_eq(result.winner, BattleResult.PLAYER, "Starter card repository should beat first wave")
    assert_lt(result.ticks_elapsed, 120, "First wave should resolve within 60 sec")
```

### 2.3 AI 陪练 Agent（阶段 2 加入，本期可选）

**MVP 起步阶段**：仅做"固定链条 vs 固定敌人"的回归。
**阶段 2 后**：加入会自己摆链条、选奖励的 AI Agent。

#### Agent 设计

```gdscript
# tools/ai/play_agent.gd
class_name PlayAgent extends RefCounted

# 给定卡牌池，返回最优排序
func arrange_chain(slots: Array[Slot], hand: Array[CardData]) -> Array[CardData]:
    # 启发式 v1：按 cost 升序 + 同标签聚合（共鸣加成）
    pass

# 给定三选一奖励，返回选哪个
func pick_reward(state: RunState, options: Array[Reward]) -> int:
    # 启发式 v1：与现有 build 协同分最高的
    pass
```

**评估指标**：
- AI 通关率（应该 30-50% 之间，太高=游戏太简单，太低=平衡有问题）
- AI 平均通关时长

---

## 三、平衡性回归（核心产出）

### 3.1 跑万局战斗

```bash
# tools/balance_runner.sh
godot --headless --script tools/balance_runner.gd \
  --seeds=0..9999 \
  --build-preset=sword_starter \
  --enemy-set=act1 \
  --output=reports/balance_$(date +%Y%m%d_%H%M).json
```

`balance_runner.gd` 内部调用 `BattleSimulator.simulate()` 跑 10000 次，输出 JSON：

```json
{
  "preset": "sword_starter",
  "enemy_set": "act1",
  "total_runs": 10000,
  "win_rate": 0.62,
  "avg_ticks": 84.3,
  "avg_player_hp_remaining_on_win": 41.2,
  "p95_ticks": 142,
  "card_fire_distribution": {
    "zhan": 4823,
    "ju_qi": 2104,
    ...
  },
  "loss_root_causes": {
    "hp_zero": 3621,
    "timeout": 179
  }
}
```

### 3.2 数据可视化

每次 CI 跑完后，用 Python 脚本生成 HTML 报告：

```python
# tools/balance_report.py
import json, sys
import matplotlib.pyplot as plt
import pandas as pd

def render(report_path):
    data = json.load(open(report_path))
    # 1. 胜率热力图：横轴=卡牌仓库 preset，纵轴=敌人 set
    # 2. tick 分布直方图
    # 3. 卡牌触发频率排行
    # 4. 与上次 baseline 的 diff
    ...
```

输出：`reports/balance_20260430_1530.html` —— 可上传 GitLab Pages 或飞书。

### 3.3 平衡性 Gate 规则

CI 自动判断"是否阻塞合码"：

| 指标 | 警告阈值 | 阻塞阈值 |
|------|---------|---------|
| 起手卡牌仓库对 Act 1 胜率 | <50% 或 >80% | <30% 或 >95% |
| 任意单卡触发频率 | <0.3× 平均 或 >3× 平均 | <0.1× 平均 或 >10× 平均 |
| Boss 战平均时长偏离 | ±30% | ±60% |
| 与上次 baseline 胜率 diff | >5pp | >15pp |

阻塞 → MR 不允许合并，必须有"平衡性变更说明"标签人工 override。

---

## 四、CI 集成

### 4.1 GitLab CI 配置（参考）

```yaml
# .gitlab-ci.yml
stages:
  - test
  - balance
  - report

variables:
  GODOT_VERSION: "4.6-stable"

godot_setup:
  stage: .pre
  script:
    - apt-get update && apt-get install -y wget unzip
    - wget -q https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip
    - unzip Godot_v${GODOT_VERSION}_linux.x86_64.zip
    - mv Godot_v${GODOT_VERSION}_linux.x86_64 /usr/local/bin/godot
  artifacts:
    paths:
      - /usr/local/bin/godot

unit_tests:
  stage: test
  script:
    - godot --headless --path . --script addons/gut/gut_cmdln.gd \
        -gdir=res://tests/unit -gexit
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

integration_tests:
  stage: test
  script:
    - godot --headless --path . --script addons/gut/gut_cmdln.gd \
        -gdir=res://tests/integration -gexit
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

balance_regression:
  stage: balance
  script:
    - godot --headless --path . --script tools/balance_runner.gd \
        -- --seeds=0..1999 --output=balance.json
    - python3 tools/balance_check.py balance.json
  artifacts:
    paths:
      - balance.json
      - reports/
    expire_in: 30 days
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - data/cards/**/*
        - data/enemies/**/*
        - data/tuning/**/*
        - src/core/**/*

balance_full:
  stage: balance
  script:
    - godot --headless --path . --script tools/balance_runner.gd \
        -- --seeds=0..9999 --output=balance_full.json
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: always
  schedule: nightly
```

**关键策略**：
- MR 阶段：跑 2000 局快速回归（约 5 分钟）
- 主分支夜跑：跑 10000 局完整回归
- 数据/核心代码改动才触发 balance 阶段，UI 改动不触发

### 4.2 飞书通知

balance gate 失败时，自动通过 `feishu-operator` 发卡片到团队群：

```
⚠️ 平衡回归告警
分支: feature/sword-rework
胜率: 32.1%（baseline 65.4%，变动 -33.3pp）
触发阈值: 阻塞合码
变更文件: data/cards/sword/zhan.tres
查看报告: <link>
```

---

## 五、测试数据管理

### 5.1 Build Preset

测试用的"标准卡牌仓库"集中在 `tests/fixtures/builds/`：

```
tests/fixtures/builds/
├── sword_starter.tres       # 剑修起手卡牌仓库（与游戏内一致）
├── sword_charge_burst.tres  # 充能爆发流（GDD §10.1 示例）
├── sword_resonance_fire.tres
├── talisman_interrupt.tres
└── ...
```

每次平衡变更后跑全部 preset，对比 baseline。

### 5.2 Enemy Set

```
tests/fixtures/enemy_sets/
├── act1_normal.tres         # Act 1 普通战斗 5 套敌人组合
├── act1_elite.tres
├── act1_boss.tres
├── act2_*.tres
└── act3_*.tres
```

### 5.3 Baseline 管理

```
reports/baseline/
├── balance_baseline.json    # 当前已认可的"正常状态"基线
└── README.md                # 何时由谁更新，原因
```

更新基线必须 PR + 至少 1 人 review。

---

## 六、不在本期范围（已识别）

| 项 | 推迟原因 | 何时启动 |
|------|---------|---------|
| UI 自动点击 / 截图回归 | UI 频繁迭代，前期投入产出比低 | 阶段 4 美术稳定后 |
| 真机性能基准测试 | 需要真机 farm，成本高 | 阶段 5 平台扩展时 |
| 模糊测试（fuzzing） | 输入空间相对小 | 必要时再加 |
| AI 自学习陪练（RL） | 启发式 Agent 已够用 | 远期 |

---

## 七、PC 多平台构建烟雾测试（v0.2 新增）

> EA 走 Steam，PC 三平台必须每次合码都验证能启动。这个测试**与玩法无关**，仅验证"能不能跑起来"。

### 7.1 测试目标

每次 main 分支合并：
- Windows / Linux / macOS 三平台分别出包
- 各平台启动到主菜单，无崩溃
- 启动用时 < 10 秒（CI 环境）
- 主菜单点击"开始游戏"能进入下一界面

### 7.2 CI Job 配置示例

```yaml
build_smoke:
  stage: build
  parallel:
    matrix:
      - PLATFORM: [windows, linux, macos]
  script:
    - godot --headless --path . --export-release "${PLATFORM}" build/${PLATFORM}/game
    - ./tools/smoke_launch.sh build/${PLATFORM}/game
  artifacts:
    paths:
      - build/${PLATFORM}/
    expire_in: 7 days
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

### 7.3 烟雾测试脚本

```bash
# tools/smoke_launch.sh
# 启动游戏，5 秒内截图，比对主菜单标志，然后退出
GAME_PATH=$1
$GAME_PATH --smoke-test &       # 游戏启动后自动播放预设动作脚本然后退出
PID=$!
sleep 8
if ! kill -0 $PID 2>/dev/null; then
    echo "✓ Game exited cleanly within smoke test window"
    exit 0
else
    kill $PID
    echo "✗ Game still running after timeout"
    exit 1
fi
```

游戏内提供 `--smoke-test` 启动参数：
- 跳过启动画面
- 加载主菜单
- 等 1 秒
- 模拟点击"开始游戏" → 选剑修 → 进入战斗 → 跳过到第一回合
- 等 1 秒
- 干净退出（exit code 0）

### 7.4 Steam Deck 烟雾测试（阶段 3.5 起）

```bash
# Steam Deck 测试需要真机或 SteamOS 模拟环境
# CI 跑不到，但每次发版手动跑一遍
# 关键检查：
# - 1280x800 分辨率 UI 不溢出
# - 手柄能完整操作菜单
# - 文字大小可读
```

→ 阶段 3.5 EA 准备期开始，每次 release candidate 必须在 Steam Deck 实机跑一遍。

---

## 八、第一周可落地清单（与开发路线图对齐）

为了避免"测试方案永远停在文档"，前期就要把骨架立起来：

- [ ] Godot 项目骨架 + gut 接入
- [ ] `Timeline` 类 + 单元测试（5 个 case）
- [ ] `Chain` 类 + 单元测试（含修整、空链条边界）
- [ ] `BattleSimulator` 主循环 + 1 个 smoke 集成测试
- [ ] CI 跑通 unit + integration（无 balance 阶段）
- [ ] **CI 跑通三平台 PC 构建烟雾测试**
- [ ] balance_runner 雏形（先跑 100 局生成 JSON 即可）
- [ ] README 写明本地运行测试的命令

---

## 九、风险与对策

| 风险 | 对策 |
|------|------|
| 测试代码积累后变成"二等公民"，没人维护 | 每次新卡牌入库时强制配套测试，纳入 MR checklist |
| Headless 模拟器与真实战斗逻辑漂移 | `BattleController` 内部直接复用 `BattleContext`，避免双写 |
| GDScript 跑万局太慢 | 必要时把 `BattleSimulator` 抽成 C# 或 Python 镜像版本（仅离线分析） |
| 测试数据 fixture 过期 | 每个版本 release 前重新生成 baseline |

---

## 文档版本

- v0.1 (2026-04-30) - 初稿，MVP 起步层级（Headless + 平衡回归）
- v0.2 (2026-04-30) - 适配 Steam EA + PC 优先：
  - 新增 §7 PC 多平台（Windows / Linux / macOS）构建烟雾测试
  - 新增 Steam Deck 烟雾测试约定
  - 第一周清单加上三平台 CI 构建项
