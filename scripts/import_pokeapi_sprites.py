"""Import the first 151 pixel sprites into the Xcode asset catalog."""

from concurrent.futures import ThreadPoolExecutor, as_completed
from io import BytesIO
import json
from pathlib import Path
from urllib.request import Request, urlopen

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "pokeTab" / "Assets.xcassets"
SOURCE = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/{id}.png"


def import_sprite(number: int) -> tuple[int, int, int]:
    request = Request(SOURCE.format(id=number), headers={"User-Agent": "pokeTab-local-prototype"})
    with urlopen(request, timeout=30) as response:
        data = response.read()
    image = Image.open(BytesIO(data)).convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"Sprite {number} has no visible pixels")

    cropped = image.crop(bounds)
    padding = max(3, round(max(cropped.size) * 0.08))
    canvas = Image.new(
        "RGBA",
        (cropped.width + 2 * padding, cropped.height + 2 * padding),
        (0, 0, 0, 0),
    )
    canvas.alpha_composite(cropped, (padding, padding))

    folder = ASSETS / f"pokemon-{number}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    canvas.save(folder / "sprite.png", optimize=True)
    (folder / "Contents.json").write_text(
        json.dumps(
            {
                "images": [{"filename": "sprite.png", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
            },
            indent=2,
        )
        + "\n"
    )
    return number, cropped.width, cropped.height


def main() -> None:
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(import_sprite, number) for number in range(1, 152)]
        results = [future.result() for future in as_completed(futures)]
    print(f"Imported {len(results)} sprites into {ASSETS}")
    print(f"Visible sprite dimensions: {min(w for _, w, _ in results)}–{max(w for _, w, _ in results)} px wide")


if __name__ == "__main__":
    main()
