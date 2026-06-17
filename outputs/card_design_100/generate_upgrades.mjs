import fs from "node:fs/promises";
import path from "node:path";

const project = "/Users/happyelements/Documents/卡牌/project";
const cardsDir = path.join(project, "data/cards/sword");
const upgradesDir = path.join(cardsDir, "upgrades");
const i18nPath = path.join(project, "translations/_source.csv");

function parseValue(raw) {
  const value = raw.trim();
  if (value.startsWith('&"') && value.endsWith('"')) return value.slice(2, -1);
  if (value.startsWith('"') && value.endsWith('"')) return value.slice(1, -1);
  if (value === "true") return true;
  if (value === "false") return false;
  if (/^-?\d+(?:\.\d+)?$/.test(value)) return Number(value);
  if (value.startsWith("[") && value.endsWith("]")) return [...value.matchAll(/&"([^"]+)"/g)].map((m) => m[1]);
  if (value.startsWith("ExtResource")) return value.match(/ExtResource\("([^"]+)"\)/)?.[1] ?? value;
  if (value.startsWith("SubResource")) return value.match(/SubResource\("([^"]+)"\)/)?.[1] ?? value;
  return value;
}

function gdValue(value) {
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") return String(Number.isInteger(value) ? value : Number(value.toFixed(2)));
  if (Array.isArray(value)) return `[${value.map((t) => `&"${t}"`).join(", ")}]`;
  if (typeof value === "string") {
    if (value === "") return '&""';
    if (/^[a-zA-Z0-9_]+$/.test(value)) return `&"${value}"`;
    return `"${value.replaceAll('"', '\\"')}"`;
  }
  return String(value);
}

function parseTres(text) {
  const extResources = [];
  const sub = {};
  const res = {};
  let section = "";
  let inEffect = false;
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    if (trimmed.startsWith("[ext_resource")) {
      const id = trimmed.match(/id="([^"]+)"/)?.[1] ?? "";
      const p = trimmed.match(/path="([^"]+)"/)?.[1] ?? "";
      extResources.push({ id, path: p, raw: trimmed });
      section = "ext";
      continue;
    }
    if (trimmed.startsWith("[sub_resource")) {
      section = "sub";
      inEffect = true;
      continue;
    }
    if (trimmed === "[resource]") {
      section = "resource";
      inEffect = false;
      continue;
    }
    const eq = trimmed.indexOf("=");
    if (eq < 0) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = parseValue(trimmed.slice(eq + 1));
    if (section === "sub" && inEffect) sub[key] = value;
    if (section === "resource") res[key] = value;
  }
  const effectExt = extResources.find((e) => e.id === sub.script);
  const dataExt = extResources.find((e) => e.id === "1_data") ?? extResources.find((e) => e.path.includes("card_data.gd"));
  return { extResources, effect: sub, resource: res, effectPath: effectExt?.path ?? "", dataPath: dataExt?.path ?? "res://src/data_models/card_data.gd" };
}

function csvParseLine(line) {
  const out = [];
  let cur = "";
  let q = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (q && line[i + 1] === '"') { cur += '"'; i++; } else q = !q;
    } else if (ch === "," && !q) {
      out.push(cur); cur = "";
    } else cur += ch;
  }
  out.push(cur);
  return out;
}

async function loadI18n() {
  const text = await fs.readFile(i18nPath, "utf8");
  const map = new Map();
  for (const line of text.split(/\r?\n/).slice(1)) {
    if (!line.trim()) continue;
    const [key, zh = "", en = ""] = csvParseLine(line);
    map.set(key, { zh, en });
  }
  return { text, map };
}

function csvEscape(s) {
  return `"${String(s).replaceAll('"', '""')}"`;
}

function upgradeEffect(effect, effectPath, tags) {
  const out = { ...effect };
  delete out.script;
  let changed = false;
  const bumpInt = (key, amount) => {
    if (typeof out[key] === "number") { out[key] += amount; changed = true; }
  };
  const bumpFloat = (key, amount) => {
    if (typeof out[key] === "number") { out[key] = Number((out[key] + amount).toFixed(2)); changed = true; }
  };

  bumpInt("damage", tags.includes("multi_hit") ? 1 : 3);
  if (!("damage" in out) && tags.includes("attack")) { out.damage = 4; changed = true; }
  bumpInt("hits", tags.includes("multi_hit") ? 1 : 0);
  bumpInt("base_damage", 4);
  bumpInt("charge_base_damage", 4);
  bumpFloat("charge_multiplier", 0.5);
  bumpFloat("charge_multiplier", effectPath.includes("effect_power_strike") ? 0.5 : 0);
  bumpInt("shield_amount", 4);
  bumpInt("shield", 4);
  bumpInt("charge_amount", 1);
  bumpInt("charge", 1);
  bumpInt("burn_stacks", 1);
  bumpInt("burn_duration", 1);
  bumpInt("vulnerable_duration", 1);
  bumpInt("interrupt_damage", 3);
  bumpInt("also_damage", 3);
  bumpInt("haste_duration", 1);
  bumpInt("next_card_cost_reduction", 1);
  bumpInt("next_tag_damage_bonus", 2);
  bumpInt("next_tag_status_bonus", 1);
  bumpInt("cycle_heal", 3);
  bumpInt("cycle_damage", 4);
  bumpInt("cycle_damage_per_tag_amount", 2);
  bumpInt("echo_haste_on_success", 1);
  if (out.echo_previous === 1) { out.echo_previous = 2; changed = true; }
  if (!changed && effectPath.includes("effect_echo")) { out.copy_count = Number(out.copy_count ?? 1) + 1; changed = true; }
  if (!changed && tags.includes("defense")) { out.shield = 6; changed = true; }
  if (!changed) { out.next_card_cost_reduction = 1; }
  return out;
}

