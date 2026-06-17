# 阶段 1 验收漏项补完计划

> **范围**：路线图「阶段 1.8 验收清单」中**除团队试玩外**的所有未完成项。
> **目标**：让阶段 1 在工程层面真正过 Gate，再进入阶段 2。
> **不在范围**：5 人团队试玩、玩法是否爽决策点（→ 用户人工验证）。

---

## 一、现状盘点（基于代码扫描）

### ✅ 已经到位

| 项 | 证据 |
|---|---|
| 战斗核心 | `src/core/{timeline,chain,combatant,battle_context,battle_controller,battle_simulator,card_runtime,status}.gd` |
| 卡牌效果 | `src/core/effects/`（攻击/充能/蓄力/强力一击/防御/回响） |
| 起手卡组 + 扩展卡 | `data/cards/sword/*.tres`（15 张） |
| 5 个敌人 | `data/enemies/{slime,fire_imp,iron_golem,shadow_blade,stone_guard}.tres` |
| 战斗 UI | `scenes/battle/` + `src/ui/battle/` |
| 构筑 UI | `src/ui/build/` |
| 极简爬塔 | `src/meta/{map_generator,run_state,save_system}.gd` + `src/ui/map/` |
| 单元测试 | `tests/unit/test_{timeline,chain,combatant,effects,smoke}.gd` |
| 集成测试 | `tests/integration/test_{battle_simulator,balance_baseline,synergy_combos,e2e_run_flow}.gd` |
| Headless runner | `tests/headless_runner.gd` |
| CI（i18n + tests + 三平台 build） | `.github/workflows/ci.yml` |
| i18n 框架 | `translations/_source.csv` + 工具 `tools/i18n_*.py` |

### ❌ 待补漏项（路线图 §1.8 验收清单）

| 漏项 | 来源 | 当前状态 |
|---|---|---|
| **A. 1000 局 baseline 跑批 + 存档** | §1.7 / §1.8 | `reports/baseline/` 空目录 |
| **B. CI balance gate（警告级）** | §1.7 | CI 跑测试但没有 baseline 对比 |
| **C. 战斗加速 4x 不卡顿验证** | §1.8 | 无性能基准 |
| **D. 多分辨率 UI 巡检（1080p/1440p/1280×800/21:9）** | §1.8 | 无巡检脚本/截图 |
| **E. 一条 10 节点 + boss 的完整 demo 通玩证据** | §1.8 | 代码就位但无端到端通关跑批证明 |

---

## 二、漏项 → 任务分解

### A. 1000 局 baseline 跑批（核心）

**目标**：产出可复现的平衡基线 `reports/baseline/baseline_v1.json`，作为后续 CI balance gate 的对照基准。

**任务**：

1. **`tests/baseline_runner.gd`**（新建）— headless 跑批脚本
   - 入口：`godot --headless --path . --script tests/baseline_runner.gd -- --count 1000 --out reports/baseline/baseline_v1.json`
   - 复用现有 `BattleSimulator.simulate_batch`
   - 跑 3 个组合（与 `test_balance_baseline.gd` 一致）：
     - 起手卡组 vs Slime（25HP，弱）
     - 起手卡组 vs Stone Guard（40HP，中）
     - 起手卡组 vs Iron Golem / Fire Imp / Shadow Blade（其余 3 个敌人，各跑 1000 局）
   - 每组合记录：`win_rate / avg_ticks / avg_damage_dealt / avg_damage_taken / avg_cards_fired / hp_remaining_avg / hp_remaining_p50 / hp_remaining_p90`
   - 输出 JSON schema：

     ```json
     {
       "version": "v1",
       "generated_at": "2026-05-06T...",
       "godot_version": "4.6.x",
       "battle_count_per_matchup": 1000,
       "matchups": [
         {
           "name": "starter_vs_slime",
           "player": "starter_sword",
           "enemies": ["slime"],
           "win_rate": 1.0,
           "avg_ticks": 18.4,
           "avg_damage_dealt": 28.1,
           "avg_damage_taken": 4.2,
           "avg_cards_fired": 6.3,
           "hp_remaining": { "avg": 75.8, "p50": 76, "p90": 80 }
         }
       ]
     }
     ```

