import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const root = "/Users/happyelements/Documents/卡牌/project";
const cardsRoot = path.join(root, "data/cards/sword");
const i18nPath = path.join(root, "translations/_source.csv");
const outputPath = "/Users/happyelements/Documents/卡牌/outputs/card_design_100/card_design_100.xlsx";

const CARD_TYPES = ["攻击", "防御", "增益", "控制", "召唤", "特殊"];
const RARITIES = ["普通", "罕见", "稀有"];
const STATUS_EXISTING = "已实装";
const STATUS_PLANNED = "规划";

function parseCsvLine(line) {
  const out = [];
  let cur = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        cur += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === "," && !inQuotes) {
      out.push(cur);
      cur = "";
    } else {
      cur += ch;
    }
  }
  out.push(cur);
  return out;
}

async function loadI18n() {
  const text = await fs.readFile(i18nPath, "utf8");
  const map = new Map();
  for (const line of text.split(/\r?\n/).slice(1)) {
    if (!line.trim()) continue;
    const [key, zh = "", en = ""] = parseCsvLine(line);
    map.set(key, { zh, en });
  }
  return map;
}

function parseValue(raw) {
  const value = raw.trim();
  if (value.startsWith('&"') && value.endsWith('"')) return value.slice(2, -1);
  if (value.startsWith('"') && value.endsWith('"')) return value.slice(1, -1);
  if (value === "true") return true;
  if (value === "false") return false;
  if (value === "null") return null;
  if (/^-?\d+(?:\.\d+)?$/.test(value)) return Number(value);
  if (value.startsWith("[") && value.endsWith("]")) {
    const matches = [...value.matchAll(/&"([^"]+)"/g)].map((m) => m[1]);
    return matches.length ? matches : value;
  }
  if (value.startsWith("ExtResource")) return value.match(/ExtResource\("([^"]+)"\)/)?.[1] ?? value;
  if (value.startsWith("SubResource")) return value.match(/SubResource\("([^"]+)"\)/)?.[1] ?? value;
  return value;
}

function parseTres(text) {
  const extResources = new Map();
  const subResources = new Map();
  const resource = {};
  let section = "";
  let subId = "";

  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    if (trimmed.startsWith("[ext_resource")) {
      section = "ext";
      const id = trimmed.match(/id="([^"]+)"/)?.[1] ?? "";
      const resPath = trimmed.match(/path="([^"]+)"/)?.[1] ?? "";
      if (id) extResources.set(id, resPath);
      continue;
    }
    if (trimmed.startsWith("[sub_resource")) {
      section = "sub";
      subId = trimmed.match(/id="([^"]+)"/)?.[1] ?? "";
      if (subId) subResources.set(subId, {});
      continue;
    }
    if (trimmed === "[resource]") {
      section = "resource";
      subId = "";
      continue;
    }

    const eq = trimmed.indexOf("=");
    if (eq < 0) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = parseValue(trimmed.slice(eq + 1));
    if (section === "sub" && subId) subResources.get(subId)[key] = value;
    if (section === "resource") resource[key] = value;
  }
  return { extResources, subResources, resource };
}

function effectInfo(parsed) {
  const effect = parsed.subResources.get(parsed.resource.effect) ?? {};
  const scriptPath = parsed.extResources.get(effect.script) ?? "";
  const scriptName = scriptPath.split("/").pop()?.replace(".gd", "") ?? "";
  const params = Object.entries(effect)
    .filter(([k]) => k !== "script")
    .map(([k, v]) => `${k}=${v}`)
    .join("; ");
  return { scriptName, params };
}

function inferArchetype(tags, id) {
  const t = new Set(tags);
  if (t.has("echo")) return "回响";
  if (t.has("charge_consume") || t.has("charge")) return "充能";
  if (t.has("interrupt") || t.has("debuff") || t.has("control")) return "控制";
  if (t.has("defense")) return "防反";
  if (t.has("fire")) return "流火";
  if (t.has("multi_hit") || id.includes("feng") || id.includes("liu_yun")) return "快剑";
  return "剑修基础";
}

async function loadExistingCards(i18n) {
  const files = (await fs.readdir(cardsRoot)).filter((f) => f.endsWith(".tres")).sort();
  const rows = [];
  for (const fname of files) {
    const file = path.join(cardsRoot, fname);
    const parsed = parseTres(await fs.readFile(file, "utf8"));
    const r = parsed.resource;
    const name = i18n.get(r.display_name_key) ?? {};
    const desc = i18n.get(r.desc_key) ?? {};
    const rarity = RARITIES[Number(r.rarity ?? 0)] ?? String(r.rarity ?? 0);
    const type = CARD_TYPES[Number(r.card_type ?? 0)] ?? String(r.card_type ?? 0);
    const tags = Array.isArray(r.tags) ? r.tags : [];
    const { scriptName, params } = effectInfo(parsed);
    rows.push({
      status: STATUS_EXISTING,
      id: r.id,
      nameZh: name.zh ?? "",
      nameEn: name.en ?? "",
      rarity,
      type,
      cost: Number(r.cost ?? 0),
      archetype: inferArchetype(tags, String(r.id)),
      tags: tags.join(", "),
      keywords: "",
      descZh: desc.zh ?? r.description_template ?? "",
      descEn: desc.en ?? "",
      effectScript: scriptName,
      effectParams: params,
      implementation: "已有脚本",
      notes: "当前项目资源",
    });
  }
  return rows;
}

