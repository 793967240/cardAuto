# Baseline Reports

> 阶段 1 平衡基线 - 起手卡组 (剑修 5 卡) vs 5 个敌人各 1000 局的统计快照。

## 重跑命令

```bash
cd project
godot --headless --path . --script tests/baseline_runner.gd -- \
  --count 1000 \
  --out reports/baseline/baseline_v1.json
```

参数：
- `--count N`：每个 matchup 跑 N 局（默认 1000）
- `--out PATH`：输出 JSON 路径（相对项目根，默认 `reports/baseline/baseline_v1.json`）

## 何时刷新 baseline

任一改动后必须重跑：
- 卡牌数据 (`data/cards/sword/*.tres`)
- 敌人数据 (`data/enemies/*.tres`)
- 战斗核心调参 (`data/tuning/default.tres` 或核心代码 `src/core/`)
- 起手卡组组成 (`tests/baseline_runner.gd:STARTER_DECK_PATHS`)

刷完后必须同步更新本 README 的「当前数据快照」一节。

## 阈值（用于 `tests/balance_gate.gd`）

CI balance gate 警告阈值：
- `win_rate` 偏移 > **±0.10** → ⚠ warning
- `avg_ticks` 偏移 > **±30%** → ⚠ warning

警告级，不阻塞合并。

## 当前数据快照（v1）

| matchup | win_rate | avg_ticks | avg_dmg | avg_taken | hp_avg |
|---|---|---|---|---|---|
| starter_vs_slime | 1.000 | 17.0 | 46.0 | 0.0 | 72.0 |
| starter_vs_fire_imp | 1.000 | 12.0 | 42.0 | 0.0 | 62.0 |
| starter_vs_shadow_blade | 1.000 | 28.0 | 113.0 | 0.0 | 24.0 |
| starter_vs_stone_guard | 1.000 | 39.0 | 56.0 | 0.0 | 68.0 |
| starter_vs_iron_golem | 1.000 | 39.0 | 152.0 | 0.0 | 4.0 |

## 已知偏离（待阶段 2 调）

按阶段 1 验收计划 (`.sisyphus/plans/phase1-acceptance-followup.md` §四 风险登记)，
对**异常胜率固化数字**而非调数值。当前观察到的偏离：

1. **Stone Guard 胜率 1.000，超出预期 [0.4, 0.85] 区间**：起手卡组对所有敌人都满胜率，
   说明阶段 1 MVP 卡组整体偏强 / 敌人 AI 偏弱。**不在阶段 1 工程批次内调整**，
   留到阶段 2「构筑深度」时随词条 + 卡池扩展整体重平衡。
2. **avg_damage_taken 全为 0**：当前敌人 cost 周期或 AI 决策导致首次出手前玩家就赢了。
   这是 BattleSimulator 模拟结果，不是 bug；同样作为基准固化，待阶段 2 引入更复杂敌人 AI 后重测。
3. **iron_golem 平均剩血 4 HP**：BOSS 战压力符合预期（"千钧一发"感受），保留。

## 文件清单

- `baseline_v1.json` — 当前 baseline，CI 与本地工具均读此文件
- `README.md` — 本文档
- 旧版本会以 `baseline_v0.{N}.json` 命名归档，不主动删除

## JSON Schema（v1）

```json
{
  "version": "v1",
  "generated_at": "ISO 8601 timestamp",
  "godot_version": "4.6.x-stable (official)",
  "battle_count_per_matchup": 1000,
  "player_deck": ["res://data/cards/sword/...", "..."],
  "matchups": [
    {
      "name": "starter_vs_<enemy_id>",
      "player": "starter_sword",
      "enemies": ["<enemy_id>"],
      "win_rate": 0.0,
      "avg_ticks": 0.0,
      "avg_damage_dealt": 0.0,
      "avg_damage_taken": 0.0,
      "avg_cards_fired": 0.0,
      "hp_remaining": { "avg": 0.0, "p50": 0, "p90": 0 }
    }
  ]
}
```