function upgradeCost(cost, effect, tags) {
  if (cost >= 3 && !tags.includes("charge_consume")) return cost - 1;
  if (cost >= 4) return cost - 1;
  return cost;
}

function buildTres(card, upgradedEffect, upgradedCost, descZh, descEn) {
  const r = card.resource;
  const id = `${r.id}_plus`;
  const effectPath = card.effectPath || "res://src/core/effects/effect_timechain.gd";
  const effectLines = Object.entries(upgradedEffect)
    .filter(([k]) => k !== "script")
    .map(([k, v]) => `${k} = ${gdValue(v)}`);
  const passiveReduction = Number(r.passive_adjacent_cost_reduction ?? 0);
  const upgradedPassive = passiveReduction > 0 ? passiveReduction + 1 : 0;
  const passiveLines = [];
  if (upgradedPassive > 0) passiveLines.push(`passive_adjacent_cost_reduction = ${upgradedPassive}`);
  if (r.passive_adjacent_required_tag) passiveLines.push(`passive_adjacent_required_tag = &"${r.passive_adjacent_required_tag}"`);
  return `[gd_resource type="Resource" load_steps=3 format=3 uid="uid://card_${id}"]

[ext_resource type="Script" path="res://src/data_models/card_data.gd" id="1_data"]
[ext_resource type="Script" path="${effectPath}" id="2_fx"]

[sub_resource type="Resource" id="effect_1"]
script = ExtResource("2_fx")
${effectLines.join("\n")}

[resource]
script = ExtResource("1_data")
id = &"${id}"
display_name_key = "card.${id}.name"
desc_key = "card.${id}.desc"
cost = ${upgradedCost}
card_type = ${r.card_type}
tags = ${gdValue(r.tags ?? [])}
rarity = ${r.rarity}
description_template = "${descZh.replaceAll('"', '\\"')}"
effect = SubResource("effect_1")
consumable = ${r.consumable ? "true" : "false"}
${passiveLines.join("\n")}
`;
}

function addUpgradeRef(originalText, upgradePath) {
  if (originalText.includes("\nupgrade = ")) return originalText;
  const lines = originalText.split(/\r?\n/);
  let insertAt = 1;
  const ids = [...originalText.matchAll(/id="(\d+_[^"]+)"/g)].map((m) => m[1]);
  const extId = "3_up";
  const extLine = `[ext_resource type="Resource" path="${upgradePath}" id="${extId}"]`;
  lines.splice(insertAt + 1, 0, extLine);
  let text = lines.join("\n");
  text = text.replace(/load_steps=(\d+)/, (_m, n) => `load_steps=${Number(n) + 1}`);
  if (!text.endsWith("\n")) text += "\n";
  return text.replace(/\n$/, `upgrade = ExtResource("${extId}")\n`);
}

await fs.mkdir(upgradesDir, { recursive: true });
const i18n = await loadI18n();
const additions = [];
const files = (await fs.readdir(cardsDir)).filter((f) => f.endsWith(".tres")).sort();
let count = 0;
for (const file of files) {
  if (file.endsWith("_plus.tres")) continue;
  const full = path.join(cardsDir, file);
  let text = await fs.readFile(full, "utf8");
  const card = parseTres(text);
  const id = String(card.resource.id ?? "");
  if (!id || id.endsWith("_plus")) continue;
  const tags = Array.isArray(card.resource.tags) ? card.resource.tags : [];
  const upgradedId = `${id}_plus`;
  const name = i18n.map.get(card.resource.display_name_key)?.zh ?? id;
  const nameEn = i18n.map.get(card.resource.display_name_key)?.en ?? id;
  const baseDesc = i18n.map.get(card.resource.desc_key)?.zh ?? card.resource.description_template ?? "";
  const baseDescEn = i18n.map.get(card.resource.desc_key)?.en ?? "";
  const descZh = `${baseDesc.replace(/。$/, "")}。（升级版）`;
  const descEn = `${baseDescEn.replace(/\.$/, "")}. (Upgraded)`;
  const upgradedEffect = upgradeEffect(card.effect, card.effectPath, tags);
  const upgradedCost = upgradeCost(Number(card.resource.cost ?? 1), upgradedEffect, tags);
  const outPath = path.join(upgradesDir, `${upgradedId}.tres`);
  await fs.writeFile(outPath, buildTres(card, upgradedEffect, upgradedCost, descZh, descEn), "utf8");
  const rel = `res://data/cards/sword/upgrades/${upgradedId}.tres`;
  await fs.writeFile(full, addUpgradeRef(text, rel), "utf8");
  for (const [key, zh, en] of [
    [`card.${upgradedId}.name`, `${name}+`, `${nameEn}+`],
    [`card.${upgradedId}.desc`, descZh, descEn],
  ]) {
    if (!i18n.map.has(key)) additions.push(`${key},${csvEscape(zh)},${csvEscape(en)}`);
  }
  count += 1;
}

let i18nText = i18n.text;
if (additions.length) {
  if (!i18nText.endsWith("\n")) i18nText += "\n";
  i18nText += additions.join("\n") + "\n";
  await fs.writeFile(i18nPath, i18nText, "utf8");
}
console.log(`generated upgrades for ${count} cards`);