const planned = [
  // 普通 36
  ["规划","shan_ji","闪击","Flash Cut","普通","攻击",1,"快剑","sword, attack, haste","加速 1","造成 4 点伤害。获得加速 1。","Deal 4 damage. Gain Haste 1.","EffectAttackAndHaste","damage=4; haste_seconds=1; haste_rate=1.5","需要新增","快剑低费润滑"],
  ["规划","lian_ci","连刺","Double Thrust","普通","攻击",1,"快剑","sword, attack, multi_hit","多段","造成 2 次 2 点伤害。","Deal 2 damage twice.","EffectAttack","damage=2; hits=2","已有脚本","普通多段基准"],
  ["规划","kuai_jian","快剑","Quick Blade","普通","攻击",1,"快剑","sword, attack","无","造成 6 点伤害。","Deal 6 damage.","EffectAttack","damage=6; hits=1","已有脚本","高于刺剑的普通攻击"],
  ["规划","hui_feng","回风","Returning Wind","普通","增益",1,"快剑","sword, haste","急行","本周天结束前，下一张牌 cost 减半。","Until this cycle ends, halve the next card's cost.","EffectNextCardHalfCost","scope=this_cycle; target=next","需要新增","引导顺序构筑"],
  ["规划","jian_bu","剑步","Sword Step","普通","增益",1,"时序","sword, haste","加速 1","获得加速 1。","Gain Haste 1.","EffectHaste","duration_seconds=1; tick_rate=1.5","需要新增","最简单加速牌"],
  ["规划","shun_pu","顺劈","Flowing Cleave","普通","攻击",2,"快剑","sword, attack","流转","造成 9 点伤害。流转：下一张攻击牌 +2 伤害。","Deal 9 damage. Flow: next Attack gets +2 damage.","EffectAttackAndFlowDamage","damage=9; bonus=2; required_tag=attack","需要新增","普通流转样例"],
  ["规划","qing_mang","青芒","Verdant Gleam","普通","攻击",1,"快剑","sword, attack","无","造成 5 点伤害。","Deal 5 damage.","EffectAttack","damage=5; hits=1","已有脚本","基础攻击补量"],
  ["规划","san_luo_jian","散落剑","Scattered Blades","普通","攻击",2,"快剑","sword, attack, multi_hit","多段","造成 3 次 2 点伤害。","Deal 2 damage three times.","EffectAttack","damage=2; hits=3","已有脚本","红宝石潜在收益"],
  ["规划","yi_qi","一气","One Breath","普通","增益",1,"充能","sword, charge","充能","获得 1 层充能。若上一张是攻击牌，额外获得 1 层。","Gain 1 Charge. If the previous card was an Attack, gain 1 more.","EffectChargeConditional","charge=1; bonus_if_prev_tag=attack","需要新增","简单条件充能"],
  ["规划","yin_qi_zhan","引气斩","Qi-Draw Slash","普通","攻击",2,"充能","sword, attack, charge","充能","造成 6 点伤害，获得 1 层充能。","Deal 6 damage and gain 1 Charge.","EffectComboChargeAttack","damage=6; charge_amount=1","已有脚本","充能流普通桥牌"],
  ["规划","na_qi","纳气","Absorb Qi","普通","增益",2,"充能","sword, charge","充能","获得 2 层充能。","Gain 2 Charge.","EffectBuildup","charge_amount=2","已有脚本","蓄势同型补量"],
  ["规划","po_kong_zhan","破空斩","Skybreak Slash","普通","攻击",3,"充能","sword, attack, charge_consume","充能消耗","消耗所有充能，造成 8+充能×2 点伤害。","Consume all Charge. Deal 8 + Charge×2 damage.","EffectPowerStrike","base_damage=8; charge_multiplier=2","已有脚本","普通终结弱版"],
  ["规划","ning_qi","凝气","Condense Qi","普通","增益",2,"充能","sword, charge","流转","获得 1 层充能。流转：下一张充能牌额外 +1 充能。","Gain 1 Charge. Flow: next Charge card gains +1 extra Charge.","EffectChargeAndFlowCharge","charge=1; bonus=1","需要新增","长链铺垫"],
  ["规划","qie_mai","切脉","Sever Meridian","普通","控制",2,"控制","sword, control, debuff","迟滞","施加迟滞 2 tick。","Apply Slow for 2 ticks.","EffectApplyStatus","status_id=vulnerable; duration=2; stacks=1","已有脚本","轻控制"],
  ["规划","lan_jian","拦剑","Parry Blade","普通","控制",2,"控制","sword, attack, interrupt","打断","打断目标当前卡，附加 3 点伤害。","Interrupt target's current card and deal 3 damage.","EffectInterrupt","also_damage=3; immune_duration=4","已有脚本","低伤打断"],
  ["规划","zhen_jiao","镇脚","Rooting Step","普通","控制",1,"控制","sword, control, debuff","迟滞","施加迟滞 1 tick。","Apply Slow for 1 tick.","EffectApplyStatus","status_id=vulnerable; duration=1; stacks=1","已有脚本","1费控制"],
  ["规划","lie_kou","裂口","Open Wound","普通","攻击",2,"控制","sword, attack, debuff","破甲","造成 7 点伤害；若目标有迟滞，额外 +3。","Deal 7 damage; +3 if target is Slowed.","EffectAttackIfTargetStatus","damage=7; bonus=3; status=vulnerable","需要新增","控制 payoff"],
  ["规划","yu_bu","御步","Guard Step","普通","防御",1,"防反","sword, defense","护盾","获得 5 点护盾。","Gain 5 Shield.","EffectDefense","shield_amount=5","已有脚本","小盾"],
  ["规划","jian_ge","剑格","Sword Guard","普通","防御",2,"防反","sword, defense","护盾","获得 10 点护盾。","Gain 10 Shield.","EffectDefense","shield_amount=10","已有脚本","中盾"],
  ["规划","fan_shou","反手","Riposte","普通","攻击",1,"防反","sword, attack","防反","造成 4 点伤害。若你有护盾，额外 +3。","Deal 4 damage. If you have Shield, +3.","EffectAttackIfSelfStatus","damage=4; bonus=3; status=shield","需要新增","防反基础输出"],
  ["规划","shou_zhong_dai_gong","守中带攻","Guarded Strike","普通","防御",2,"防反","sword, defense, attack","双效果","获得 6 点护盾，造成 4 点伤害。","Gain 6 Shield and deal 4 damage.","EffectDefenseAndAttack","shield=6; damage=4","需要新增","普通双效果上限"],
  ["规划","jian_ying","剑影","Blade Shadow","普通","特殊",1,"回响","sword, echo","回响","复制前一张普通攻击牌。","Copy the previous common Attack card.","EffectEchoFiltered","copy_count=1; rarity=common; required_tag=attack","需要新增","低复杂回响"],
  ["规划","zhui_jian","追剑","Pursuing Blade","普通","攻击",1,"回响","sword, attack","邻位","若前一张是攻击牌，造成 7 点伤害，否则造成 4 点。","If previous card is an Attack, deal 7 damage; otherwise 4.","EffectAttackIfPrevTag","damage=4; bonus_damage=3; tag=attack","需要新增","顺序奖励"],
  ["规划","qian_yin","牵引","Lead-In","普通","特殊",1,"回响","sword, sequence","急行","本周天结束前，下一张特殊牌 cost -1。","Until this cycle ends, the next Special card costs 1 less.","EffectNextTagCostReduction","tag=special; reduction=1","需要新增","回响前置件"],
  ["规划","huo_xing","火星","Spark","普通","攻击",1,"流火","sword, attack, fire","燃烧","造成 3 点伤害，施加 1 层燃烧 3 tick。","Deal 3 damage. Apply 1 Burn for 3 ticks.","EffectAttackAndStatus","damage=3; status=burn; stacks=1; duration=3","需要新增","燃烧基础牌"],
  ["规划","yan_xi","炎息","Flame Breath","普通","攻击",2,"流火","sword, attack, fire","燃烧","造成 6 点伤害，施加 2 层燃烧 3 tick。","Deal 6 damage. Apply 2 Burn for 3 ticks.","EffectAttackAndStatus","damage=6; status=burn; stacks=2; duration=3","需要新增","燃烧中费"],
  ["规划","yin_ran","引燃","Ignite","普通","控制",1,"流火","sword, fire, debuff","燃烧","若目标已有燃烧，使其燃烧持续 +2 tick。","If target has Burn, extend it by 2 ticks.","EffectExtendStatus","status=burn; duration_bonus=2","需要新增","燃烧维护"],
  ["规划","liu_huo","流火","Flowing Fire","普通","攻击",2,"流火","sword, attack, fire","流转","造成 5 点伤害。流转：下一张火牌 +3 伤害。","Deal 5 damage. Flow: next Fire card gets +3 damage.","EffectAttackAndFlowDamage","damage=5; bonus=3; required_tag=fire","需要新增","火系流转"],
  ["规划","ding_shi","定时","Set Tempo","普通","增益",1,"时序","sword, time","急行","本周天结束前，下一张牌 cost -1。","Until this cycle ends, the next card costs 1 less.","EffectNextCardCostReduction","reduction=1; scope=this_cycle","需要新增","急行弱版"],
  ["规划","yi_pai","移拍","Shift Beat","普通","特殊",1,"时序","sword, time","流转","流转：后续第 2 张牌 +3 伤害。","Flow: the second later card gets +3 damage.","EffectFlowNthDamage","n=2; bonus=3","需要新增","时间轴教学"],
  ["规划","duan_pai","断拍","Broken Beat","普通","控制",2,"时序","sword, time, interrupt","打断","打断目标；若成功，获得加速 1。","Interrupt target. If successful, gain Haste 1.","EffectInterruptAndHasteOnSuccess","also_damage=0; haste_seconds=1","需要新增","控制+时序"],
  ["规划","xiao_zhou_tian","小周天","Minor Cycle","普通","增益",2,"时序","sword, time, charge","加速","获得 1 层充能和加速 1。","Gain 1 Charge and Haste 1.","EffectChargeAndHaste","charge=1; haste_seconds=1","需要新增","混合引擎"],
  ["规划","bu_fa","步法","Footwork","普通","增益",1,"时序","sword, time","固有","固有：后一张牌 cost -1，最低 1。","Innate: the next card costs 1 less, min 1.","PassiveAdjacentCostReduction","next=1; prev=0; reduction=1","需要新增","单向邻位"],
  ["规划","ce_shen","侧身","Side Step","普通","防御",1,"时序","sword, defense, time","急行","获得 4 点护盾。本周天结束前，下一张牌 cost -1。","Gain 4 Shield. Until this cycle ends, next card costs 1 less.","EffectDefenseAndNextCostReduction","shield=4; reduction=1","需要新增","防御时序"],
  ["规划","zhuan_shou","转手","Turnabout","普通","特殊",1,"时序","sword, time","流转","流转：下一张非攻击牌 cost -1。","Flow: the next non-Attack card costs 1 less.","EffectFlowNextNonTagCostReduction","excluded_tag=attack; reduction=1","需要新增","顺序调整"],
  ["规划","shou_shi","收势","Close Form","普通","防御",2,"时序","sword, defense, time","循环","获得 6 点护盾。若这是本周天最后一张牌，额外恢复 3 生命。","Gain 6 Shield. If this is the last card this cycle, heal 3.","EffectDefenseIfLastHeal","shield=6; heal=3","需要新增","长链收尾"],

  // 罕见 23
  ["规划","feng_chi","风驰","Windrush","罕见","增益",2,"快剑","sword, haste","加速 2","获得加速 2。","Gain Haste 2.","EffectHaste","duration_seconds=2; tick_rate=1.5","需要新增","加速标准牌"],
  ["规划","lian_huan_jian","连环剑","Chain Blade","罕见","攻击",2,"快剑","sword, attack, multi_hit","多段","造成 4 次 3 点伤害。","Deal 3 damage four times.","EffectAttack","damage=3; hits=4","已有脚本","多段核心"],
  ["规划","ru_yan","如燕","Swallow Step","罕见","特殊",1,"快剑","sword, haste, time","急行","本周天结束前，下一张攻击牌 cost 减半。","Until this cycle ends, halve the next Attack card's cost.","EffectNextTagHalfCost","tag=attack","需要新增","快剑大招前置"],
  ["规划","feng_juan_can_yun","风卷残云","Gale Sweep","罕见","攻击",3,"快剑","sword, attack, haste","加速","造成 14 点伤害。若你有加速，额外触发一次。","Deal 14 damage. If you have Haste, trigger once more.","EffectAttackAgainIfSelfStatus","damage=14; status=haste","需要新增","加速 payoff"],
  ["规划","qi_hai","气海","Qi Sea","罕见","增益",2,"充能","sword, charge","固有","获得 2 层充能。固有：后一张充能消耗牌 cost -1。","Gain 2 Charge. Innate: next Charge-consume card costs 1 less.","EffectChargeWithPassiveNextTagCost","charge=2; tag=charge_consume; reduction=1","需要新增","充能拼图"],
  ["规划","jian_dan","剑胆","Blade Resolve","罕见","增益",2,"充能","sword, charge","充能","获得 3 层充能。","Gain 3 Charge.","EffectBuildup","charge_amount=3","已有脚本","高效充能"],
  ["规划","lie_shan_pi","裂山劈","Mountain Rive","罕见","攻击",4,"充能","sword, attack, charge_consume","充能消耗","消耗所有充能，造成 16+充能×2.5 点伤害。","Consume all Charge. Deal 16 + Charge×2.5 damage.","EffectPowerStrike","base_damage=16; charge_multiplier=2.5","已有脚本","中级终结"],
  ["规划","hui_qi","回气","Qi Return","罕见","攻击",2,"充能","sword, attack, charge_consume","充能返还","消耗所有充能造成 8+充能×2 伤害；若消耗 3 层以上，返还 1 层。","Consume all Charge for 8 + Charge×2 damage; if 3+ spent, regain 1 Charge.","EffectPowerStrikeRefund","base=8; mult=2; threshold=3; refund=1","需要新增","循环性充能"],
  ["规划","feng_xue","封穴","Seal Point","罕见","控制",2,"控制","sword, control, debuff","迟滞","施加迟滞 4 tick。","Apply Slow for 4 ticks.","EffectApplyStatus","status_id=vulnerable; duration=4; stacks=1","已有脚本","高效迟滞"],
  ["规划","po_zhen","破阵","Formation Breaker","罕见","攻击",3,"控制","sword, attack, debuff","破甲","造成 13 点伤害。若目标有迟滞，打断目标。","Deal 13 damage. If target is Slowed, interrupt it.","EffectAttackInterruptIfStatus","damage=13; status=vulnerable","需要新增","控制组合"],
  ["规划","kong_ming_jian","空明剑","Clear Void Blade","罕见","控制",2,"控制","sword, attack, interrupt","打断","打断目标，附加 8 点伤害。","Interrupt target and deal 8 damage.","EffectInterrupt","also_damage=8; immune_duration=4","已有脚本","虚空剑升级横向版"],
  ["规划","zhen_mai","镇脉","Meridian Lock","罕见","控制",3,"控制","sword, control, debuff","迟滞","施加迟滞 3 tick。流转：下一张攻击牌对迟滞目标 +6 伤害。","Apply Slow 3 ticks. Flow: next Attack deals +6 to Slowed targets.","EffectStatusAndFlowDamageIfStatus","status=vulnerable; duration=3; bonus=6","需要新增","控制铺垫"],
  ["规划","xuan_jia","玄甲","Mystic Guard","罕见","防御",2,"防反","sword, defense","护盾","获得 16 点护盾。","Gain 16 Shield.","EffectDefense","shield_amount=16","已有脚本","高效防御"],
  ["规划","fan_zhen","反震","Rebound","罕见","防御",2,"防反","sword, defense, attack","防反","获得 8 点护盾。若你已有护盾，造成等量伤害。","Gain 8 Shield. If you already had Shield, deal that much damage.","EffectShieldThenAttackIfShield","shield=8","需要新增","盾转伤"],
  ["规划","cang_feng_shou","藏锋守","Hidden Edge Guard","罕见","防御",2,"防反","sword, defense, time","固有","获得 10 点护盾。固有：前一张攻击牌 cost -1。","Gain 10 Shield. Innate: previous Attack costs 1 less.","EffectDefenseWithPassivePrevTagCost","shield=10; tag=attack; reduction=1","需要新增","邻位防反"],
  ["规划","yu_jian_fan_ji","御剑反击","Guarded Riposte","罕见","攻击",2,"防反","sword, attack, defense","防反","造成 7 点伤害；本周天每获得过 5 点护盾，额外 +2。","Deal 7 damage; +2 for each 5 Shield gained this cycle.","EffectAttackByCycleShield","damage=7; per_shield=5; bonus=2","需要新增","需要战斗统计"],
  ["规划","shuang_xiang","双响","Double Echo","罕见","特殊",2,"回响","sword, echo","回响","复制前一张非回响牌。","Copy the previous non-Echo card.","EffectEcho","copy_count=1","已有脚本","现有回响的横向命名"],
  ["规划","jian_ming","剑鸣","Blade Resonance","罕见","特殊",2,"回响","sword, echo, time","固有","固有：相邻攻击牌 cost -1，最低 1。","Innate: adjacent Attack cards cost 1 less, min 1.","PassiveAdjacentTagCostReduction","tag=attack; reduction=1","需要新增","核心拼图"],
  ["规划","yu_yin","余音","Aftertone","罕见","特殊",1,"回响","sword, echo","流转","流转：下一张被复制的牌 +5 伤害。","Flow: the next copied card gets +5 damage.","EffectFlowNextEchoDamage","bonus=5","需要新增","回响 payoff"],
  ["规划","ran_jian","燃剑","Burning Blade","罕见","攻击",2,"流火","sword, attack, fire","燃烧","造成 9 点伤害。目标每有 1 层燃烧，额外 +1。","Deal 9 damage. +1 per Burn stack on target.","EffectAttackByTargetStatusStacks","damage=9; status=burn; per_stack=1","需要新增","燃烧 payoff"],
  ["规划","huo_yu","火狱","Flame Prison","罕见","控制",3,"流火","sword, fire, debuff","燃烧/迟滞","施加 3 层燃烧 4 tick 和迟滞 2 tick。","Apply 3 Burn for 4 ticks and Slow for 2 ticks.","EffectApplyTwoStatuses","burn=3/4; vulnerable=1/2","需要新增","火控混合"],
  ["规划","chi_xiao","赤霄","Red Firmament","罕见","攻击",3,"流火","sword, attack, fire","流转","造成 12 点伤害。流转：下一张火牌施加的燃烧 +2。","Deal 12 damage. Flow: next Fire card applies +2 Burn.","EffectAttackAndFlowStatusStacks","damage=12; tag=fire; status=burn; bonus=2","需要新增","火系引擎"],
  ["规划","shi_ling","时令","Timing Order","罕见","特殊",2,"时序","sword, time","固有","固有：相邻牌 cost -1，最低 1。","Innate: adjacent cards cost 1 less, min 1.","PassiveAdjacentCostReduction","prev=1; next=1; reduction=1","需要新增","用户提议核心"],

  // 稀有 17
  ["规划","wu_bu_yi_sha","五步一杀","Five-Step Kill","稀有","攻击",4,"快剑","sword, attack, haste","加速 payoff","造成 24 点伤害。若你有加速，此牌 cost 减半。","Deal 24 damage. If you have Haste, this card's cost is halved.","EffectAttackSelfStatusHalfCost","damage=24; status=haste","需要新增","快剑终结"],
  ["规划","feng_lei_yin","风雷引","Wind-Thunder Lead","稀有","增益",2,"快剑","sword, haste, time","加速 3","获得加速 3。本周天下一张攻击牌额外触发一次。","Gain Haste 3. The next Attack this cycle triggers once more.","EffectHasteAndNextAttackEcho","duration=3; copy_count=1","需要新增","快剑稀有引擎"],
  ["规划","wan_jian_gui_zong","万剑归宗","Ten Thousand Blades","稀有","攻击",5,"快剑","sword, attack, multi_hit","多段","造成 8 次 3 点伤害。","Deal 3 damage eight times.","EffectAttack","damage=3; hits=8","已有脚本","多段终局"],
  ["规划","tai_xu_ju_qi","太虚聚气","Void Qi Condensation","稀有","增益",3,"充能","sword, charge, time","固有","获得 4 层充能。固有：相邻充能消耗牌 cost -1。","Gain 4 Charge. Innate: adjacent Charge-consume cards cost 1 less.","EffectChargeWithPassiveAdjacentTagCost","charge=4; tag=charge_consume; reduction=1","需要新增","充能核心拼图"],
  ["规划","kai_tian_zhan","开天斩","Heaven Splitter","稀有","攻击",5,"充能","sword, attack, charge_consume","充能消耗","消耗所有充能，造成 24+充能×4 点伤害。","Consume all Charge. Deal 24 + Charge×4 damage.","EffectPowerStrike","base_damage=24; charge_multiplier=4","已有脚本","大终结"],
  ["规划","qi_zhuan","气转","Qi Transposition","稀有","特殊",2,"充能","sword, charge, time","急行","本周天结束前，下一张消耗充能的牌 cost 减半，且不消耗前 2 层充能。","Until this cycle ends, halve next Charge-consume card cost and preserve 2 Charge.","EffectNextChargeConsumeHalfCostAndPreserve","preserve=2","需要新增","爆发组合件"],
  ["规划","sui_xing_jian","碎星剑","Starbreaker Blade","稀有","控制",4,"控制","sword, attack, interrupt","穿透打断","穿透打断目标，附加 18 点伤害。","Pierce-interrupt target and deal 18 damage.","EffectInterrupt","also_damage=18; immune_duration=4; pierce_resistance=true","已有脚本","Boss 反制"],
  ["规划","tian_luo","天罗","Celestial Net","稀有","控制",3,"控制","sword, control, debuff","迟滞","施加迟滞 6 tick。目标本周天下一张牌 cost 额外 +1。","Apply Slow 6 ticks. Target's next card this cycle costs +1 more.","EffectSlowAndNextEnemyCostUp","duration=6; next_cost_up=1","需要新增","控制稀有"],
  ["规划","zhan_nian","斩念","Thought Sever","稀有","攻击",3,"控制","sword, attack, debuff","状态 payoff","造成 12 点伤害。目标每有一种负面状态，额外 +8。","Deal 12 damage. +8 per debuff on target.","EffectAttackByDebuffKinds","damage=12; per_debuff=8","需要新增","控制收束"],
  ["规划","bu_mie_jian_xin","不灭剑心","Undying Sword Heart","稀有","防御",3,"防反","sword, defense","护盾","获得 20 点护盾。周天结束时保留一半护盾。","Gain 20 Shield. Keep half your Shield at cycle end.","EffectDefenseAndRetainShield","shield=20; retain_ratio=0.5","需要新增","防反核心"],
  ["规划","xuan_wu_fan","玄武反","Black Tortoise Counter","稀有","攻击",3,"防反","sword, attack, defense","盾转伤","造成等同当前护盾的伤害，然后获得 8 点护盾。","Deal damage equal to current Shield, then gain 8 Shield.","EffectAttackByShieldThenDefense","shield=8","需要新增","防反终结"],
  ["规划","jian_yu_tong_xin","剑与同心","Blade Unity","稀有","特殊",3,"回响","sword, echo","回响","复制前两张非回响牌。","Copy the previous two non-Echo cards.","EffectEchoPreviousN","count=2; exclude=echo","需要新增","回响终局"],
  ["规划","kong_gu_hui_xiang","空谷回响","Valley Echo","稀有","特殊",2,"回响","sword, echo, time","固有","固有：前后两张牌 cost -1。若此卡复制成功，获得加速 2。","Innate: adjacent cards cost 1 less. If this copies successfully, gain Haste 2.","EffectEchoAndHasteWithPassiveAdjacentCost","reduction=1; haste=2","需要新增","时间轴回响核心"],
  ["规划","fen_tian","焚天","Skyfire","稀有","攻击",4,"流火","sword, attack, fire","燃烧引爆","造成 18 点伤害。引爆目标燃烧，立即结算剩余燃烧伤害的一半。","Deal 18 damage. Detonate Burn for half its remaining damage.","EffectAttackDetonateBurn","damage=18; ratio=0.5","需要新增","火系终结"],
  ["规划","ye_huo_lun","业火轮","Karmic Fire Wheel","稀有","特殊",3,"流火","sword, fire, time","循环","本周天每打出一张火牌，周天结束时对敌人造成 5 点伤害。","Each Fire card played this cycle adds 5 end-cycle damage.","EffectCycleFireCounter","damage_per_fire=5","需要新增","长链火系"],
  ["规划","shi_xu_ling","时序令","Temporal Edict","稀有","特殊",2,"时序","sword, time","加速/急行","获得加速 2。本周天结束前，每打出 3 张牌，下一张牌 cost 减半。","Gain Haste 2. Until this cycle ends, every 3 cards played halves the next card's cost.","EffectTemporalEdict","haste=2; every=3","需要新增","时序稀有核心"],
  ["规划","tai_yi_lun","太一轮","Grand Cycle","稀有","特殊",4,"时序","sword, time","循环","周天结束时，若本周天打出了 6 张以上牌，恢复 8 生命并获得加速 2。","At cycle end, if 6+ cards were played, heal 8 and gain Haste 2.","EffectCyclePlayedCountReward","threshold=6; heal=8; haste=2","需要新增","长链时序 payoff"],
];