2. **`reports/baseline/README.md`**（新建）— 说明
   - 如何重跑、阈值含义、何时刷 baseline（卡数据/敌人/调参变更后重跑）

3. **跑一次，提交 `reports/baseline/baseline_v1.json`**

**QA 执行（验收时按此跑）**：
```bash
cd project
time godot --headless --path . --script tests/baseline_runner.gd -- --count 1000 --out reports/baseline/baseline_v1.json
```
**期望产物**：
- 退出码 0；总耗时 < 60 秒
- `project/reports/baseline/baseline_v1.json` 存在，结构匹配上述 schema，包含 7 个 matchup（5 个单敌人 + Stone Guard + Slime 已含其中；如重复则 5 个）
- 用 `python3 -c "import json; d=json.load(open('project/reports/baseline/baseline_v1.json')); assert d['battle_count_per_matchup']==1000; assert len(d['matchups'])>=5; print('OK')"` 校验通过
- 起手卡组对 Slime `win_rate >= 0.95`；对 Stone Guard `0.4 <= win_rate <= 0.85`；对全部 5 敌人加权 `win_rate >= 0.5`（任一不满足 → 固化数字 + 在 README 注明「待阶段 2 调」，不在本批次调数值）

---

### B. CI balance gate（警告级）

**目标**：CI 上每次 PR 跑小批量（200 局/组合，CI 友好），与 baseline 对比，**偏离超阈值打 warning**（不阻塞合并，符合路线图"警告级"要求）。

**任务**：

4. **`tests/balance_gate.gd`**（新建）— CI 入口
   - 读 `reports/baseline/baseline_v1.json`
   - 跑 200 局/组合（CI 内 < 30 秒）
   - 对比每个 matchup：
     - `win_rate` 偏移 > 0.10 → ⚠ warning
     - `avg_ticks` 偏移 > 30% → ⚠ warning
   - 把 warning 写到 `$GITHUB_STEP_SUMMARY`（Markdown 表格）
   - **退出码 0**（警告级，不阻塞）；只在脚本错误/baseline 缺失时退 1

5. **`.github/workflows/ci.yml`** 加 job
   - 名称：`balance_gate`
   - `needs: unit_tests`
   - 复用 cached godot binary
   - 把 markdown 摘要 append 到 `$GITHUB_STEP_SUMMARY`

**QA 执行（验收时按此跑）**：
```bash
# 本地正常情况
cd project
godot --headless --path . --script tests/balance_gate.gd 2>&1 | tee /tmp/gate.log
echo "exit=$?"
# 模拟 baseline 缺失
mv reports/baseline/baseline_v1.json reports/baseline/baseline_v1.json.bak
godot --headless --path . --script tests/balance_gate.gd; echo "exit=$?"
mv reports/baseline/baseline_v1.json.bak reports/baseline/baseline_v1.json
```
**期望产物**：
- 正常情况：退出码 0，`/tmp/gate.log` 无 `WARN`
- baseline 缺失：退出码 1
- CI 上 PR 触发 → GitHub Actions 摘要页（`$GITHUB_STEP_SUMMARY`）出现 Markdown 表格，列含 `matchup / baseline_win_rate / current_win_rate / delta / status`
- 故意把某卡 `damage` ×2 重跑 → 退出码 0 但摘要表显示 `⚠ DRIFT` 行（手动验证一次即可，不需要纳入自动 QA）

---

### C. 战斗加速 4x 性能基准

**目标**：证明 4x 加速下战斗逻辑不掉帧（路线图原文「4x 不卡顿」）。

**任务**：

