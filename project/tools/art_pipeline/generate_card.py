#!/usr/bin/env python3
"""
AI 卡牌生图工具
通过 animal-mediakit skill CLI 调用 AI 生成水墨修仙风格卡牌图

依赖：无需额外安装，通过 skill CLI 调用（uv run scripts/cli.py）
skill 路径：~/.config/opencode/skills/animal-mediakit/

用法：
  python3 tools/art_pipeline/generate_card.py --card tools/art_pipeline/card.yaml
  python3 tools/art_pipeline/generate_card.py --style-anchors
  python3 tools/art_pipeline/generate_card.py --list-pending
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
PENDING_DIR = PROJECT_ROOT / "assets" / "_pending"
SKILL_DIR = Path.home() / ".config" / "opencode" / "skills" / "animal-mediakit"
SKILL_CLI = SKILL_DIR / "scripts" / "cli.py"

STYLE_HEADER = (
    "水墨修仙风格，中国传统水墨画技法，留白美学，笔触质感，"
    "墨色晕染，卷轴纸纹，符箓装饰，古风仙侠氛围，精细线条，"
    "竖向构图，高对比度，"
)

NEGATIVE_PROMPT = (
    "低质量，模糊，像素化，3D渲染，照片写实，"
    "西方奇幻风格，科幻，现代元素，文字，水印，"
)

CARD_SIZE = "1024x1536"
DEFAULT_MODEL = "doubao-seedream-5-0-260128"

STYLE_ANCHOR_PROMPTS = [
    "剑修挥剑，剑气纵横，山水卷轴背景，水墨风格，留白突出，竖版构图",
    "古代符箓特写，符文发光，蓝紫色墨迹，神秘气息，精细线条，近景",
    "丹炉炼制场景，火焰升腾，炼丹房内景，金红色调，古朴气息",
    "时间轴卷轴展开俯视，刻度如竹简，墨迹流动，古朴纸纹",
    "六芒阵盘正面视角，符文发光，淡金色光晕，古典图案，精细雕刻感",
    "修炼者盘膝调息入定，周身灵气流动，水墨晕染效果，仙气飘飘",
    "业火状态特效特写，橙红墨迹飞溅，火焰符文，破阵冲击感",
    "打断封印特效，蓝白墨迹炸裂，符箓碎片飞散，冲击波效果",
]


def _check_skill_cli() -> bool:
    if not SKILL_CLI.exists():
        print(f"❌ animal-mediakit skill not found at: {SKILL_DIR}")
        print("   Please install the skill first.")
        return False
    return True


def generate_image(prompt: str, output_path: Path, model: str = DEFAULT_MODEL) -> bool:
    if not _check_skill_cli():
        return False

    output_path.parent.mkdir(parents=True, exist_ok=True)

    cmd = [
        "uv", "run", str(SKILL_CLI),
        "--json",
        "generate", "image",
        prompt,
        "--model", model,
        "--size", CARD_SIZE,
        "--negative-prompt", NEGATIVE_PROMPT,
        "-o", str(output_path),
    ]

    print(f"🎨 Generating: {output_path.name}")
    print(f"   Model: {model}")

    try:
        result = subprocess.run(
            cmd,
            cwd=str(SKILL_DIR),
            capture_output=True,
            text=True,
            timeout=300,
        )

        if result.returncode == 0:
            try:
                data = json.loads(result.stdout)
                if data.get("status") == "success":
                    print(f"✅ Saved: {output_path}")
                    return True
            except json.JSONDecodeError:
                pass
            print(f"✅ Generated: {output_path}")
            return True
        else:
            try:
                err = json.loads(result.stdout)
                print(f"❌ Generation failed: {err.get('message', result.stderr)}")
            except json.JSONDecodeError:
                print(f"❌ Generation failed: {result.stderr or result.stdout}")
            return False

    except subprocess.TimeoutExpired:
        print("❌ Timeout: generation took too long (>300s)")
        return False
    except FileNotFoundError:
        print("❌ 'uv' not found. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh")
        return False


def _load_card_yaml(yaml_path: str) -> dict:
    try:
        import yaml
        with open(yaml_path, encoding="utf-8") as f:
            return yaml.safe_load(f)
    except ImportError:
        import re
        card = {}
        with open(yaml_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("#") or not line:
                    continue
                m = re.match(r'^(\w+)\s*:\s*["\']?(.+?)["\']?\s*$', line)
                if m:
                    card[m.group(1)] = m.group(2)
        return card


def main():
    parser = argparse.ArgumentParser(description="TimeChain Card Art Generator")
    parser.add_argument("--card", help="Path to card.yaml config")
    parser.add_argument("--output", default=str(PENDING_DIR), help="Output directory")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="AI model to use")
    parser.add_argument("--style-anchors", action="store_true",
                        help="Generate 8 style anchor images for team review")
    parser.add_argument("--list-pending", action="store_true",
                        help="List files in assets/_pending/")
    args = parser.parse_args()

    if args.list_pending:
        pending = list(PENDING_DIR.glob("*.png")) + list(PENDING_DIR.glob("*.webp"))
        if not pending:
            print("No pending files in assets/_pending/")
        else:
            print(f"Pending files ({len(pending)}):")
            for p in sorted(pending):
                print(f"  {p.name}")
        return

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = Path(args.output)

    if args.style_anchors:
        print(f"Generating {len(STYLE_ANCHOR_PROMPTS)} style anchor images...")
        success = 0
        for i, prompt in enumerate(STYLE_ANCHOR_PROMPTS):
            full_prompt = f"{STYLE_HEADER}{prompt}"
            out_path = out_dir / f"style_anchor_{i+1:02d}_{ts}.png"
            if generate_image(full_prompt, out_path, args.model):
                success += 1
        print(f"\nDone: {success}/{len(STYLE_ANCHOR_PROMPTS)} generated → {out_dir}")
        return

    if not args.card:
        parser.print_help()
        sys.exit(1)

    card = _load_card_yaml(args.card)
    card_id = card.get("id", "unknown")
    base_prompt = card.get("prompt", "")
    style = card.get("style_override") or STYLE_HEADER
    full_prompt = f"{style}{base_prompt}"
    model = card.get("model", args.model)

    out_path = out_dir / f"{card_id}_{ts}.png"
    if not generate_image(full_prompt, out_path, model):
        sys.exit(1)


if __name__ == "__main__":
    main()