function objectFromPlanned(row) {
  const [status, id, nameZh, nameEn, rarity, type, cost, archetype, tags, keywords, descZh, descEn, effectScript, effectParams, implementation, notes] = row;
  return { status, id, nameZh, nameEn, rarity, type, cost, archetype, tags, keywords, descZh, descEn, effectScript, effectParams, implementation, notes };
}

function countBy(rows, key) {
  const m = new Map();
  for (const row of rows) m.set(row[key], (m.get(row[key]) ?? 0) + 1);
  return [...m.entries()].sort((a, b) => String(a[0]).localeCompare(String(b[0])));
}

const i18n = await loadI18n();
const existing = await loadExistingCards(i18n);
const existingIds = new Set(existing.map((row) => row.id));
const remainingPlanned = planned.map(objectFromPlanned).filter((row) => !existingIds.has(row.id));
const allRows = [...existing, ...remainingPlanned];

const workbook = Workbook.create();
const cards = workbook.worksheets.add("100卡设计");
const keywords = workbook.worksheets.add("关键词规则");
const summary = workbook.worksheets.add("统计");

const headers = ["状态","ID","中文名","英文名","稀有度","类型","Cost","流派","Tags","关键词","中文描述","英文描述","效果脚本","效果参数","实现状态","设计备注"];
const data = [headers, ...allRows.map((r) => headers.map((h) => ({
  "状态": r.status, "ID": r.id, "中文名": r.nameZh, "英文名": r.nameEn, "稀有度": r.rarity,
  "类型": r.type, "Cost": r.cost, "流派": r.archetype, "Tags": r.tags, "关键词": r.keywords,
  "中文描述": r.descZh, "英文描述": r.descEn, "效果脚本": r.effectScript, "效果参数": r.effectParams,
  "实现状态": r.implementation, "设计备注": r.notes,
}[h])))];
cards.getRangeByIndexes(0, 0, data.length, headers.length).values = data;
cards.getRange("A1:P1").format.fill.color = "#1F2937";
cards.getRange("A1:P1").format.font.color = "#FFFFFF";
cards.getRange("A1:P1").format.font.bold = true;
cards.getRange("A:P").format.font.name = "Arial";
cards.getRange("A:P").format.font.size = 10;
cards.freezePanes.freezeRows(1);
for (const col of ["K:K","L:L","N:N","P:P"]) cards.getRange(col).format.wrapText = true;
const widths = [70,150,100,140,70,70,55,85,190,160,300,300,190,260,90,220];
for (let i = 0; i < widths.length; i += 1) {
  const col = String.fromCharCode("A".charCodeAt(0) + i);
  cards.getRange(`${col}:${col}`).format.columnWidth = widths[i];
}
const rarityFill = { "普通": "#E5E7EB", "罕见": "#DBEAFE", "稀有": "#FEF3C7" };
const statusFill = { [STATUS_EXISTING]: "#DCFCE7", [STATUS_PLANNED]: "#F3F4F6" };
for (let i = 0; i < allRows.length; i += 1) {
  const r = allRows[i];
  const rowNum = i + 2;
  cards.getRange(`A${rowNum}`).format.fill.color = statusFill[r.status] ?? "#FFFFFF";
  cards.getRange(`E${rowNum}`).format.fill.color = rarityFill[r.rarity] ?? "#FFFFFF";
}

