import fs from "node:fs/promises";
import path from "node:path";

const project = "/Users/happyelements/Documents/卡牌/project";
const designScript = "/Users/happyelements/Documents/卡牌/outputs/card_design_100/build_card_design_100.mjs";
const cardsDir = path.join(project, "data/cards/sword");
const i18nPath = path.join(project, "translations/_source.csv");

const typeMap = { "攻击": 0, "防御": 1, "增益": 2, "控制": 3, "召唤": 4, "特殊": 5 };
const rarityMap = { "普通": 0, "罕见": 1, "稀有": 2 };

function parsePlannedArray(source) {
  const start = source.indexOf("const planned = [");
  const marker = "\n];";
  const end = source.indexOf(marker, start);
  if (start < 0 || end < 0) throw new Error("planned array not found");
  const body = source.slice(source.indexOf("[", start), end + 2);
  // The array literal contains only JSON-compatible strings/numbers plus comments.
  const withoutComments = body.replace(/\/\/.*$/gm, "");
  return Function(`"use strict"; return (${withoutComments});`)();
}

function parseParams(text) {
  const out = {};
  for (const part of String(text ?? "").split(";")) {
    const trimmed = part.trim();
    if (!trimmed || !trimmed.includes("=")) continue;
    const [k, ...rest] = trimmed.split("=");
    let v = rest.join("=").trim();
    if (v === "true") out[k.trim()] = true;
    else if (v === "false") out[k.trim()] = false;
    else if (/^-?\d+(?:\.\d+)?$/.test(v)) out[k.trim()] = Number(v);
    else out[k.trim()] = v;
  }
  return out;
}

function gdValue(value) {
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") return String(value);
  if (typeof value === "string") {
    if (value === "") return '&""';
    if (/^[a-zA-Z0-9_]+$/.test(value)) return `&"${value}"`;
    return `"${value.replaceAll('"', '\\"')}"`;
  }
  return String(value);
}

function tagArray(tags) {
  return `[${tags.map((t) => `&"${t}"`).join(", ")}]`;
}

