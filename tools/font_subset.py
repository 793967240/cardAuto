#!/usr/bin/env python3
"""
思源宋体子集化脚本
先下载完整字体包，再执行此脚本生成游戏专用子集

用法：python3 tools/font_subset.py
"""
import csv, sys
from pathlib import Path

PROJECT = Path(__file__).parent.parent
FONT_IN = PROJECT / "assets/fonts/source_han_serif_sc_regular.otf"
FONT_OUT = PROJECT / "assets/fonts/source_han_serif_subset.otf"
CHARS_FILE = PROJECT / "tools/font_chars.txt"

def build_charset():
    chars = set()
    for csv_file in (PROJECT / "translations").glob("*.csv"):
        for row in csv.DictReader(open(csv_file, encoding="utf-8")):
            for v in row.values():
                for ch in v:
                    if '\u4e00' <= ch <= '\u9fff' or '\u3000' <= ch <= '\u303f':
                        chars.add(ch)
    extras = "，。！？、：；""''（）【】《》…—～·%0123456789 "
    chars.update(extras)
    CHARS_FILE.write_text("".join(sorted(chars)), encoding="utf-8")
    print(f"  Charset: {len(chars)} chars → {CHARS_FILE}")
    return chars

def subset():
    if not FONT_IN.exists():
        print(f"❌ Font not found: {FONT_IN}")
        print("   Download from: https://github.com/adobe-fonts/source-han-serif/releases")
        print("   Save as: assets/fonts/source_han_serif_sc_regular.otf")
        sys.exit(1)

    print("Building charset...")
    build_charset()

    print("Subsetting font...")
    from fontTools.subset import main as subset_main
    sys.argv = [
        "pyftsubset", str(FONT_IN),
        f"--text-file={CHARS_FILE}",
        f"--output-file={FONT_OUT}",
        "--layout-features=*",
        "--no-hinting",
    ]
    subset_main()

    size_mb = FONT_OUT.stat().st_size / 1024 / 1024
    print(f"✅ {FONT_OUT.name}: {size_mb:.1f} MB")

if __name__ == "__main__":
    subset()
