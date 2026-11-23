#!/bin/bash
# ref-print.sh <code> [--region us|eu] [--color <hex>] [--logo-shape <path|url>] [--brand <name>]
#               [--variant <name>] [--location <text>]
#
# Prints resume-<code>.pdf and resume-<code>-preview.png with a QR code to the
# personal job link https://www.andreadecandia.com/r/<code> in the top-left, then the
# plain versions resume-<code>.docx and resume-<code>-plain.pdf (make-plain.sh), and
# reads each file back as text (check-extract.sh): exits 1 if one reads wrong.

usage() {
    echo "Usage: ./ref-print.sh <code> [--region us|eu] [--color <hex>] [--logo-shape <path|url>] [--brand <name>]"
    echo "                             [--variant <name>] [--location <text>]"
    echo "  <code>    the 3-character link code from the site API (lowercase letters/digits)"
    echo "  --region  us (default, US number) or eu (Spanish number)"
    echo "  --color   QR module color as hex without #, e.g. 0b5fff (lighter colors are darkened to 4.5:1 on white)"
    echo "  --logo-shape  silhouette (SVG, or PNG by alpha/darkness) the dots form, in the --color brand color"
    echo "  --brand   company name: looks up its silhouette and brand color in Simple Icons and uses"
    echo "            them as --logo-shape and --color (an explicit --color wins). Not found -> plain QR."
    echo "  --variant a tailored version: variants/<name>.json replaces chips, bullets, the Skills line and"
    echo "            may set the location (see variants/README.md). Unknown name -> error, nothing printed."
    echo "  --location  shows a location row, e.g. \"Barcelona, Spain\" (wins over the variant's; default: none)"
    exit 1
}

CODE=$1
if [ -z "$CODE" ] || [[ "$CODE" == -* ]]; then
    usage
fi
shift
if ! [[ "$CODE" =~ ^[a-z0-9]{3}$ ]]; then
    echo "Error: code \"$CODE\" must be exactly 3 lowercase letters or digits (e.g. k7q)."
    exit 1
fi

REGION="us"
COLOR=""
SHAPE=""
BRAND=""
VARIANT=""
LOCATION=""
while [ $# -gt 0 ]; do
    if [[ "$1" == --region || "$1" == --color || "$1" == --logo-shape || "$1" == --brand || "$1" == --variant || "$1" == --location ]] && [ $# -lt 2 ]; then
        echo "Error: $1 needs a value."
        exit 1
    fi
    case "$1" in
        --region) REGION=$2; shift 2 ;;
        --color) COLOR=${2#\#}; shift 2 ;;
        --logo-shape) SHAPE=$2; shift 2 ;;
        --brand) BRAND=$2; shift 2 ;;
        --variant) VARIANT=$2; shift 2 ;;
        --location) LOCATION=$2; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Error: unknown option $1"; usage ;;
    esac
done

if [ "$REGION" != "us" ] && [ "$REGION" != "eu" ]; then
    echo "Error: --region must be us or eu."
    exit 1
fi
if [ -n "$COLOR" ] && ! [[ "$COLOR" =~ ^[0-9a-fA-F]{6}$ ]]; then
    echo "Error: --color must be a 6-digit hex like 0b5fff."
    exit 1
fi

# Local files are relative to where the script was run from: resolve them before the cd.
[ -n "$SHAPE" ] && [ -f "$SHAPE" ] && SHAPE=$(realpath "$SHAPE")

# Run from the repo so the server sees index.html and the outputs land here.
cd "$(dirname "$0")" || exit 1
. tools/common.sh

# --variant: check the file exists and names real jobs and scopes before printing, so a
# typo can't silently print the generic resume. The location is --location, else the
# variant's, else none.
LOCATION=$(python3 tools/resume_data.py --region "$REGION" --variant "$VARIANT" --location "$LOCATION" --code "$CODE") || exit 1
[ -n "$VARIANT" ] && echo "Variant: $VARIANT (variants/$VARIANT.json)"
[ -n "$LOCATION" ] && echo "Location: $LOCATION"