function timechainFields(row) {
  const params = parseParams(row.effectParams);
  const fields = {};
  const script = row.effectScript;
  const desc = row.descZh;
  const tags = new Set(row.tags.split(",").map((s) => s.trim()).filter(Boolean));

  if (script === "EffectAttack") {
    fields.damage = params.damage ?? 0;
    fields.hits = params.hits ?? 1;
  } else if (script === "EffectBuildup") {
    fields.charge = params.charge_amount ?? 0;
  } else if (script === "EffectDefense") {
    fields.shield = params.shield_amount ?? 0;
  } else if (script === "EffectPowerStrike") {
    fields.charge_consume = true;
    fields.charge_base_damage = params.base_damage ?? 0;
    fields.charge_multiplier = params.charge_multiplier ?? 0;
  } else if (script === "EffectComboChargeAttack") {
    fields.damage = params.damage ?? 0;
    fields.charge = params.charge_amount ?? 0;
  } else if (script === "EffectInterrupt") {
    fields.interrupt = true;
    fields.interrupt_damage = params.also_damage ?? 0;
    fields.interrupt_immune_duration = params.immune_duration ?? 4;
    fields.pierce_interrupt_resistance = params.pierce_resistance ?? false;
  } else if (script === "EffectEcho") {
    fields.echo_previous = params.copy_count ?? 1;
  }

  if (script.includes("Haste") || row.keywords.includes("加速")) {
    fields.haste_duration ??= params.haste_seconds ?? params.duration_seconds ?? params.duration ?? 1;
  }
  if (script.includes("NextCardHalfCost") || desc.includes("下一张牌 cost 减半")) fields.next_card_half_cost = true;
  if (script.includes("NextAttackEcho")) {
    fields.haste_duration = params.duration ?? 3;
    fields.next_tag_half_cost = "attack";
  }
  if (script.includes("NextCardCostReduction") || desc.includes("下一张牌 cost -1")) fields.next_card_cost_reduction = params.reduction ?? 1;
  if (script.includes("NextTagCostReduction") || script.includes("NextNonTagCostReduction")) {
    fields.next_tag_cost_reduction_tag = params.tag ?? "special";
    fields.next_tag_cost_reduction = params.reduction ?? 1;
  }
  if (script.includes("NextTagHalfCost")) {
    fields.next_tag_half_cost = params.tag ?? "attack";
  }
  if (script.includes("FlowDamage") || script.includes("FlowNthDamage")) {
    fields.next_tag_damage_bonus_tag = params.required_tag ?? params.tag ?? "attack";
    fields.next_tag_damage_bonus = params.bonus ?? 0;
  }
  if (script.includes("FlowCharge")) {
    fields.charge = params.charge ?? 1;
  }
  if (script.includes("FlowStatusStacks")) {
    fields.damage = params.damage ?? fields.damage ?? 0;
    fields.next_tag_status_bonus_tag = params.tag ?? "fire";
    fields.next_tag_status_bonus_status = params.status ?? "burn";
    fields.next_tag_status_bonus = params.bonus ?? 0;
  }
  if (script.includes("FlowNextEchoDamage")) {
    fields.next_tag_damage_bonus_tag = "attack";
    fields.next_tag_damage_bonus = params.bonus ?? 5;
  }
  if (script.includes("ApplyStatus") || script.includes("StatusAnd")) {
    if (params.status === "vulnerable" || params.status_id === "vulnerable") fields.vulnerable_duration = params.duration ?? 3;
  }
  if (desc.includes("迟滞")) fields.vulnerable_duration ||= Number(String(row.effectParams).match(/duration=(\d+)/)?.[1] ?? 2);
  if (desc.includes("燃烧")) {
    fields.burn_stacks ||= params.stacks ?? params.burn ?? Number(String(row.effectParams).match(/burn=(\d+)/)?.[1] ?? 1);
    fields.burn_duration ||= params.duration ?? 3;
  }
  if (script.includes("ExtendStatus")) fields.burn_extend = params.duration_bonus ?? 2;
  if (script.includes("DetonateBurn")) {
    fields.damage = params.damage ?? 18;
    fields.burn_detonate_ratio = params.ratio ?? 0.5;
  }
  if (script.includes("AttackIfPrevTag")) {
    fields.damage = params.damage ?? 0;
    fields.bonus_damage = params.bonus_damage ?? params.bonus ?? 0;
    fields.bonus_if_prev_tag = params.tag ?? "attack";
  }
  if (script.includes("AttackIfSelfStatus")) {
    fields.damage = params.damage ?? 0;
    fields.bonus_damage = params.bonus ?? 0;
    fields.bonus_if_self_status = params.status ?? "shield";
  }
  if (script.includes("AttackIfTargetStatus") || script.includes("AttackInterruptIfStatus")) {
    fields.damage = params.damage ?? 0;
    fields.bonus_damage = params.bonus ?? 0;
    fields.bonus_if_target_status = params.status ?? "vulnerable";
  }
  if (script.includes("AttackByTargetStatusStacks")) {
    fields.damage = params.damage ?? 0;
    fields.bonus_per_target_status_stack = params.status ?? "burn";
    fields.bonus_per_stack = params.per_stack ?? 1;
  }
  if (script.includes("AttackByDebuffKinds")) {
    fields.damage = params.damage ?? 0;
    fields.bonus_per_debuff_kind = params.per_debuff ?? 8;
  }
  if (script.includes("DefenseAndAttack")) {
    fields.shield = params.shield ?? 0;
    fields.damage = params.damage ?? 0;
  }
  if (script.includes("ShieldThenAttackIfShield")) {
    fields.shield = params.shield ?? 8;
    fields.damage = params.shield ?? 8;
    fields.shield_bonus_if_had_shield = true;
    fields.shield_bonus_damage_ratio = 1;
  }
  if (script.includes("AttackByShield")) {
    fields.shield_damage_ratio = 1;
    fields.shield = params.shield ?? 0;
  }
  if (script.includes("DefenseAndNextCostReduction")) {
    fields.shield = params.shield ?? 0;
    fields.next_card_cost_reduction = params.reduction ?? 1;
  }
  if (script.includes("ChargeWithPassive")) {
    fields.charge = params.charge ?? 2;
  }
  if (script.includes("ChargeAndHaste")) {
    fields.charge = params.charge ?? 1;
    fields.haste_duration = params.haste_seconds ?? 1;
  }
  if (script.includes("ChargeConditional")) {
    fields.charge = params.charge ?? 1;
    fields.bonus_charge_if_prev_tag = params.bonus_if_prev_tag ?? "attack";
  }
  if (script.includes("PowerStrikeRefund")) {
    fields.charge_consume = true;
    fields.charge_base_damage = params.base ?? 8;
    fields.charge_multiplier = params.mult ?? 2;
    fields.charge_refund_threshold = params.threshold ?? 3;
    fields.charge_refund = params.refund ?? 1;
  }
  if (script.includes("Preserve")) {
    fields.next_tag_half_cost = "charge_consume";
    fields.preserve_charge = params.preserve ?? 2;
  }
  if (script.includes("EchoFiltered")) fields.echo_previous = 1;
  if (script.includes("EchoPreviousN")) fields.echo_previous = params.count ?? 2;
  if (script.includes("EchoAndHaste")) {
    fields.echo_previous = 1;
    fields.echo_haste_on_success = params.haste ?? 2;
  }
  if (script.includes("CycleFireCounter")) {
    fields.cycle_damage_per_tag = "fire";
    fields.cycle_damage_per_tag_amount = params.damage_per_fire ?? 5;
  }
  if (script.includes("CyclePlayedCountReward")) {
    fields.cycle_threshold_played = params.threshold ?? 6;
    fields.cycle_threshold_heal = params.heal ?? 8;
    fields.cycle_threshold_haste = params.haste ?? 2;
  }
  if (script.includes("DefenseIfLastHeal")) {
    fields.shield = params.shield ?? 6;
    fields.cycle_heal = params.heal ?? 3;
  }
  if (script.includes("AttackByCycleShield")) {
    fields.damage = params.damage ?? 7;
    fields.bonus_damage = params.bonus ?? 2;
  }
  if (script.includes("DefenseAndRetainShield")) {
    fields.shield = params.shield ?? 20;
  }
  if (script.includes("TemporalEdict")) {
    fields.haste_duration = params.haste ?? 2;
    fields.next_card_half_cost = true;
  }
  if (desc.includes("恢复 8 生命")) fields.cycle_heal ||= 8;
  if (desc.includes("获得加速 2")) fields.cycle_haste ||= 2;

  return fields;
}

