import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const root = "/Users/happyelements/Documents/卡牌/project";
const cardsRoot = path.join(root, "data/cards");
const i18nPath = path.join(root, "translations/_source.csv");
const outputPath = "/Users/happyelements/Documents/卡牌/outputs/card_export/card_data_export.xlsx";

const CARD_TYPES = ["攻击", "防御", "增益", "控制", "召唤", "特殊"];
const RARITIES = ["普通", "罕见", "稀有"];

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

async function walkTres(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walkTres(full));
    } else if (entry.isFile() && entry.name.endsWith(".tres")) {
      files.push(full);
    }
  }
  return files.sort((a, b) => a.localeCompare(b));
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
  if (value.startsWith("ExtResource")) {
    const m = value.match(/ExtResource\("([^"]+)"\)/);
    return m ? m[1] : value;
  }
  if (value.startsWith("SubResource")) {
    const m = value.match(/SubResource\("([^"]+)"\)/);
    return m ? m[1] : value;
  }
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
      subId = "";
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
    if (section === "sub" && subId) {
      subResources.get(subId)[key] = value;
    } else if (section === "resource") {
      resource[key] = value;
    }
  }

  return { extResources, subResources, resource };
}

function effectSummary(parsed) {
  const effectId = parsed.resource.effect;
  const effect = parsed.subResources.get(effectId) ?? {};
  const scriptId = effect.script;
  const scriptPath = parsed.extResources.get(scriptId) ?? "";
  const scriptName = scriptPath.split("/").pop()?.replace(".gd", "") ?? "";
  const params = Object.entries(effect)
    .filter(([k]) => k !== "script")
    .map(([k, v]) => `${k}=${v}`)
    .join("; ");
  return { scriptPath, scriptName, params };
}

function makeRows(files, i18n) {
  return files.map((file) => {
    const rel = path.relative(root, file).replaceAll(path.sep, "/");
    return fs.readFile(file, "utf8").then((text) => {
      const parsed = parseTres(text);
      const r = parsed.resource;
      const { scriptPath, scriptName, params } = effectSummary(parsed);
      const name = i18n.get(r.display_name_key) ?? {};
      const desc = i18n.get(r.desc_key) ?? {};
      const rarityIdx = Number(r.rarity ?? 0);
      const typeIdx = Number(r.card_type ?? 0);
      return {
        id: r.id ?? "",
        nameZh: name.zh ?? "",
        nameEn: name.en ?? "",
        descZh: desc.zh ?? r.description_template ?? "",
        descEn: desc.en ?? "",
        cost: Number(r.cost ?? 0),
        type: CARD_TYPES[typeIdx] ?? String(typeIdx),
        rarity: RARITIES[rarityIdx] ?? String(rarityIdx),
        tags: Array.isArray(r.tags) ? r.tags.join(", ") : String(r.tags ?? ""),
        consumable: r.consumable ? "是" : "否",
        effectScript: scriptName,
        effectParams: params,
        upgrade: r.upgrade ? String(r.upgrade) : "",
        path: rel,
      };
    });
  });
}

function countBy(rows, key) {
  const map = new Map();
  for (const row of rows) map.set(row[key], (map.get(row[key]) ?? 0) + 1);
  return [...map.entries()].sort((a, b) => String(a[0]).localeCompare(String(b[0])));
}

const i18n = await loadI18n();
const files = await walkTres(cardsRoot);
const rows = await Promise.all(makeRows(files, i18n));

const workbook = Workbook.create();
const cards = workbook.worksheets.add("Cards");
const summary = workbook.worksheets.add("Summary");

const headers = [
  "ID", "中文名", "英文名", "中文描述", "英文描述", "Cost", "类型", "稀有度",
  "标签", "一次性", "效果脚本", "效果参数", "升级目标", "资源路径",
];
const values = [
  headers,
  ...rows.map((r) => [
    r.id, r.nameZh, r.nameEn, r.descZh, r.descEn, r.cost, r.type, r.rarity,
    r.tags, r.consumable, r.effectScript, r.effectParams, r.upgrade, r.path,
  ]),
];
cards.getRangeByIndexes(0, 0, values.length, headers.length).values = values;

cards.getRange("A1:N1").format.fill.color = "#1F2937";
cards.getRange("A1:N1").format.font.color = "#FFFFFF";
cards.getRange("A1:N1").format.font.bold = true;
cards.getRange("A:N").format.font.name = "Arial";
cards.getRange("A:N").format.font.size = 10;
cards.getRange("D:E").format.wrapText = true;
cards.getRange("L:L").format.wrapText = true;
cards.getRange("N:N").format.wrapText = true;
cards.freezePanes.freezeRows(1);
cards.getRange("A:A").format.columnWidth = 130;
cards.getRange("B:C").format.columnWidth = 110;
cards.getRange("D:E").format.columnWidth = 280;
cards.getRange("F:F").format.columnWidth = 60;
cards.getRange("G:H").format.columnWidth = 80;
cards.getRange("I:I").format.columnWidth = 180;
cards.getRange("J:K").format.columnWidth = 90;
cards.getRange("L:L").format.columnWidth = 220;
cards.getRange("M:M").format.columnWidth = 140;
cards.getRange("N:N").format.columnWidth = 300;

const rarityColors = {
  "普通": "#E5E7EB",
  "罕见": "#DBEAFE",
  "稀有": "#FEF3C7",
};
for (let i = 0; i < rows.length; i += 1) {
  const rowNumber = i + 2;
  cards.getRange(`H${rowNumber}`).format.fill.color = rarityColors[rows[i].rarity] ?? "#FFFFFF";
}

const typeCounts = countBy(rows, "type");
const rarityCounts = countBy(rows, "rarity");
const costCounts = countBy(rows, "cost");
const summaryValues = [
  ["卡牌数据导出", ""],
  ["导出时间", new Date().toLocaleString("zh-CN", { timeZone: "Asia/Shanghai" })],
  ["卡牌总数", rows.length],
  ["", ""],
  ["按类型统计", "数量"],
  ...typeCounts,
  ["", ""],
  ["按稀有度统计", "数量"],
  ...rarityCounts,
  ["", ""],
  ["按费用统计", "数量"],
  ...costCounts,
];
summary.getRangeByIndexes(0, 0, summaryValues.length, 2).values = summaryValues;
summary.getRange("A1:B1").merge();
summary.getRange("A1").format.fill.color = "#1F2937";
summary.getRange("A1").format.font.color = "#FFFFFF";
summary.getRange("A1").format.font.bold = true;
summary.getRange("A1").format.font.size = 16;
summary.getRange("A:B").format.font.name = "Arial";
summary.getRange("A:B").format.columnWidth = 180;
summary.getRange("B:B").format.columnWidth = 90;
for (const row of [5, 5 + typeCounts.length + 2, 5 + typeCounts.length + 2 + rarityCounts.length + 2]) {
  summary.getRange(`A${row}:B${row}`).format.fill.color = "#E5E7EB";
  summary.getRange(`A${row}:B${row}`).format.font.bold = true;
}

const preview = await workbook.inspect({
  kind: "table",
  range: "Cards!A1:N8",
  include: "values",
  tableMaxRows: 8,
  tableMaxCols: 14,
});
console.log(preview.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "formula error scan",
});
console.log(errors.ndjson);

await workbook.render({ sheetName: "Cards", range: "A1:H12", scale: 1 });
await workbook.render({ sheetName: "Cards", range: "I1:N12", scale: 1 });
await workbook.render({ sheetName: "Summary", range: "A1:B20", scale: 1 });

await fs.mkdir(path.dirname(outputPath), { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(outputPath);
