# Resume Project

This resume is built with **Petite-Vue** and **UnoCSS**. It dynamically fetches data from `resume.json` and `icons.json`.

## Quick View
![Resume Preview](./resume-preview.png)

## How to View Locally
Because it fetches external JSON data, it **must be served via a web server** to work correctly.

### Option 1: Using Node.js
```bash
npx serve .
```

### Option 2: Using Python
```bash
python3 -m http.server
```

Once running, visit `http://localhost:3000` (or the port provided) to view the resume.

---

## How to Print (PDF & PNG)
You can generate a PDF and a high-quality PNG preview in one command. This script requires **Google Chrome** (or Chromium) and **poppler-utils** (`pdftoppm`).

### Generate the standard version:
```bash
./print.sh
```

### Generate a custom version for tracking:
This will append tracking parameters to your website links (`?utm_source=resume&utm_campaign=REF_NAME`).

```bash
./utm-print.sh <ref-name> [job-url]
# Example: ./utm-print.sh bobby-at-apple "https://jobs.apple.com/..."
```

This will output:
- `resume-REF_NAME.pdf`
- `resume-REF_NAME-preview.png`

---

## Tracking
The resume automatically tracks clicks to your website by appending UTM parameters. 
- The base link is `?utm_source=resume`.
- Custom campaigns can be added via the script or by visiting `index.html?ref=MY_REF`.