function passiveFields(row) {
  const p = parseParams(row.effectParams);
  if (!row.keywords.includes("固有")) return {};
  let tag = p.tag ?? "";
  if (row.descZh.includes("攻击牌")) tag = "attack";
  if (row.descZh.includes("充能消耗牌")) tag = "charge_consume";
  return {
    passive_adjacent_cost_reduction: p.reduction ?? 1,
    passive_adjacent_required_tag: tag,
  };
}

function makeTres(row) {
  const tags = row.tags.split(",").map((s) => s.trim()).filter(Boolean);
  const fields = timechainFields(row);
  const passives = passiveFields(row);
  const effectLines = Object.entries(fields)
    .filter(([, v]) => v !== "" && v !== 0 && v !== false)
    .map(([k, v]) => `${k} = ${gdValue(v)}`);
  const passiveLines = Object.entries(passives)
    .filter(([, v]) => v !== "" && v !== 0 && v !== false)
    .map(([k, v]) => `${k} = ${gdValue(v)}`);
  return `[gd_resource type="Resource" load_steps=3 format=3 uid="uid://card_${row.id}"]

[ext_resource type="Script" path="res://src/data_models/card_data.gd" id="1_data"]
[ext_resource type="Script" path="res://src/core/effects/effect_timechain.gd" id="2_fx"]

[sub_resource type="Resource" id="effect_1"]
script = ExtResource("2_fx")
${effectLines.join("\n")}

[resource]
script = ExtResource("1_data")
id = &"${row.id}"
display_name_key = "card.${row.id}.name"
desc_key = "card.${row.id}.desc"
cost = ${row.cost}
card_type = ${typeMap[row.type] ?? 0}
tags = ${tagArray(tags)}
rarity = ${rarityMap[row.rarity] ?? 0}
description_template = "${row.descZh.replaceAll('"', '\\"')}"
effect = SubResource("effect_1")
consumable = false
${passiveLines.join("\n")}
`;
}

function csvEscape(s) {
  return `"${String(s).replaceAll('"', '""')}"`;
}

const source = await fs.readFile(designScript, "utf8");
const planned = parsePlannedArray(source);
const rows = planned.map((r) => ({
  status: r[0], id: r[1], nameZh: r[2], nameEn: r[3], rarity: r[4], type: r[5],
  cost: r[6], archetype: r[7], tags: r[8], keywords: r[9], descZh: r[10],
  descEn: r[11], effectScript: r[12], effectParams: r[13], implementation: r[14], notes: r[15],
}));

for (const row of rows) {
  const out = path.join(cardsDir, `${row.id}.tres`);
  await fs.writeFile(out, makeTres(row), "utf8");
}

let i18n = await fs.readFile(i18nPath, "utf8");
const existingKeys = new Set(i18n.split(/\r?\n/).map((line) => line.split(",")[0]));
const additions = [];
for (const row of rows) {
  const nameKey = `card.${row.id}.name`;
  const descKey = `card.${row.id}.desc`;
  if (!existingKeys.has(nameKey)) additions.push(`${nameKey},${csvEscape(row.nameZh)},${csvEscape(row.nameEn)}`);
  if (!existingKeys.has(descKey)) additions.push(`${descKey},${csvEscape(row.descZh)},${csvEscape(row.descEn)}`);
}
for (const [key, zh, en] of [
  ["status.haste.name", "加速", "Haste"],
  ["status.haste.desc", "链条推进更快", "Chain advances faster"],
]) {
  if (!existingKeys.has(key)) additions.push(`${key},${csvEscape(zh)},${csvEscape(en)}`);
}
if (additions.length) {
  if (!i18n.endsWith("\n")) i18n += "\n";
  i18n += additions.join("\n") + "\n";
  await fs.writeFile(i18nPath, i18n, "utf8");
}

console.log(`materialized ${rows.length} planned cards`);
