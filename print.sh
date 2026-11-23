#!/bin/bash
# print.sh [--location <text>] [--eu-location <text>]
#
# Prints the generic resume, US (resume) and European (cv), each as:
#   <name>.pdf + <name>-preview.png   the designed one-page PDF
#   <name>.docx, <name>-plain.pdf     plain single-column versions (make-plain.sh)
# and reads every file back as text (check-extract.sh): exits 1 if one reads wrong.
#
#   --location     shows a location row, e.g. "New York, NY" (default: no location at all)
#   --eu-location  the location for the European version (default: the --location text)

usage() {
    echo "Usage: ./print.sh [--location <text>] [--eu-location <text>]"
    exit 1
}

LOCATION=""
EU_LOCATION=""
EU_LOCATION_SET=""
while [ $# -gt 0 ]; do
    if [[ "$1" == --location || "$1" == --eu-location ]] && [ $# -lt 2 ]; then
        echo "Error: $1 needs a value."
        exit 1
    fi
    case "$1" in
        --location) LOCATION=$2; shift 2 ;;
        --eu-location) EU_LOCATION=$2; EU_LOCATION_SET=1; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Error: unknown option $1"; usage ;;
    esac
done
[ -z "$EU_LOCATION_SET" ] && EU_LOCATION=$LOCATION

cd "$(dirname "$0")" || exit 1
. tools/common.sh
find_chrome
echo "Using browser: $CHROME_BIN"

# Start server, clearing any previous one on the port
echo "Starting temporary server..."
PORT=8989
fuser -k $PORT/tcp > /dev/null 2>&1 || true
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID > /dev/null 2>&1' EXIT

# Wait a moment for the server to be ready
sleep 2

urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }

STATUS=0

# print_version <name> <region> <location>: <name>.pdf and <name>-preview.png from
# index.html, then the checks and the plain versions.
print_version() {
    local NAME=$1 REGION=$2 LOC=$3
    local QUERY="region=$REGION"
    [ -n "$LOC" ] && QUERY="$QUERY&location=$(urlencode "$LOC")"
    local URL="http://localhost:$PORT/index.html?$QUERY"
    echo "Generating $NAME.pdf..."
    "$CHROME_BIN" --no-sandbox --headless --disable-gpu --print-to-pdf="$NAME.pdf" --no-margins --virtual-time-budget=5000 "$URL" 2>/dev/null

    echo "Generating $NAME-preview.png..."
    if command -v pdftoppm &> /dev/null; then
        pdftoppm "$NAME.pdf" "$NAME-preview" -png -rx 300 -ry 300 -singlefile
    else
        "$CHROME_BIN" --no-sandbox --headless --screenshot="$NAME-preview.png" --window-size=1200,1650 --virtual-time-budget=5000 "$URL" 2>/dev/null
    fi

    after_print "$NAME" "$REGION" "" "$LOC" || STATUS=1
}

# The US version, and the European one (Spanish number) for visitors in Europe.
print_version resume us "$LOCATION"
print_version cv eu "$EU_LOCATION"

echo "---------------------------------"
if [ $STATUS -ne 0 ]; then
    echo "FAILED: see the errors above. The files were written but at least one reads wrong."
else
    echo "Done! resume and cv, each as .pdf, -preview.png, .docx and -plain.pdf; all read back correctly"
fi
echo "---------------------------------"
exit $STATUS
