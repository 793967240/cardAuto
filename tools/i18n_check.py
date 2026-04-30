#!/usr/bin/env python3
"""
i18n 校验工具
检查：
1. 缺失 key（代码里用了但 CSV 里没有）
2. 占位符一致性（各语言 {placeholder} 必须一致）
3. 未使用 key（警告级）

用法：
  python3 tools/i18n_check.py
"""

import csv
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
SRC_DIR = PROJECT_ROOT / "src"
TRANSLATIONS_DIR = PROJECT_ROOT / "translations"
SOURCE_CSV = TRANSLATIONS_DIR / "_source.csv"


def find_all_tr_keys(src_dir: Path) -> set[str]:
    """扫描所有 .gd 文件，提取 tr("...") 和 tr('...') 中的 key"""
    keys = set()
    pattern = re.compile(r'tr\(\s*["\']([^"\']+)["\']\s*[\),]')
    for f in src_dir.rglob("*.gd"):
        content = f.read_text(encoding="utf-8")
        found = pattern.findall(content)
        keys.update(found)
    # 也扫描 .tscn 场景文件里的 tr()
    for f in (PROJECT_ROOT / "scenes").rglob("*.tscn"):
        content = f.read_text(encoding="utf-8")
        found = pattern.findall(content)
        keys.update(found)
    return keys


def load_csv_keys(csv_path: Path) -> tuple[set[str], list[dict]]:
    """读取 CSV，返回 key 集合 + 所有行"""
    if not csv_path.exists():
        print(f"❌ Source CSV not found: {csv_path}")
        sys.exit(1)

    rows = []
    with open(csv_path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)

    keys = {row["keys"] for row in rows if row.get("keys")}
    return keys, rows


def check_placeholders(rows: list[dict]) -> bool:
    """检查所有语言版本的 {placeholder} 必须一致"""
    placeholder_pattern = re.compile(r"\{(\w+)\}")
    ok = True
    for row in rows:
        key = row.get("keys", "")
        if not key:
            continue
        langs = {k: v for k, v in row.items() if k != "keys" and v}
        if not langs:
            continue
        baseline_lang, baseline_text = next(iter(langs.items()))
        baseline_ph = set(placeholder_pattern.findall(baseline_text))
        for lang, text in langs.items():
            ph = set(placeholder_pattern.findall(text))
            if ph != baseline_ph:
                print(f"❌ Placeholder mismatch in key '{key}':")
                print(f"   {baseline_lang}: {sorted(baseline_ph)}")
                print(f"   {lang}: {sorted(ph)}")
                ok = False
    return ok


def main() -> int:
    print("🔍 Checking i18n keys...")

    # 1. 加载 CSV keys
    csv_keys, rows = load_csv_keys(SOURCE_CSV)
    print(f"  CSV keys: {len(csv_keys)}")

    # 2. 扫描代码中的 keys
    code_keys = find_all_tr_keys(SRC_DIR)
    print(f"  Code keys: {len(code_keys)}")

    # 3. 检查缺失
    missing = code_keys - csv_keys
    if missing:
        print(f"\n❌ Missing keys in translation CSV ({len(missing)}):")
        for k in sorted(missing):
            print(f"  - {k}")

    # 4. 未使用（警告）
    unused = csv_keys - code_keys
    if unused:
        print(f"\n⚠️  Unused keys in CSV (warning only, {len(unused)}):")
        for k in sorted(unused):
            print(f"  - {k}")

    # 5. 占位符一致性
    ph_ok = check_placeholders(rows)

    if missing or not ph_ok:
        print("\n❌ i18n check FAILED")
        return 1

    print("\n✅ i18n check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
