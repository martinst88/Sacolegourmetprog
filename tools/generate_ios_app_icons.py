from pathlib import Path

from PIL import Image, ImageColor


ROOT = Path(__file__).resolve().parents[1]
logo_path = ROOT / "ARFsSacolesGourmet" / "Assets.xcassets" / "BrandLogo.imageset" / "brand-logo.png"
icon_dir = ROOT / "ARFsSacolesGourmet" / "Assets.xcassets" / "AppIcon.appiconset"

BACKGROUND = ImageColor.getrgb("#F5EFE7")
ICON_SPECS = [
    ("iphone-notification-20@2x.png", 40, "iphone", "20x20", "2x"),
    ("iphone-notification-20@3x.png", 60, "iphone", "20x20", "3x"),
    ("iphone-settings-29@2x.png", 58, "iphone", "29x29", "2x"),
    ("iphone-settings-29@3x.png", 87, "iphone", "29x29", "3x"),
    ("iphone-spotlight-40@2x.png", 80, "iphone", "40x40", "2x"),
    ("iphone-spotlight-40@3x.png", 120, "iphone", "40x40", "3x"),
    ("iphone-app-60@2x.png", 120, "iphone", "60x60", "2x"),
    ("iphone-app-60@3x.png", 180, "iphone", "60x60", "3x"),
    ("ios-marketing-1024@1x.png", 1024, "ios-marketing", "1024x1024", "1x"),
]


def render_icon(source: Image.Image, size: int) -> Image.Image:
    canvas = Image.new("RGB", (size, size), BACKGROUND)

    logo = source.copy()
    inset = max(1, round(size * 0.12))
    target = size - (inset * 2)
    logo.thumbnail((target, target), Image.Resampling.LANCZOS)

    x = (size - logo.width) // 2
    y = (size - logo.height) // 2
    canvas.paste(logo.convert("RGB"), (x, y))
    return canvas


def write_contents_json() -> None:
    lines = [
        "{",
        '  "images" : [',
    ]

    for index, (filename, _, idiom, size, scale) in enumerate(ICON_SPECS):
        suffix = "," if index < len(ICON_SPECS) - 1 else ""
        lines.extend(
            [
                "    {",
                f'      "filename" : "{filename}",',
                f'      "idiom" : "{idiom}",',
                f'      "scale" : "{scale}",',
                f'      "size" : "{size}"',
                f"    }}{suffix}",
            ]
        )

    lines.extend(
        [
            "  ],",
            '  "info" : {',
            '    "author" : "xcode",',
            '    "version" : 1',
            "  }",
            "}",
        ]
    )

    (icon_dir / "Contents.json").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    icon_dir.mkdir(parents=True, exist_ok=True)
    source = Image.open(logo_path)

    for filename, size, _, _, _ in ICON_SPECS:
        render_icon(source, size).save(icon_dir / filename, format="PNG")

    write_contents_json()


if __name__ == "__main__":
    main()

