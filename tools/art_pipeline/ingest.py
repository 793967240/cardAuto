#!/usr/bin/env python3
"""
美术资产入库脚本
将 assets/_pending/ 中的图片移动到对应的 assets/ 子目录

用法：
  python3 tools/art_pipeline/ingest.py --file assets/_pending/sword_zhan_20260430.png --dest cards/sword
  python3 tools/art_pipeline/ingest.py --pending-all --dest cards/sword
"""

import argparse
import shutil
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
PENDING_DIR = PROJECT_ROOT / "assets" / "_pending"
ASSETS_DIR = PROJECT_ROOT / "assets"

VALID_DEST_DIRS = {
    "cards/shared", "cards/sword", "cards/talisman", "cards/alchemy", "cards/body",
    "enemies", "slots", "ui", "effects",
}


def ingest_file(src: Path, dest_subdir: str) -> bool:
    dest_dir = ASSETS_DIR / dest_subdir
    dest_dir.mkdir(parents=True, exist_ok=True)

    dest_path = dest_dir / src.name
    if dest_path.exists():
        print(f"⚠️  Already exists: {dest_path}")
        return False

    shutil.move(str(src), str(dest_path))
    print(f"✅ Ingested: {src.name} → assets/{dest_subdir}/")
    return True


def list_pending() -> list[Path]:
    if not PENDING_DIR.exists():
        return []
    return sorted(PENDING_DIR.glob("*.png")) + sorted(PENDING_DIR.glob("*.webp"))


def main():
    parser = argparse.ArgumentParser(description="Ingest art assets from pending dir")
    parser.add_argument("--file", help="Single file to ingest")
    parser.add_argument("--pending-all", action="store_true", help="List all pending files")
    parser.add_argument("--dest", required=False, help="Destination subdir (e.g. cards/sword)")
    args = parser.parse_args()

    if args.pending_all or not args.file:
        pending = list_pending()
        if not pending:
            print("No pending files found in assets/_pending/")
            return
        print(f"Pending files ({len(pending)}):")
        for p in pending:
            print(f"  {p.name}")
        if not args.dest:
            return

        for p in pending:
            ingest_file(p, args.dest)
        return

    if args.file:
        if not args.dest:
            print("❌ --dest is required when using --file")
            sys.exit(1)
        if args.dest not in VALID_DEST_DIRS:
            print(f"❌ Invalid dest: {args.dest}")
            print(f"   Valid options: {sorted(VALID_DEST_DIRS)}")
            sys.exit(1)
        src = Path(args.file)
        if not src.exists():
            print(f"❌ File not found: {src}")
            sys.exit(1)
        ingest_file(src, args.dest)


if __name__ == "__main__":
    main()
