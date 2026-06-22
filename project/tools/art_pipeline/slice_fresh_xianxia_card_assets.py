from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
CARD_DIR = ROOT / "assets" / "ui" / "cards"
SOURCE = CARD_DIR / "fresh_xianxia_card_frame_source.png"
OUT = CARD_DIR / "card_frame_common.png"
PREVIEW = CARD_DIR / "fresh_xianxia_card_assets_preview.png"
CARD_SIZE = (480, 752)


def save_card_frame() -> None:
    src = Image.open(SOURCE).convert("RGBA")
    src.thumbnail(CARD_SIZE, Image.Resampling.LANCZOS)

    card = Image.new("RGBA", CARD_SIZE, (0, 0, 0, 0))
    card.alpha_composite(src, ((CARD_SIZE[0] - src.width) // 2, (CARD_SIZE[1] - src.height) // 2))
    card.save(OUT)


def save_preview() -> None:
    card = Image.open(OUT).convert("RGBA")
    bg = Image.new("RGBA", CARD_SIZE, (236, 248, 244, 255))
    draw = ImageDraw.Draw(bg)
    step = 24
    for y in range(0, CARD_SIZE[1], step):
        for x in range(0, CARD_SIZE[0], step):
            if (x // step + y // step) % 2 == 0:
                draw.rectangle((x, y, x + step - 1, y + step - 1), fill=(210, 226, 222, 255))
    bg.alpha_composite(card)
    bg.thumbnail((300, 470), Image.Resampling.LANCZOS)

    preview = Image.new("RGBA", (340, 520), (250, 252, 250, 255))
    preview.alpha_composite(bg, ((preview.width - bg.width) // 2, 18))
    ImageDraw.Draw(preview).text((16, 492), OUT.name, fill=(30, 70, 66, 255))
    preview.save(PREVIEW)


def main() -> None:
    CARD_DIR.mkdir(parents=True, exist_ok=True)
    save_card_frame()
    save_preview()


if __name__ == "__main__":
    main()