const keywordRows = [
  ["关键词","规则文本","设计用途","建议实现"],
  ["加速 N","接下来 N 秒内己方时间流速提高，例如基础 1 tick/s 时，加速期间变为 1.5 tick/s。","提高整条链推进速度，服务快剑/时序流。","新增 haste 状态；Chain/Tick 推进按时间流速累计进度。"],
  ["急行","本周天结束前，下一张符合条件的牌 cost 减半，最低 1。","制造明确的顺序组合，如急行接大招。","新增 next-card modifier，循环结束清除。"],
  ["固有：邻位减时","此卡前后或指定相邻牌 cost -1，最低 1。","让玩家调整卡牌位置形成构筑拼图。","ChainComposer 编译 layout 时注入 passive modifier。"],
  ["流转","本周天结束前，为后续某张或某类牌附加一次性奖励。","服务长链和顺序规划。","新增 cycle-scoped modifier 队列，命中后消费。"],
  ["燃烧","每 tick 受到层数伤害，持续指定 tick。","流火/延迟流核心状态。","已有 Status burn 支持，部分复合效果需新增脚本。"],
  ["穿透打断","可无视 Boss 打断抗性重置目标当前卡进度。","Boss 反制和高稀有控制牌。","EffectInterrupt 已有 pierce_resistance 参数。"],
];
keywords.getRangeByIndexes(0, 0, keywordRows.length, 4).values = keywordRows;
keywords.getRange("A1:D1").format.fill.color = "#1F2937";
keywords.getRange("A1:D1").format.font.color = "#FFFFFF";
keywords.getRange("A1:D1").format.font.bold = true;
keywords.getRange("A:D").format.font.name = "Arial";
keywords.getRange("B:D").format.wrapText = true;
keywords.getRange("A:A").format.columnWidth = 130;
keywords.getRange("B:B").format.columnWidth = 430;
keywords.getRange("C:C").format.columnWidth = 260;
keywords.getRange("D:D").format.columnWidth = 360;

