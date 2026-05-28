# AGENTS.md — 时序录 (TimeChain) 项目指南

> 给 AI Agent 的快速参考。修改代码前必读此文件。

---

## 项目概述

**Godot 4.6 GDScript 卡牌 Roguelike**。Xianxia（仙侠）主题，时间轴自动战斗 + 构筑。

- **引擎**: Godot 4.6, GDScript
- **测试框架**: GUT (addons/gut/)
- **平台**: Steam (Windows/Linux/macOS), PC 优先
- **当前阶段**: 阶段 2（构筑深度）— v0.5 核心机制重构后

---

## 目录结构

```
project/
├── src/
│   ├── core/              # 战斗核心逻辑（无 UI 依赖）
│   │   ├── chain.gd       # 链条执行器：环形循环，8 卡无缝轮转
│   │   ├── chain_slot.gd  # 单槽元数据：card + gems
│   │   ├── chain_composer.gd  # 编译 RunState → ChainSlot[]
│   │   ├── battle_context.gd  # 战斗状态容器 + tick 驱动
│   │   ├── battle_controller.gd  # Node 桥接 Context → EventBus
│   │   ├── battle_simulator.gd   # Headless 战斗模拟（CI 用）
│   │   ├── combatant.gd   # 战斗者（玩家/敌人共用）
│   │   ├── card_runtime.gd # 卡牌运行时实例
│   │   ├── gem_instance.gd # 宝石运行时实例
│   │   ├── timeline.gd    # Tick 引擎（速度倍率）
│   │   ├── status.gd      # 状态系统（虚弱/易伤/燃烧/充能等）
│   │   └── effects/       # 卡牌效果 + 宝石效果
│   │       ├── card_effect.gd      # 卡牌效果基类
│   │       ├── effect_attack.gd    # 攻击（调用 chain.modify_damage）
│   │       ├── effect_*.gd         # 其他卡牌效果
│   │       ├── gem_effect.gd       # 宝石效果基类
│   │       └── gems/               # 具体宝石效果实现
│   ├── data_models/       # Resource 数据定义
│   │   ├── card_data.gd   # 卡牌（cost/type/effect/tags/upgrade）
│   │   ├── slot_data.gd   # 底座（id + gem_socket_count）
│   │   ├── gem_data.gd    # 宝石（trigger: PASSIVE/ON_PLAY/ON_CYCLE）
│   │   ├── enemy_data.gd  # 敌人
│   │   └── tuning.gd      # 全局平衡参数（base_count=8 等）
│   ├── meta/              # 存档/进度
│   │   ├── run_state.gd   # Run 状态（v4 schema: bases/base_cards/base_gems/gems）
│   │   ├── save_system.gd # 存档读写（含 _rehydrate 反序列化）
│   │   ├── map_generator.gd
│   │   └── reward_pool.gd
│   ├── globals/           # AutoLoad 单例
│   │   ├── game_state.gd  # 游戏状态 + start_run()
│   │   ├── event_bus.gd   # 全局信号总线
│   │   └── settings.gd
│   └── ui/                # UI 场景脚本
│       ├── battle/battle_scene.gd
│       ├── build/build_scene.gd   # 构筑界面：8 底座网格 + 宝石面板 + 卡组
│       ├── map/map_scene.gd       # 地图 + 篝火（回血/升级）
│       └── components/    # 可复用 UI 组件
│           ├── card_view.gd       # 卡牌组件（BATTLE/BUILD_SLOT/BUILD_DECK_ITEM 三模式）
│           ├── enemy_view.gd
│           └── timeline_scroll_view.gd
├── data/                  # .tres 资源文件
│   ├── cards/sword/       # 剑修卡牌（17 张）
│   ├── enemies/           # 敌人（5 个）
│   ├── gems/              # 宝石（4 个：ruby/sapphire/amber/jade）
│   ├── slots/base/        # 底座模板（base_slot.tres）
│   └── tuning/            # 平衡参数
├── scenes/                # .tscn 场景文件
├── tests/
│   ├── unit/              # 单元测试（chain/combatant/effects/timeline/smoke）
│   ├── integration/       # 集成测试（e2e/simulation/balance/simulator）
│   ├── baseline_runner.gd # 平衡基线跑批工具
│   ├── balance_gate.gd    # CI 平衡警告 gate
│   └── perf_battle_4x.gd  # 性能基准
├── translations/          # i18n
│   └── _source.csv        # 翻译源文件（zh_CN + en）
└── reports/               # CI 报告（baseline/perf/ui_audit）
```

