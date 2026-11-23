#!/bin/bash
# make-plain.sh <name> [--region us|eu] [--variant <name>] [--location <text>] [--code <code>]
#
# The plain single-column versions of the resume, for systems that read resumes badly in
# two columns or ask for Word: <name>.docx and <name>-plain.pdf, from the same resume.json
# (and region, variant, location) as the designed PDF. print.sh and ref-print.sh run it
# after every print; it also runs alone, e.g. ./make-plain.sh resume
#
# No Microsoft software: the Word file is written with python-docx, in a
# venv (.venv/, gitignored) this script creates on its first run; the PDF is printed by
# the same Chromium as the designed one.

NAME=$1
if [ -z "$NAME" ] || [[ "$NAME" == -* ]]; then
    echo "Usage: ./make-plain.sh <name> [--region us|eu] [--variant <name>] [--location <text>] [--code <code>]"
    exit 1
fi
shift

cd "$(dirname "$0")" || exit 1
. tools/common.sh

# python-docx, once
if ! .venv/bin/python -c "import docx" 2> /dev/null; then
    echo "First run: creating .venv with python-docx..."
    python3 -m venv .venv && .venv/bin/pip install --quiet --disable-pip-version-check python-docx
    if ! .venv/bin/python -c "import docx" 2> /dev/null; then
        echo "Error: could not install python-docx into .venv; $NAME.docx and $NAME-plain.pdf not written."
        exit 1
    fi
fi

HTML=".plain-$NAME.html"
trap 'rm -f "$HTML"' EXIT
echo "Generating $NAME.docx..."
.venv/bin/python tools/plain_outputs.py "$NAME" "$@" || exit 1

STATUS=0
find_chrome
echo "Generating $NAME-plain.pdf..."
"$CHROME_BIN" --no-sandbox --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$NAME-plain.pdf" "file://$(pwd)/$HTML" 2> /dev/null
if [ ! -s "$NAME-plain.pdf" ]; then
    echo "Error: $NAME-plain.pdf was not generated."
    STATUS=1
fi

./check-extract.sh "$NAME.docx" "$@" || STATUS=1
[ -s "$NAME-plain.pdf" ] && { ./check-extract.sh "$NAME-plain.pdf" --plain "$@" || STATUS=1; }

# Optional: the Word file as a word processor lays it out, <name>-docx-preview.pdf, by
# LibreOffice (soffice) when it is installed. It is only for looking at (the Word file
# itself is what the check reads; LibreOffice's bullet glyphs would fail it here). Not installed,
# or the conversion fails: a one-line notice, and everything else stands.
# (soffice names its output <name>.pdf, the designed PDF's name: hence the temp directory.)
if command -v soffice &> /dev/null; then
    TMP_OUT=$(mktemp -d)
    if soffice --headless --convert-to pdf --outdir "$TMP_OUT" "$NAME.docx" > /dev/null 2>&1 && [ -s "$TMP_OUT/$NAME.pdf" ]; then
        mv "$TMP_OUT/$NAME.pdf" "$NAME-docx-preview.pdf"
        echo "Generated $NAME-docx-preview.pdf (the Word file as LibreOffice lays it out)"
    else
        echo "Notice: soffice could not convert $NAME.docx; no $NAME-docx-preview.pdf (everything else is unaffected)."
    fi
    rm -rf "$TMP_OUT"
else
    echo "Notice: LibreOffice (soffice) is not installed; skipping $NAME-docx-preview.pdf."
fi
exit $STATUS