const summaryRows = [
  ["目标","数量"],
  ["卡牌总数", allRows.length],
  ["普通目标", 50],
  ["罕见目标", 30],
  ["稀有目标", 20],
  ["", ""],
  ["按稀有度", "数量"],
  ...countBy(allRows, "rarity"),
  ["", ""],
  ["按状态", "数量"],
  ...countBy(allRows, "status"),
  ["", ""],
  ["按流派", "数量"],
  ...countBy(allRows, "archetype"),
  ["", ""],
  ["按实现状态", "数量"],
  ...countBy(allRows, "implementation"),
];
summary.getRangeByIndexes(0, 0, summaryRows.length, 2).values = summaryRows;
summary.getRange("A1:B1").format.fill.color = "#1F2937";
summary.getRange("A1:B1").format.font.color = "#FFFFFF";
summary.getRange("A1:B1").format.font.bold = true;
summary.getRange("A:B").format.font.name = "Arial";
summary.getRange("A:A").format.columnWidth = 180;
summary.getRange("B:B").format.columnWidth = 90;

const preview = await workbook.inspect({
  kind: "table",
  range: "统计!A1:B30",
  include: "values",
  tableMaxRows: 30,
  tableMaxCols: 2,
});
console.log(preview.ndjson);
const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "formula error scan",
});
console.log(errors.ndjson);
await workbook.render({ sheetName: "100卡设计", range: "A1:H15", scale: 1 });
await workbook.render({ sheetName: "100卡设计", range: "I1:P15", scale: 1 });
await workbook.render({ sheetName: "关键词规则", range: "A1:D8", scale: 1 });
await workbook.render({ sheetName: "统计", range: "A1:B30", scale: 1 });

await fs.mkdir(path.dirname(outputPath), { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(outputPath);