# --brand: the company's silhouette and brand color from Simple Icons (CC0 brand icons:
# one SVG path + the official hex each), from a pinned release on jsDelivr, cached in
# .brand-cache/ (gitignored). Never fails the print: not found -> a plain QR.
SIMPLE_ICONS_VERSION="16.30.0"
if [ -n "$BRAND" ]; then
    if [ -n "$SHAPE" ]; then
        echo "Error: use --brand or --logo-shape, not both."
        exit 1
    fi
    BRAND_OUT=$(python3 - "$BRAND" "$SIMPLE_ICONS_VERSION" <<'PY'
import json, os, sys, unicodedata, urllib.request

name, version = sys.argv[1], sys.argv[2]
cdn = f"https://cdn.jsdelivr.net/npm/simple-icons@{version}"
cache = os.path.join(".brand-cache", version)
os.makedirs(cache, exist_ok=True)

def fetch(url, dest):
    if not os.path.exists(dest):
        with urllib.request.urlopen(url, timeout=20) as r:
            data = r.read()
        with open(dest + ".part", "wb") as f:
            f.write(data)
        os.replace(dest + ".part", dest)
    return dest

def say(msg):
    print(msg, file=sys.stderr)

# Simple Icons' own titleToSlug (sdk.mjs): lowercase, a few replacements, strip diacritics
# (NFD) and anything not a-z / 0-9.
REPL = {"+": "plus", ".": "dot", "&": "and", "đ": "d", "ħ": "h", "ı": "i", "ĸ": "k",
        "ŀ": "l", "ł": "l", "ß": "ss", "ŧ": "t", "ø": "o"}
def slugify(title):
    s = "".join(REPL.get(c, c) for c in title.lower())
    s = unicodedata.normalize("NFD", s)
    return "".join(c for c in s if c.isascii() and (c.isdigit() or "a" <= c <= "z"))

try:
    icons = json.load(open(fetch(f"{cdn}/data/simple-icons.json", os.path.join(cache, "simple-icons.json"))))
except Exception as e:
    say(f"Brand: could not load the Simple Icons {version} data ({e}).")
    sys.exit(0)

slug, key = slugify(name), name.strip().casefold()
def names(icon):
    aliases = icon.get("aliases") or {}
    return [icon["title"], *aliases.get("aka", []), *(d["title"] for d in aliases.get("dup", [])),
            *(aliases.get("loc") or {}).values()]
icon_slug = lambda icon: icon.get("slug") or slugify(icon["title"])
match = (next((i for i in icons if icon_slug(i) == slug), None)
         or next((i for i in icons if any(n.casefold() == key for n in names(i))), None)
         or next((i for i in icons if any(slugify(n) == slug for n in names(i))), None))
if not match or not slug:
    say(f'Brand: "{name}" is not in Simple Icons {version} (slug "{slug}"); printing a plain QR.')
    sys.exit(0)

s = icon_slug(match)
try:
    svg = fetch(f"{cdn}/icons/{s}.svg", os.path.join(cache, f"{s}.svg"))
except Exception as e:
    say(f'Brand: found "{match["title"]}" but could not download {s}.svg ({e}); printing a plain QR.')
    sys.exit(0)
print(svg)
print(match["hex"].lower())
print(match["title"])
PY
)
    BRAND_SVG=$(sed -n 1p <<< "$BRAND_OUT")
    BRAND_HEX=$(sed -n 2p <<< "$BRAND_OUT")
    BRAND_TITLE=$(sed -n 3p <<< "$BRAND_OUT")
    if [ -n "$BRAND_SVG" ]; then
        SHAPE=$BRAND_SVG
        echo "Brand: \"$BRAND_TITLE\" from Simple Icons $SIMPLE_ICONS_VERSION ($BRAND_SVG), brand color #$BRAND_HEX"
        if [ -z "$COLOR" ]; then
            COLOR=$BRAND_HEX
        else
            echo "Brand: using --color #$COLOR instead of the brand color"
        fi
        echo "Reminder: brand logos are only for a one-off resume sent to that company; never publish one."
    elif [ -z "$COLOR" ]; then
        echo "Brand: no logo; plain QR in the default color"
    else
        echo "Brand: no logo; plain QR in #$COLOR"
    fi
fi

