#!/bin/bash

# Find available chrome/headless_shell binary
CHROME_BIN=""
if command -v google-chrome &> /dev/null; then
    CHROME_BIN="google-chrome"
elif command -v chromium &> /dev/null; then
    CHROME_BIN="chromium"
elif [ -f "/home/dev/.cache/ms-playwright/chromium_headless_shell-1228/chrome-linux/headless_shell" ]; then
    CHROME_BIN="/home/dev/.cache/ms-playwright/chromium_headless_shell-1228/chrome-linux/headless_shell"
else
    FOUND_BIN=$(find /home/dev/.cache/ms-playwright -name "headless_shell" 2>/dev/null | head -n 1)
    if [ -n "$FOUND_BIN" ]; then
        CHROME_BIN="$FOUND_BIN"
    fi
fi

if [ -z "$CHROME_BIN" ]; then
    echo "Error: No Chrome or headless_shell binary found."
    exit 1
fi

echo "Using browser: $CHROME_BIN"

# Start server on an ephemeral port to avoid conflicts
echo "Starting temporary server..."
PORT=8989
fuser -k $PORT/tcp > /dev/null 2>&1 || true
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!

# Wait a moment for the server to be ready
sleep 2

# Generate the PDF using headless Chrome
echo "Generating resume.pdf..."
"$CHROME_BIN" --no-sandbox --headless --disable-gpu --print-to-pdf=resume.pdf --no-margins --virtual-time-budget=5000 "http://localhost:$PORT/index.html" 2>/dev/null

# Generate high-resolution preview PNG
echo "Generating resume-preview.png..."
if command -v pdftoppm &> /dev/null; then
    pdftoppm resume.pdf resume-preview -png -rx 300 -ry 300 -singlefile
else
    "$CHROME_BIN" --no-sandbox --headless --screenshot=resume-preview.png --window-size=1200,1650 --virtual-time-budget=5000 "http://localhost:$PORT/index.html" 2>/dev/null
fi

# Clean up
if [ ! -z "$SERVER_PID" ]; then
    kill $SERVER_PID > /dev/null 2>&1 || true
fi

echo "---------------------------------"
echo "Done! Saved to: resume.pdf and resume-preview.png"
echo "---------------------------------"