---

## 核心架构（v0.5 重构后）

### 战斗循环

```
Timeline (tick 引擎, 0.5s/tick, 1x/2x/4x)
  └─ tick_advanced → BattleContext.advance_one_tick()
      ├─ player.chain.on_tick(ctx)
      │   ├─ 累积 current_card_progress
      │   ├─ progress >= effective_cost → card.fire() + gem ON_PLAY hook
      │   ├─ _advance_index → 下一张卡
      │   └─ 超过末尾 → _complete_cycle → gem ON_CYCLE hook → current_index=0（无缝循环）
      ├─ player.tick_statuses(ctx)
      ├─ for each enemy: chain.on_tick + tick_statuses
      └─ _check_victory()
```

**关键**: 无调息/修整阶段。8 张卡打完直接回第 1 张，触发 `cycle_completed` 信号。

### 底座与宝石

- **8 个固定底座**，每个 1 卡槽 + 1 宝石槽（遗物可扩展）
- `RunState.bases: Array[SlotData]` — 8 个底座实例
- `RunState.base_cards: Dictionary` — `{base_id: CardData}` 每底座 1 张卡
- `RunState.base_gems: Dictionary` — `{base_id: Array[GemData]}` 每底座的宝石
- `RunState.gems: Array[GemData]` — 玩家宝石背包

### 宝石触发时机

| Trigger | 时机 | 调用方式 |
|---------|------|---------|
| `PASSIVE` | 持续生效 | `Chain._effective_cost()` / `modify_damage()` 聚合 |
| `ON_PLAY` | 卡牌打出时 | `Chain._fire_gem_hook(idx, "on_card_played", ...)` |
| `ON_CYCLE` | 循环一周时 | `Chain._fire_gem_hook_all("on_cycle_completed", ...)` |

### 数据流

```
GameState.start_run()
  → RunState（8 bases + 10 deck cards + 4 starter gems）
  → BuildScene（玩家摆卡/镶宝石）
  → ChainComposer.compose(spec) → Result.layout: Array[ChainSlot]
  → BattleScene → player.chain.set_layout(result.layout)
  → 战斗开始
```

---

## 测试命令

```bash
# 运行全部测试（GUT）
godot --headless --path . -d -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# 运行单个测试文件
godot --headless --path . -d -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_chain.gd -gexit

# 平衡基线跑批
godot --headless --path . --script tests/baseline_runner.gd -- --count 1000 --out reports/baseline/baseline_v1.json

# 性能基准
godot --headless --path . --script tests/perf_battle_4x.gd

# 平衡 gate（CI 用）
godot --headless --path . --script tests/balance_gate.gd
```

**当前测试**: 9 脚本 / 70 用例。

---

## 代码约定

- **class_name**: 每个 `.gd` 文件顶部声明 `class_name`，Godot 全局可用
- **信号**: 通过 `EventBus` AutoLoad 中转，UI 不直接引用战斗对象
- **Resource**: 数据用 `.tres` 文件，脚本用 `class_name XXX extends Resource`
- **i18n**: 所有 UI 文本走 `tr("key")`，翻译源在 `translations/_source.csv`
- **存档 schema**: `RunState.serialize()` 输出 version 4，`SaveSystem._rehydrate()` 从 ID 重建引用
- **无 recovery**: 已删除调息/修整机制，不要重新引入 `RECOVERING` 状态

---

## 常见陷阱

1. **GDScript lambda 不能写外部 var** — 用 `Array[int]` 单元素绕开（见 test_chain.gd）
2. **`.tres` 中 `[sub_resource]` 必须在 `[resource]` 之前** — 否则加载失败
3. **`StatusInstance` duration=0 会立即过期** — 永久状态用 `-1`
4. **GUT 把 WARNING 当失败** — 未用参数要加 `_` 前缀（如 `_ctx`）
5. **`Chain.set_slots()` 生成空 layout** — 不含宝石，仅用于敌人和 fallback
6. **`Chain.set_layout()` 含宝石** — 玩家战斗走这条路径

---

## 当前待办

- [ ] 宝石获取渠道（商店/事件/战斗奖励掉落）
- [ ] 卡池铺量（17 → 50-80 张）
- [ ] 平衡 baseline 重做（8 卡环形循环 vs 旧 5 卡）
- [ ] 阶段 3 Roguelike 外壳（非线性地图/商店/事件/遗物）