6. **`tests/perf_battle_4x.gd`**（新建）— headless 性能测试
   - 用 `BattleSimulator` + 真实战斗（起手卡组 vs Stone Guard）
   - 测量纯逻辑跑 1000 tick 耗时（headless 无 UI，作为 lower bound）
   - 阈值：1000 tick 在本机 < 1 秒（@ 60fps 4x = 240 tick/sec，留足余量）
   - 输出 `reports/perf/battle_logic_v1.json`

**QA 执行（验收时按此跑）**：
```bash
cd project
godot --headless --path . --script tests/perf_battle_4x.gd 2>&1 | tee /tmp/perf.log
echo "exit=$?"
cat reports/perf/battle_logic_v1.json
```
**期望产物**：
- 退出码 0；`/tmp/perf.log` 包含一行 `[perf] 1000 ticks in X ms`，`X < 1000`
- `project/reports/perf/battle_logic_v1.json` 存在，含 `{"ticks": 1000, "wall_ms": <int>, "ticks_per_sec": <float>}` 三个字段
- `ticks_per_sec >= 240`（4x@60fps 的最低要求；实测应远高于此）
- **不在 CI 上跑**（CI runner 性能不稳）；脚本本地跑通后把 JSON 提交

> 注：UI 渲染层 4x 卡顿需要真机/Godot Editor 测试，不在本批次。本批次只验证逻辑层 ≥ 4x 安全余量。

---

### D. 多分辨率 UI 巡检脚本

**目标**：路线图要求「1080p / 1440p / 1280×800 / 21:9 四档分辨率 UI 巡检通过」。

**任务**：

7. **`tools/ui_resolution_check.gd`**（新建）— Godot 脚本（**非 headless**：截图需要渲染）
   - 用法：`godot --path . --script tools/ui_resolution_check.gd --quit-after 30`（带显示，CI 上跳过）
   - 实际场景文件路径（已校对仓库）：
     - 主菜单：`res://scenes/main_menu.tscn`
     - 战斗：`res://scenes/battle/battle_scene.tscn`
     - 构筑：`res://scenes/build/build_scene.tscn`
     - 地图：`res://scenes/map/map_scene.tscn`
   - 启动时依次设置 4 档分辨率（用 `DisplayServer.window_set_size()` + `get_viewport().size`）：`1920×1080`、`2560×1440`、`1280×800`、`3440×1440`
   - 每个分辨率依次加载 4 个场景，等 2 帧渲染后调 `get_viewport().get_texture().get_image().save_png()`
   - 截图保存到 `reports/ui_audit/{resolution}/{scene}.png`（如 `reports/ui_audit/1920x1080/battle.png`）
   - 静态检查：递归遍历场景树所有 `Control`，记录 `get_global_rect()` 与 viewport 大小对比；越界节点写到 `reports/ui_audit/{resolution}/overflow.json`
   - **任一分辨率有任意 Control 越界 → 退出 1**

8. **`reports/ui_audit/README.md`**（新建）— 巡检使用说明 + 提交基线截图

**QA 执行（验收时按此跑）**：
```bash
cd project
godot --path . --script tools/ui_resolution_check.gd 2>&1 | tee /tmp/ui_audit.log
echo "exit=$?"
ls reports/ui_audit/*/
find reports/ui_audit -name "*.png" | wc -l   # 期望 16
find reports/ui_audit -name "overflow.json" -exec cat {} \;
```
**期望产物**：
- 退出码 0
- 16 张 PNG（4 分辨率 × 4 场景），每张文件大小 > 10KB（非全黑）
- 4 个 `overflow.json` 文件，每个内容为 `{"resolution": "1920x1080", "overflows": []}`（空数组）
- `reports/ui_audit/README.md` 描述如何重跑

> 注：截图作为视觉基线提交（后续 PR 改 UI 后人工对比）；图像 diff 工具超出本批次范围。
> 注：本脚本需带显示运行（macOS/Linux 桌面），不在 CI 上跑。

---

### E. E2E run flow 通关证明

**目标**：路线图要求「一条 10 节点 + boss 的完整 demo 通玩」。已存在 `test_e2e_run_flow.gd`，需确认它真的覆盖完整 10 节点 + boss。

