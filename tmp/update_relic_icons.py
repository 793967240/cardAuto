import json
import re
from pathlib import Path

ROOT = Path("/Users/happyelements/Documents/卡牌/project")
MANIFEST = Path("/Users/happyelements/Documents/卡牌/tmp/relic_icon_manifest.json")
ICON_DIR = ROOT / "assets/ui/relics/generated"
RELIC_DIR = ROOT / "data/relics"


def patch_relic_tres(relic_id: str) -> None:
    path = RELIC_DIR / f"{relic_id}.tres"
    text = path.read_text(encoding="utf-8")
    icon_path = f"res://assets/ui/relics/generated/{relic_id}.png"
    if "id=\"2_icon\"" in text or 'id="2_icon"' in text:
        text = re.sub(
            r'\[ext_resource type="Texture2D" path="[^"]+" id="2_icon"\]',
            f'[ext_resource type="Texture2D" path="{icon_path}" id="2_icon"]',
            text,
        )
    else:
        text = text.replace(
            '[ext_resource type="Script" path="res://src/data_models/relic_data.gd" id="1_data"]',
            '[ext_resource type="Script" path="res://src/data_models/relic_data.gd" id="1_data"]\n'
            f'[ext_resource type="Texture2D" path="{icon_path}" id="2_icon"]',
        )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    items = json.loads(MANIFEST.read_text(encoding="utf-8"))
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    missing = []
    for item in items:
        relic_id = item["id"]
        if not (ICON_DIR / f"{relic_id}.png").exists():
            missing.append(relic_id)
            continue
        patch_relic_tres(relic_id)
    print(f"patched={len(items) - len(missing)} missing={len(missing)}")
    if missing:
        print("\n".join(missing))


if __name__ == "__main__":
    main()
