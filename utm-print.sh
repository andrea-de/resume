#!/bin/bash

# Campaign name from first argument
REF=$1
# Optional Job URL from second argument
JOB_URL=$2

if [ -z "$REF" ]; then
    echo "Usage: ./print-for.sh <ref-name> [job-url]"
    exit 1
fi

# URL encode the JOB_URL if it exists
if [ ! -z "$JOB_URL" ]; then
    ENCODED_JOB=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$JOB_URL'''))")
    QUERY_PARAMS="ref=$REF&job=$ENCODED_JOB"
else
    QUERY_PARAMS="ref=$REF"
fi

# Start server on 8989, clearing any previous ones
PORT=8989
echo "Starting temporary server for $REF..."
fuser -k $PORT/tcp > /dev/null 2>&1
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!

# Wait for server
sleep 2

# Generate PDF
echo "Generating resume-$REF.pdf..."
google-chrome --headless=new --disable-gpu --print-to-pdf="resume-$REF.pdf" --no-margins --virtual-time-budget=5000 "http://localhost:$PORT/index.html?$QUERY_PARAMS" 2>/dev/null

# Convert to PNG
if command -v pdftoppm &> /dev/null
then
    echo "Converting PDF to resume-$REF-preview.png..."
    pdftoppm "resume-$REF.pdf" "resume-$REF-preview" -png -rx 300 -ry 300 -singlefile
else
    echo "Note: 'pdftoppm' not found. Skipping PNG conversion."
fi

# Cleanup
if [ ! -z "$SERVER_PID" ]; then
    kill $SERVER_PID > /dev/null 2>&1
fi

echo "---------------------------------"
echo "Done! Saved to: resume-$REF.pdf"
echo "---------------------------------"
