#!/bin/bash
# check-extract.sh <file.pdf|file.docx> [--plain] [--region us|eu] [--variant <name>] [--location <text>] [--code <code>]
#
# Reads a printed resume back the way software does (pdftotext) and compares it with
# resume.json: name at the top, email / phone / LinkedIn / GitHub whole, every job's
# header, bullets and chips contiguous and in order, nothing wrapped, exactly one page.
# Exits 1 with the list of what is wrong. print.sh and ref-print.sh run it after every
# print; pass the same --region / --variant / --location / --code the print used.
# Details: tools/check_extract.py
FILE=$1
[ -n "$FILE" ] && [ -f "$FILE" ] && FILE=$(realpath "$FILE")
shift
cd "$(dirname "$0")" || exit 1
exec python3 tools/check_extract.py "$FILE" "$@"
