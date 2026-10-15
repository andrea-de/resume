#!/bin/bash
# ref-print.sh <code> [--region us|eu] [--color <hex>] [--logo <path|url>]
#
# Prints resume-<code>.pdf and resume-<code>-preview.png with a QR code to the
# personal job link https://www.andreadecandia.com/r/<code> in the top-left.

usage() {
    echo "Usage: ./ref-print.sh <code> [--region us|eu] [--color <hex>] [--logo <path|url>]"
    echo "  <code>    the 3-character link code from the site API (lowercase letters/digits)"
    echo "  --region  us (default, US number) or eu (Spanish number)"
    echo "  --color   QR module color as hex without #, e.g. 0b5fff (must be >= 4.5:1 on white)"
    echo "  --logo    image placed in the QR center (file path or http(s) URL)"
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
LOGO=""
while [ $# -gt 0 ]; do
    if [[ "$1" == --region || "$1" == --color || "$1" == --logo ]] && [ $# -lt 2 ]; then
        echo "Error: $1 needs a value."
        exit 1
    fi
    case "$1" in
        --region) REGION=$2; shift 2 ;;
        --color) COLOR=${2#\#}; shift 2 ;;
        --logo) LOGO=$2; shift 2 ;;
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

# Run from the repo so the server sees index.html and the outputs land here.
cd "$(dirname "$0")" || exit 1

# The page can only load a logo the server can see: copy a local file into the
# repo for the duration of the print (removed on exit, gitignored as .qr-logo.*).
LOGO_PARAM=""
TMP_LOGO=""
if [ -n "$LOGO" ]; then
    if [[ "$LOGO" =~ ^https?:// ]]; then
        LOGO_PARAM=$LOGO
    elif [ -f "$LOGO" ]; then
        EXT="${LOGO##*.}"
        TMP_LOGO=".qr-logo-$$.${EXT,,}"
        cp "$LOGO" "$TMP_LOGO"
        LOGO_PARAM=$TMP_LOGO
    else
        echo "Error: logo file not found: $LOGO"
        exit 1
    fi
fi

# Find available chrome/headless_shell binary
CHROME_BIN=""
if command -v google-chrome &> /dev/null; then
    CHROME_BIN="google-chrome"
elif command -v chromium &> /dev/null; then
    CHROME_BIN="chromium"
else
    FOUND_BIN=$(find "$HOME/.cache/ms-playwright" -name "headless_shell" -type f 2>/dev/null | head -n 1)
    if [ -n "$FOUND_BIN" ]; then
        CHROME_BIN="$FOUND_BIN"
    fi
fi

if [ -z "$CHROME_BIN" ]; then
    echo "Error: No Chrome or headless_shell binary found."
    exit 1
fi

echo "Using browser: $CHROME_BIN"

# Start server, clearing any previous one on the port
echo "Starting temporary server..."
PORT=8989
fuser -k $PORT/tcp > /dev/null 2>&1 || true
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!

cleanup() {
    [ -n "$SERVER_PID" ] && kill $SERVER_PID > /dev/null 2>&1
    [ -n "$TMP_LOGO" ] && rm -f "$TMP_LOGO"
}
trap cleanup EXIT

# Wait a moment for the server to be ready
sleep 2

urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }

QUERY="code=$CODE&region=$REGION"
[ -n "$COLOR" ] && QUERY="$QUERY&qrColor=$COLOR"
[ -n "$LOGO_PARAM" ] && QUERY="$QUERY&qrLogo=$(urlencode "$LOGO_PARAM")"

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

if command -v pdfinfo &> /dev/null; then
    PAGES=$(pdfinfo "$NAME.pdf" | awk '/^Pages:/ {print $2}')
    [ "$PAGES" != "1" ] && echo "Warning: $NAME.pdf has $PAGES pages (expected 1)."
fi

echo "---------------------------------"
echo "Done! QR -> https://www.andreadecandia.com/r/$CODE (region: $REGION)"
echo "  $(pwd)/$NAME.pdf"
echo "  $(pwd)/$NAME-preview.png"
echo "---------------------------------"
