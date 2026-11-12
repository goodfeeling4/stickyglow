#!/usr/bin/env bash
set -uo pipefail

if (( $# < 2 )); then
  echo "Usage: $0 <input_image> <file1.txt> [file2.txt ...] [output.png]" >&2
  exit 1
fi

INPUT_IMG="$1"
shift

if [[ ! -f "$INPUT_IMG" ]]; then
  echo "Error: Input image '$INPUT_IMG' not found." >&2
  exit 1
fi

OUTPUT_IMG="output.png"
TXT_FILES=()

for arg in "$@"; do
  shopt -s nocasematch
  if [[ "$arg" =~ \.(png|jpg|jpeg|webp)$ ]]; then
    OUTPUT_IMG="$arg"
  else
    if [[ ! -f "$arg" ]]; then
      echo "info: '$arg' is directory" >&2
      continue
    fi
    TXT_FILES+=("$arg")
  fi
  shopt -u nocasematch
done

NUM_NOTES="${#TXT_FILES[@]}"
if (( NUM_NOTES == 0 )); then
  echo "Error: No input .txt files provided." >&2
  exit 1
fi

# Detect ImageMagick 7 vs ImageMagick 6
if command -v magick >/dev/null 2>&1; then
  IM=("magick")
  ID=("magick" "identify")
elif command -v convert >/dev/null 2>&1; then
  IM=("convert")
  ID=("identify")
else
  echo "Error: ImageMagick is not installed." >&2
  exit 1
fi

# Safe dimension reader: falls back to parsing WxH if %w %h is not expanded
get_dims() {
  local img="$1"
  local w="" h=""
  read -r w h < <("${ID[@]}" -format "%w %h\n" "${img}[0]" 2>/dev/null | head -n 1)
  if [[ ! "$w" =~ ^[0-9]+$ ]] || [[ ! "$h" =~ ^[0-9]+$ ]]; then
    read -r w h < <("${ID[@]}" "${img}[0]" 2>/dev/null | grep -oE ' [0-9]+x[0-9]+ ' | head -n 1 | tr 'x' ' ')
  fi
  echo "$w $h"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Get input image dimensions
read -r IMG_W IMG_H < <(get_dims "$INPUT_IMG")
if [[ ! "$IMG_W" =~ ^[0-9]+$ ]] || [[ ! "$IMG_H" =~ ^[0-9]+$ ]]; then
  echo "Error: Could not read dimensions of '$INPUT_IMG'." >&2
  exit 1
fi

echo "Processing $INPUT_IMG (${IMG_W}x${IMG_H}) with $NUM_NOTES sticky block(s)..."

# Layout and spacing constraints
MARGIN_X=$(( IMG_W * 3 / 100 ))
MARGIN_Y=$(( IMG_H * 4 / 100 ))
GAP_Y=$(( IMG_H * 2 / 100 ))
GAP_X=$(( IMG_W * 2 / 100 ))

MAX_NOTE_W=$(( IMG_W * 15 / 100 ))
if (( MAX_NOTE_W < 140 )); then
  MAX_NOTE_W=140
fi

MAX_COL_H=$(( IMG_H - MARGIN_Y * 2 ))
if (( MAX_COL_H < 120 )); then
  MAX_COL_H=$(( IMG_H - 20 ))
fi

RADIUS=12
PAD=16
TEXT_PAD=14
HEAD_PAD_Y=10
MAX_TEXT_W=$(( MAX_NOTE_W - TEXT_PAD * 2 ))

FONT_SIZE=$(( IMG_W / 70 ))
if (( FONT_SIZE < 16 )); then
  FONT_SIZE=16
fi
if (( FONT_SIZE > 30 )); then
  FONT_SIZE=30
fi

HEADING_FONT_SIZE=$(( FONT_SIZE + 1 ))

CHARS_PER_LINE=$(( MAX_TEXT_W * 10 / (FONT_SIZE * 6) ))
if (( CHARS_PER_LINE < 8 )); then
  CHARS_PER_LINE=8
fi

HEAD_CHARS_PER_LINE=$(( MAX_TEXT_W * 10 / (HEADING_FONT_SIZE * 7) ))
if (( HEAD_CHARS_PER_LINE < 8 )); then
  HEAD_CHARS_PER_LINE=8
fi

# Estimate maximum lines per single sticky note so a huge file splits instead of clipping
LINE_H_EST=$(( FONT_SIZE * 135 / 100 ))
if (( LINE_H_EST < 18 )); then
  LINE_H_EST=18
fi
MAX_LINES_PER_NOTE=$(( (MAX_COL_H - 75) / LINE_H_EST ))
if (( MAX_LINES_PER_NOTE < 3 )); then
  MAX_LINES_PER_NOTE=3
fi

WORK_IMG="$TMP_DIR/work.png"
"${IM[@]}" "${INPUT_IMG}[0]" "$WORK_IMG"

# Column state: start at the right edge and wrap leftward when full
COL_RIGHT_X=$(( IMG_W - MARGIN_X ))
CURRENT_Y="$MARGIN_Y"
COL_MAX_W=0

render_note_card() {
  local raw_heading="$1"
  local raw_body="$2"

  local heading_text="${raw_heading//%/%%}"
  local note_text="${raw_body//%/%%}"
  local canvas_h=$(( IMG_H * 2 ))

  # 1. Render mint-green bold heading (#5dd684) and trim to exact bounds
  "${IM[@]}" -size "${IMG_W}x${canvas_h}" xc:none \
    -gravity northwest \
    -weight Bold \
    -fill "rgba(0,0,0,0.65)" -pointsize "$HEADING_FONT_SIZE" -annotate +1+1 "$heading_text" \
    -fill "#5dd684" -pointsize "$HEADING_FONT_SIZE" -annotate +0+0 "$heading_text" \
    -trim +repage \
    "$TMP_DIR/heading.png"

  read -r HEAD_W HEAD_H < <(get_dims "$TMP_DIR/heading.png")

  # 2. Render light off-white body text (#e6ebf2) and trim to exact bounds
  "${IM[@]}" -size "${IMG_W}x${canvas_h}" xc:none \
    -gravity northwest \
    -fill "rgba(0,0,0,0.65)" -pointsize "$FONT_SIZE" -annotate +1+1 "$note_text" \
    -fill "rgba(230,235,242,0.92)" -pointsize "$FONT_SIZE" -annotate +0+0 "$note_text" \
    -trim +repage \
    "$TMP_DIR/text.png"

  read -r ACTUAL_TEXT_W ACTUAL_TEXT_H < <(get_dims "$TMP_DIR/text.png")

  # 3. Calculate dynamic width and free-form height from content
  local content_w="$ACTUAL_TEXT_W"
  if (( HEAD_W > content_w )); then
    content_w="$HEAD_W"
  fi

  local divider_y=$(( HEAD_PAD_Y + HEAD_H + HEAD_PAD_Y ))
  local body_y=$(( divider_y + 1 + TEXT_PAD ))

  local note_w=$(( content_w + TEXT_PAD * 2 ))
  local note_h=$(( body_y + ACTUAL_TEXT_H + TEXT_PAD ))

  if (( note_w < 90 )); then
    note_w=90
  fi
  if (( note_h < 60 )); then
    note_h=60
  fi

  # Wrap to a new column on the left if this note overflows the bottom margin
  if (( CURRENT_Y > MARGIN_Y && CURRENT_Y + note_h > IMG_H - MARGIN_Y )); then
    COL_RIGHT_X=$(( COL_RIGHT_X - COL_MAX_W - GAP_X ))
    CURRENT_Y="$MARGIN_Y"
    COL_MAX_W=0
  fi

  # Track widest card in the current column
  if (( note_w > COL_MAX_W )); then
    COL_MAX_W="$note_w"
  fi

  # Right-align the note within the current column
  local nx=$(( COL_RIGHT_X - note_w ))
  local ny="$CURRENT_Y"

  # Clamp horizontal/vertical coordinates so ImageMagick crop never goes out of bounds
  if (( nx < MARGIN_X )); then
    echo "Warning: Sticky notes reached left edge of image; clamping X position." >&2
    nx="$MARGIN_X"
  fi
  if (( nx < 0 )); then
    nx=0
  fi
  if (( ny < 0 )); then
    ny=0
  fi

  # 4. Create rounded mask and soft dark drop shadow
  "${IM[@]}" -size "${note_w}x${note_h}" xc:none \
    -fill white \
    -draw "roundrectangle 0,0 $((note_w-1)),$((note_h-1)) ${RADIUS},${RADIUS}" \
    "$TMP_DIR/mask.png"

  "${IM[@]}" -size "$((note_w + PAD*2))x$((note_h + PAD*2))" xc:none \
    -fill "rgba(0,0,0,0.45)" \
    -draw "roundrectangle ${PAD},${PAD} $((PAD+note_w-1)),$((PAD+note_h-1)) ${RADIUS},${RADIUS}" \
    -blur 0x10 \
    "$TMP_DIR/shadow.png"

  # 5. Crop background under the block, lightly blur, and apply dark translucent glass tint
  "${IM[@]}" "$WORK_IMG" -crop "${note_w}x${note_h}+${nx}+${ny}" +repage \
    -background none -extent "${note_w}x${note_h}" \
    -blur 0x6 \
    -fill "rgba(16,20,26,0.78)" -draw "rectangle 0,0 ${note_w},${note_h}" \
    "$TMP_DIR/frosted.png"

  # 6. Apply rounded corners
  "${IM[@]}" "$TMP_DIR/frosted.png" "$TMP_DIR/mask.png" \
    -alpha set -compose DstIn -composite \
    "$TMP_DIR/glass_card.png"

  # 7. Draw subtle outer border and 1px divider line between heading and notes
  "${IM[@]}" "$TMP_DIR/glass_card.png" \
    -fill none \
    -stroke "rgba(255,255,255,0.16)" -strokewidth 1 \
    -draw "line 1,${divider_y} $((note_w-2)),${divider_y}" \
    -stroke "rgba(255,255,255,0.14)" -strokewidth 1 \
    -draw "roundrectangle 0,0 $((note_w-1)),$((note_h-1)) ${RADIUS},${RADIUS}" \
    "$TMP_DIR/glass_bordered.png"

  # 8. Composite heading and body text onto the dark glass block
  "${IM[@]}" "$TMP_DIR/glass_bordered.png" \
    "$TMP_DIR/heading.png" -gravity northwest -geometry "+${TEXT_PAD}+${HEAD_PAD_Y}" -compose Over -composite \
    "$TMP_DIR/text.png" -gravity northwest -geometry "+${TEXT_PAD}+${body_y}" -compose Over -composite \
    "$TMP_DIR/final_card.png"

  # Format geometry with explicit signs (+X+Y or -X-Y) to avoid "+-5" syntax errors
  local shadow_geom card_geom
  shadow_geom="$(printf '%+d%+d' $((nx - PAD)) $((ny - PAD + 5)))"
  card_geom="$(printf '%+d%+d' "$nx" "$ny")"

  # 9. Composite shadow and sticky block onto the image
  "${IM[@]}" "$WORK_IMG" \
    "$TMP_DIR/shadow.png" -gravity northwest -geometry "$shadow_geom" -compose Over -composite \
    "$TMP_DIR/final_card.png" -gravity northwest -geometry "$card_geom" -compose Over -composite \
    "$WORK_IMG"

  CURRENT_Y=$(( CURRENT_Y + note_h + GAP_Y ))
}

for i in "${!TXT_FILES[@]}"; do
  FILE="${TXT_FILES[$i]}"

  # Extract heading from .txt filename and wrap long headings
  BASENAME="$(basename "$FILE")"
  RAW_HEADING="${BASENAME%.*}"
  RAW_HEADING="${RAW_HEADING//_/ }"
  RAW_HEADING="${RAW_HEADING^^}"
  RAW_HEADING="$(printf '%s' "$RAW_HEADING" | fold -s -w "$HEAD_CHARS_PER_LINE" | fold -w "$HEAD_CHARS_PER_LINE")"

  # Read body text, strip CR, and word-wrap to max width
  RAW_TEXT="$(tr -d '\r' < "$FILE" | fold -s -w "$CHARS_PER_LINE" | fold -w "$CHARS_PER_LINE")"
  if [[ -z "${RAW_TEXT//[[:space:]]/}" ]]; then
    continue
  fi

  # Split into lines so oversized single files automatically break into multiple cards
  mapfile -t BODY_LINES <<< "$RAW_TEXT"
  TOTAL_LINES="${#BODY_LINES[@]}"

  if (( TOTAL_LINES <= MAX_LINES_PER_NOTE )); then
    render_note_card "$RAW_HEADING" "$RAW_TEXT"
  else
    PART=1
    TOTAL_PARTS=$(( (TOTAL_LINES + MAX_LINES_PER_NOTE - 1) / MAX_LINES_PER_NOTE ))
    for (( start=0; start<TOTAL_LINES; start+=MAX_LINES_PER_NOTE )); do
      CHUNK_LINES=("${BODY_LINES[@]:start:MAX_LINES_PER_NOTE}")
      CHUNK_TEXT="$(printf '%s\n' "${CHUNK_LINES[@]}")"
      CHUNK_TEXT="${CHUNK_TEXT%$'\n'}"

      if [[ -z "${CHUNK_TEXT//[[:space:]]/}" ]]; then
        continue
      fi

      if (( PART == 1 )); then
        PART_HEADING="$RAW_HEADING"
      else
        PART_HEADING="${RAW_HEADING} (${PART}/${TOTAL_PARTS})"
      fi

      render_note_card "$PART_HEADING" "$CHUNK_TEXT"
      (( PART++ ))
    done
  fi
done

mv "$WORK_IMG" "$OUTPUT_IMG"
echo "Done! Saved output to: $OUTPUT_IMG"