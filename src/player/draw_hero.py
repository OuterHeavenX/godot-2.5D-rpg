#!/usr/bin/env python3
"""Draw a chibi hero sprite sheet (3 frames: idle, walk A, walk B) with PIL.

Each frame is 24x32 pixels, scaled 4x with NEAREST to 96x128.
Frames are laid out horizontally: 288x128 PNG with transparency.
"""
from PIL import Image

W, H = 24, 32
SCALE = 4

PALETTE = {
    "H": (90, 58, 34, 255),      # hair - dark brown
    "h": (110, 74, 46, 255),     # hair highlight
    "S": (255, 207, 158, 255),   # skin
    "E": (30, 30, 46, 255),      # eyes
    "T": (59, 130, 246, 255),    # tunic blue (hero color)
    "t": (43, 95, 199, 255),     # tunic shade
    "B": (107, 66, 38, 255),     # belt brown
    "G": (245, 197, 66, 255),    # belt buckle gold
    "P": (51, 65, 85, 255),      # pants slate
    "O": (74, 47, 29, 255),      # boots
    "W": (255, 255, 255, 255),   # highlight
}

# Upper body is identical across frames (head, hair, torso, arms).
BODY = [
    "........................",
    "........HHHHHH..........",
    "......HHHHHHHHHH........",
    ".....HHHHHHHHHHHH.......",
    ".....HhhhhHHHHHHHH......",
    ".....HHSSSSSSSSHH.......",
    ".....HSSSSSSSSSSSH......",
    ".....HSSESSSESSSH.......",
    ".....HSSSSSSSSSSSH......",
    "......SSSSSSSSSS........",
    ".......TTTTTTTT.........",
    "......TTTTTTTTTT........",
    ".....STTTTTTTTTTS.......",
    ".....STTTTTTTTTTS.......",
    ".....STTtTTTTtTTS.......",
    "......SBBBBBBBS.........",
    "......SBGGGGGBS.........",
    "......STTTTTTTS.........",
    "......STTTTTTTS.........",
    ".......TTTTTT...........",
]

# Leg variants: (left_leg_rows, right_leg_rows) as row strings.
# Idle: both feet planted. Walk A: left foot forward. Walk B: right foot forward.
LEGS_IDLE = [
    ".......PP..PP...........",
    ".......PP..PP...........",
    ".......PP..PP...........",
    ".......PP..PP...........",
    ".......PP..PP...........",
    "......OPP..PPO..........",
    "......OPP..PPO..........",
    "......OOOO..OOOO........",
    "......OOOO..OOOO........",
    "........................",
    "........................",
    "........................",
]
LEGS_WALK_A = [
    "......PP...PP...........",
    "......PP...PP...........",
    "......PP....PP..........",
    ".....PP.....PP..........",
    ".....PP......PP.........",
    ".....OP......PPO........",
    "....OOP.......PO........",
    "....OOOO.....OOOO.......",
    "....OOOO.....OOOO.......",
    "........................",
    "........................",
    "........................",
]
LEGS_WALK_B = [
    ".......PP...PP..........",
    ".......PP...PP..........",
    ".......PP....PP.........",
    ".......PP.....PP........",
    "........PP.....PP.......",
    "........PPO....PO.......",
    "........PO.....POO......",
    ".......OOOO.....OOOO....",
    ".......OOOO.....OOOO....",
    "........................",
    "........................",
    "........................",
]


def draw_frame(leg_rows):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    rows = BODY + leg_rows
    assert len(rows) == H, f"expected {H} rows, got {len(rows)}"
    for y, row in enumerate(rows):
        assert len(row) == W, f"row {y}: expected {W} chars, got {len(row)}: {row!r}"
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            px[x, y] = PALETTE[ch]
    return img


def main():
    frames = [draw_frame(LEGS_IDLE), draw_frame(LEGS_WALK_A), draw_frame(LEGS_WALK_B)]
    sheet = Image.new("RGBA", (W * 3 * SCALE, H * SCALE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        big = f.resize((W * SCALE, H * SCALE), Image.NEAREST)
        sheet.paste(big, (i * W * SCALE, 0), big)
    out = "/home/hatch/workspace/your_files/godot-25d-rpg/src/player/hero.png"
    sheet.save(out)
    print("saved", out, sheet.size)


if __name__ == "__main__":
    main()
