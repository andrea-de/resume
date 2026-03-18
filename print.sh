#!/bin/bash

# Start server on an ephemeral port (0) to avoid conflicts
echo "Starting temporary server..."
PORT=8989
fuser -k $PORT/tcp > /dev/null 2>&1
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!

# Wait a moment for the server to be ready
sleep 2

# Generate the PDF using headless Chrome
echo "Generating resume.pdf..."
google-chrome --headless=new --disable-gpu --print-to-pdf=resume.pdf --no-margins --virtual-time-budget=5000 http://localhost:$PORT/index.html 2>/dev/null

# Convert PDF to PNG for README preview
if command -v pdftoppm &> /dev/null
then
    echo "Converting PDF to resume-preview.png..."
    pdftoppm resume.pdf resume-preview -png -rx 300 -ry 300 -singlefile
else
    echo "Note: 'pdftoppm' not found. Skipping PNG conversion."
fi

# Clean up
if [ ! -z "$SERVER_PID" ]; then
    kill $SERVER_PID > /dev/null 2>&1
fi

echo "---------------------------------"
echo "Done! Saved to: resume.pdf and resume-preview.png"
echo "---------------------------------"
