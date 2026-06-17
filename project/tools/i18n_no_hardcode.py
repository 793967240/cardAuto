#!/usr/bin/env python3
"""
硬编码字符串守卫
扫描 src/ui/ 下的 .gd 文件，检测 .text = "..." 等直接赋值
有 4 个或以上字母/汉字的字符串视为硬编码

用法：
  python3 tools/i18n_no_hardcode.py
"""

import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
UI_DIRS = [
    PROJECT_ROOT / "src" / "ui",
    PROJECT_ROOT / "src" / "globals",
]

ALLOWLIST_DIRS = {
    PROJECT_ROOT / "src" / "debug",
}

PROPERTY_PATTERNS = [
    re.compile(r'\.text\s*=\s*"([^"]+)"'),
    re.compile(r'\.tooltip_text\s*=\s*"([^"]+)"'),
    re.compile(r'\.placeholder_text\s*=\s*"([^"]+)"'),
    re.compile(r'\.title\s*=\s*"([^"]+)"'),
]

HARDCODE_PATTERN = re.compile(r"[\u4e00-\u9fff]|[a-zA-Z]{4,}")


def is_allowlisted(path: Path) -> bool:
    return any(str(path).startswith(str(d)) for d in ALLOWLIST_DIRS)


def scan_violations() -> list[tuple[Path, int, str]]:
    violations = []
    for ui_dir in UI_DIRS:
        if not ui_dir.exists():
            continue
        for gd_file in ui_dir.rglob("*.gd"):
            if is_allowlisted(gd_file):
                continue
            text = gd_file.read_text(encoding="utf-8")
            for lineno, line in enumerate(text.splitlines(), 1):
                for pattern in PROPERTY_PATTERNS:
                    for match in pattern.finditer(line):
                        content = match.group(1)
                        if HARDCODE_PATTERN.search(content):
                            violations.append((gd_file, lineno, content))
    return violations


def main() -> int:
    print("🔍 Checking for hardcoded UI strings...")
    violations = scan_violations()

    if violations:
        print(f"\n❌ Hardcoded UI strings detected ({len(violations)}). Use tr() instead:")
        for path, lineno, content in violations:
            rel = path.relative_to(PROJECT_ROOT)
            print(f"  {rel}:{lineno}  →  {content!r}")
        return 1

    print("✅ No hardcoded UI strings found")
    return 0


if __name__ == "__main__":
    sys.exit(main())
