#!/bin/bash

# Port to use for the temporary server
PORT=8989

# Start a simple python server in the background
echo "Starting temporary server..."
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!

# Wait a moment for the server to be ready
sleep 2

# Generate the PDF using headless Chrome
# If you use chromium, change 'google-chrome' to 'chromium-browser'
echo "Generating resume.pdf..."
google-chrome --headless --disable-gpu --print-to-pdf=resume.pdf --no-margins http://localhost:$PORT/index.html

# Convert PDF to PNG for README preview
if command -v pdftoppm &> /dev/null
then
    echo "Converting PDF to resume-preview.png..."
    pdftoppm resume.pdf resume-preview -png -rx 300 -ry 300 -singlefile
else
    echo "Note: 'pdftoppm' not found. Skipping PNG conversion."
fi

# Kill the background server
kill $SERVER_PID

echo "---------------------------------"
echo "Done! Saved to: resume.pdf and resume-preview.png"
echo "---------------------------------"