**任务**：

9. **审查并增强 `tests/integration/test_e2e_run_flow.gd`**
   - **真实结构（已校对 `src/meta/map_generator.gd`）**：**10 个普通节点（BATTLE 或 CAMPFIRE 混合）+ 第 11 个 BOSS**。其中节点 1-2 强制 BATTLE、节点 10 强制 CAMPFIRE、节点 5 可能 CAMPFIRE、其余 70% BATTLE / 30% CAMPFIRE。BOSS 用 `iron_golem`。
   - 当前需读代码确认 `test_e2e_run_flow.gd` 是否覆盖完整 11 节点序列。
   - 缺什么补什么（最低覆盖项）：
     - 用固定 seed 生成地图，断言节点数 == 11、最后一个 `node_type == BOSS`、节点 1-2 == BATTLE、节点 10 == CAMPFIRE
     - 顺序用 `BattleSimulator` 跑完所有 BATTLE 节点 + BOSS（CAMPFIRE 节点跳过战斗，仅推进 `RunState`）
     - 中途（节点 5 后）存档 → 销毁 RunState → 加载存档 → 断言 `current_node_index / hp / chain_slots` 完全一致
   - 跑通后把通关日志（每节点类型 + 战斗结果 + HP）写到 `reports/e2e/run_flow_v1.log`

**QA 执行（验收时按此跑）**：
```bash
cd project
godot --headless --path . --script tests/headless_runner.gd 2>&1 | tee /tmp/headless.log
# 或 gut：
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_e2e_run_flow.gd -gexit 2>&1 | tee /tmp/e2e.log
```
**期望产物**：
- 退出码 0
- `/tmp/e2e.log` 包含 `PASSED` 且无 `FAILED`
- `project/reports/e2e/run_flow_v1.log` 存在，包含 11 行节点记录 + 最终 `BOSS WIN`
- 存档断言通过：`current_node_index == 6, hp == X, chain_slots count == 5` 在加载前后一致

---

### F. 文档落地

10. **更新 `开发路线图.md`**
    - §1.8 验收清单逐项打勾（A–E 完成对应项），格式如 `- [x] 平衡报告：起手卡组 Act 1 胜率 50-70%`
    - §1.8「玩家是否爽」决策点保持 `- [ ]`，标注「（用户人工验证，工程批次外）」
    - 末尾追加 v0.3 版本记录：「v0.3 (2026-05-06) - 阶段 1 工程层验收 Gate 完成（除团队试玩外），新增 baseline / balance gate / 4x 性能 / UI 多分辨率巡检证据。」

11. **更新 `project/README.md`**
    - 加新章节「### 验收命令」，列出：
      - `godot --headless ... tests/baseline_runner.gd`（baseline 跑批）
      - `godot --headless ... tests/balance_gate.gd`（平衡 gate）
      - `godot --headless ... tests/perf_battle_4x.gd`（性能基准）
      - `godot --path . ... tools/ui_resolution_check.gd`（UI 巡检）
    - 加新章节「### reports/ 目录」，说明 baseline / perf / ui_audit / e2e 各自含义与刷新时机

**QA 执行（验收时按此跑）**：
```bash
# 文档存在性 & 关键内容校验
grep -c "v0.3" 开发路线图.md                                     # >= 1
grep -c "\[x\] 平衡报告" 开发路线图.md                            # >= 1
grep -c "baseline_runner" project/README.md                      # >= 1
grep -c "balance_gate" project/README.md                         # >= 1
grep -c "perf_battle_4x" project/README.md                       # >= 1
grep -c "ui_resolution_check" project/README.md                  # >= 1
test -f project/reports/baseline/README.md && echo "baseline README OK"
test -f project/reports/ui_audit/README.md && echo "ui_audit README OK"
```
**期望产物**：以上每条命令输出 `OK` 或匹配数 ≥ 1。

---

## 三、依赖关系