# The page darkens a color under 4.5:1 on white (same hue) until it scans.
if [ -n "$COLOR" ]; then
    RATIO=$(python3 -c '
import sys
h = sys.argv[1]
lin = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
r, g, b = (lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
print(f"{1.05 / (0.2126 * r + 0.7152 * g + 0.0722 * b + 0.05):.2f}")' "$COLOR")
    if python3 -c 'import sys; sys.exit(float(sys.argv[1]) >= 4.5)' "$RATIO"; then
        echo "Color: #$COLOR is too light to scan ($RATIO:1 on white, needs 4.5:1); the QR darkens it to 4.5:1."
    fi
fi

# The page can only load files the server can see: copy a local shape into the repo
# for the duration of the print (removed on exit, gitignored as .qr-logo-*).
TMP_FILES=()
SERVER_PID=""
cleanup() {
    [ -n "$SERVER_PID" ] && kill $SERVER_PID > /dev/null 2>&1
    [ ${#TMP_FILES[@]} -gt 0 ] && rm -f "${TMP_FILES[@]}"
}
trap cleanup EXIT

# stage_file <path|url> <tag>: prints the value for the page's URL param.
stage_file() {
    if [[ "$1" =~ ^https?:// ]]; then
        echo "$1"
    elif [[ "$1" == .brand-cache/* ]] && [ -f "$1" ]; then
        echo "$1" # already in the repo
    elif [ -f "$1" ]; then
        local EXT="${1##*.}"
        local DEST=".qr-logo-$2-$$.${EXT,,}"
        cp "$1" "$DEST"
        echo "$DEST"
    else
        return 1
    fi
}
SHAPE_PARAM=""
if [ -n "$SHAPE" ]; then
    SHAPE_PARAM=$(stage_file "$SHAPE" shape) || { echo "Error: logo shape file not found: $SHAPE"; exit 1; }
    [[ "$SHAPE_PARAM" == .qr-logo-* ]] && TMP_FILES+=("$SHAPE_PARAM")
fi

find_chrome
echo "Using browser: $CHROME_BIN"

# Start server, clearing any previous one on the port
echo "Starting temporary server..."
PORT=8989
fuser -k $PORT/tcp > /dev/null 2>&1 || true
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!

# Wait a moment for the server to be ready
sleep 2

urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }

QUERY="code=$CODE&region=$REGION"
[ -n "$COLOR" ] && QUERY="$QUERY&qrColor=$COLOR"
[ -n "$SHAPE_PARAM" ] && QUERY="$QUERY&qrShape=$(urlencode "$SHAPE_PARAM")"
[ -n "$VARIANT" ] && QUERY="$QUERY&variant=$(urlencode "$VARIANT")"
[ -n "$LOCATION" ] && QUERY="$QUERY&location=$(urlencode "$LOCATION")"

NAME="resume-$CODE"
URL="http://localhost:$PORT/index.html?$QUERY"

echo "Generating $NAME.pdf..."
"$CHROME_BIN" --no-sandbox --headless --disable-gpu --print-to-pdf="$NAME.pdf" --no-margins --virtual-time-budget=5000 "$URL" 2>/dev/null

if [ ! -s "$NAME.pdf" ]; then
    echo "Error: $NAME.pdf was not generated."
    exit 1
fi

echo "Generating $NAME-preview.png..."
if command -v pdftoppm &> /dev/null; then
    pdftoppm "$NAME.pdf" "$NAME-preview" -png -rx 300 -ry 300 -singlefile
else
    "$CHROME_BIN" --no-sandbox --headless --screenshot="$NAME-preview.png" --window-size=1200,1650 --virtual-time-budget=5000 "$URL" 2>/dev/null
fi

# One page, reads back in order, nothing wrapped; then the Word and plain versions.
STATUS=0
after_print "$NAME" "$REGION" "$VARIANT" "$LOCATION" "$CODE" || STATUS=1

echo "---------------------------------"
if [ $STATUS -ne 0 ]; then
    echo "FAILED: see the errors above. The files were written but at least one reads wrong."
else
    echo "Done! QR -> https://www.andreadecandia.com/r/$CODE (region: $REGION${VARIANT:+, variant: $VARIANT}${LOCATION:+, location: $LOCATION})"
fi
echo "  $(pwd)/$NAME.pdf"
echo "  $(pwd)/$NAME-preview.png"
echo "  $(pwd)/$NAME.docx"
echo "  $(pwd)/$NAME-plain.pdf"
echo "---------------------------------"
exit $STATUS
