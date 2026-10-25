"""Encode generated PNG assets for web delivery without changing their geometry."""
from pathlib import Path
from PIL import Image

assets = Path(__file__).resolve().parent.parent / "public" / "assets"
for source in assets.glob("*.png"):
    with Image.open(source) as image:
        image.save(source.with_suffix(".webp"), "WEBP", quality=94, method=6)