```
A (baseline 跑批)
 ├─→ B (CI gate，依赖 baseline JSON)
 └─→ F (路线图打勾，依赖证据)

C (性能基准)        独立，并行做
D (UI 巡检脚本)     独立，并行做
E (E2E 增强)        独立，并行做（但建议 A 之前做完，确认数据流没断）
F (文档)            最后做，汇总所有证据
```

**推荐执行顺序**：
1. E（先确认现有代码端到端能跑）
2. A（baseline 跑批）→ B（CI gate）
3. C + D（性能 + UI 巡检，可并行）
4. F（文档收尾）

---

## 四、风险登记

| 风险 | 严重度 | 对策 |
|---|---|---|
| 现有起手卡组对 Stone Guard 胜率失衡（< 40% 或 > 90%） | 中 | baseline 跑批后如果异常，**先固化数字**写进 baseline，标注「待阶段 2 调」，不在本批次调数值 |
| `test_e2e_run_flow.gd` 实际未真的走完 10 节点 | 中 | 任务 9 强制审查，缺什么补什么 |
| 1000 局批次本机跑太慢 | 低 | 改用 RNG 种子并发跑（Godot 单线程，串行 OK；实测 < 60s 即可） |
| CI balance gate 阈值定得太敏感导致天天 warning | 低 | 阈值留宽（win_rate ±0.10 / ticks ±30%），允许后续收紧 |
| 多分辨率截图脚本在 headless 下无法渲染真实 UI | 中 | 备选方案：用 Godot Editor 模式跑（CI 上跳过该 job，本地手动跑） |

---

## 五、总产出物清单（可逐项验收）

**新建文件**：
- `project/tests/baseline_runner.gd`
- `project/tests/balance_gate.gd`
- `project/tests/perf_battle_4x.gd`
- `project/tools/ui_resolution_check.gd`
- `project/reports/baseline/baseline_v1.json`
- `project/reports/baseline/README.md`
- `project/reports/perf/battle_logic_v1.json`
- `project/reports/ui_audit/README.md`
- `project/reports/ui_audit/{1080p,1440p,1280x800,21x9}/*.png`
- `project/reports/e2e/run_flow_v1.log`

**修改文件**：
- `project/.github/workflows/ci.yml`（加 balance_gate job）
- `project/tests/integration/test_e2e_run_flow.gd`（增强覆盖）
- `project/README.md`（命令说明）
- `开发路线图.md`（验收清单打勾 + v0.3）

---

## 六、估时

| 任务批次 | 预估 |
|---|---|
| E（E2E 审查 + 增强） | 30 分钟 |
| A（baseline 跑批 + 工具） | 60 分钟 |
| B（CI gate） | 45 分钟 |
| C（性能基准） | 30 分钟 |
| D（UI 巡检脚本） | 90 分钟 |
| F（文档） | 30 分钟 |
| **合计** | **约 5 小时** |

---

## 七、Out of Scope（明确不做）

- ❌ 5 人团队试玩组织（用户自行）
- ❌ 玩法是否爽的决策（用户自行）
- ❌ 数值平衡调优（baseline 异常也只固化数字，不调数值）
- ❌ UI 视觉打磨（巡检只查越界，不调样式）
- ❌ 任何阶段 2 的内容（traits/relics/extended slots/卡池扩展）
- ❌ 真机 4x 加速 UI 帧率测试（需要 Godot Editor + 真显示器）

---

## 待用户确认

1. **执行顺序**：按 E → A → B → C+D → F？还是另有偏好？
2. **CI balance gate 阈值**：win_rate ±0.10 / avg_ticks ±30%，OK 吗？
3. **UI 巡检 4 档分辨率**：1920×1080 / 2560×1440 / 1280×800 / 3440×1440，对吗？
4. **是否一次全做完**？还是按批次（先 E+A+B，跑通再做 C+D+F）？
5. **如发现 baseline 异常胜率（如 Stone Guard < 40%）**：固化数字 + 注释「待阶段 2 调」，OK？

确认后我创建 todo 开干。
