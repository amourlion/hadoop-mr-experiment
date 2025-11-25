#!/bin/bash
# Script to generate PNG timeline from CSV using wkhtmltoimage or similar tools

CSV_FILE="$1"

if [ -z "$CSV_FILE" ]; then
    echo "Usage: $0 <csv_file>"
    echo "Example: $0 metrics/20251125_141801_slowstart_0.3_timeline.csv"
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File '$CSV_FILE' not found"
    exit 1
fi

# Generate HTML first
echo "Generating HTML timeline..."
python3 visualization/timeline_visualizer_simple.py "$CSV_FILE"

# Get the HTML filename
HTML_FILE="visualization/$(basename ${CSV_FILE%.csv}_timeline.html)"

if [ ! -f "$HTML_FILE" ]; then
    echo "Error: HTML file not generated"
    exit 1
fi

# Create output PNG filename
PNG_FILE="visualization/pics/$(basename ${CSV_FILE%.csv}_timeline.png)"

echo "Converting HTML to PNG..."

# Try different methods to convert HTML to PNG
if command -v wkhtmltoimage &> /dev/null; then
    # Method 1: wkhtmltoimage (best quality)
    wkhtmltoimage --width 1400 --height 900 "$HTML_FILE" "$PNG_FILE"
    echo "PNG saved to: $PNG_FILE"
elif command -v google-chrome &> /dev/null || command -v chromium-browser &> /dev/null; then
    # Method 2: Chrome/Chromium headless
    CHROME_CMD=$(command -v google-chrome || command -v chromium-browser)
    "$CHROME_CMD" --headless --screenshot="$PNG_FILE" --window-size=1400,900 --default-background-color=0 "file://$(pwd)/$HTML_FILE"
    echo "PNG saved to: $PNG_FILE"
elif command -v firefox &> /dev/null; then
    # Method 3: Firefox headless
    firefox --headless --screenshot "file://$(pwd)/$HTML_FILE"
    mv screenshot.png "$PNG_FILE" 2>/dev/null
    echo "PNG saved to: $PNG_FILE"
else
    echo "Error: No suitable tool found for HTML to PNG conversion"
    echo "Please install one of: wkhtmltoimage, google-chrome, chromium-browser, or firefox"
    echo ""
    echo "HTML file is available at: $HTML_FILE"
    echo "You can open it in a browser and take a screenshot manually."
    exit 1
fi

echo "Done!"
