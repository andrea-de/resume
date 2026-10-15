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

This prints two versions from the same `resume.json`:
- `resume.pdf` / `resume-preview.png`: the US version, with the US phone number.
- `cv.pdf` / `cv-preview.png`: the European version, with the Spanish phone number
  (`index.html?region=eu`). andreadecandia.com serves it to visitors in Europe.

A contact entry with `"region": "us"` or `"region": "eu"` shows only in that version;
entries without a region show in both.

### Generate a custom version for tracking:
This will append tracking parameters to your website links (`?utm_source=resume&utm_campaign=REF_NAME`).

```bash
./utm-print.sh <ref-name> [job-url]
# Example: ./utm-print.sh bobby-at-apple "https://jobs.apple.com/..."
```

This will output:
- `resume-REF_NAME.pdf`
- `resume-REF_NAME-preview.png`

### Generate a version for a personal job link (QR code):
Andrea's site hands out personal job links: the site API returns a 3-character code, and
`https://www.andreadecandia.com/r/<code>` is the link for that company. `ref-print.sh` prints a
résumé whose QR code (top-left of the sidebar) points to that link.

```bash
./ref-print.sh <code> [--region us|eu] [--color <hex>] [--logo <path|url>]
# Examples:
./ref-print.sh k7q                                 # US number, default teal QR
./ref-print.sh k7q --region eu                     # Spanish number
./ref-print.sh k7q --color 0b5fff --logo logo.svg  # brand-colored QR with a logo in the middle
```

This will output:
- `resume-<code>.pdf`
- `resume-<code>-preview.png`

The code must be exactly 3 lowercase letters or digits. A local `--logo` file is copied into the
repo as `.qr-logo-*` while printing (the page can only load files the print server can see) and
removed afterwards.

---

## QR Code
The top-left of the sidebar is a QR code on a white rounded tile (inline SVG, so it stays crisp in
the PDF; it's also a link). It's drawn from the module matrix of the vendored
[qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator) 1.4.4 (MIT,
`src/vendor/qrcode.js`): dot modules, softly rounded finder eyes, a 4-module quiet zone.

What it encodes, from the `index.html` URL params:
- `?code=k7q` → `https://www.andreadecandia.com/r/k7q`
- no code → `https://www.andreadecandia.com/?utm_source=resume`, plus `&utm_campaign=<ref>` with `?ref=`

Styling params:
- `?qrColor=0b5fff`: module color (hex, no `#`). Colors under 4.5:1 contrast on white can't be
  relied on to scan, so they fall back to near-black with a console warning. Default: dark teal.
- `?qrLogo=<path or URL>`: an image centered on a white pad (≤ 22% of the QR width); switches
  error correction from M to H so the covered modules are recovered.
- `?qrStyle=square`: plain square modules and eyes, if a scanner ever struggles with the dots.

Keep the finder eyes' outer corners only slightly rounded: rounder rings stop some decoders
(e.g. OpenCV's) from finding the code at all.

---

## Tracking
The resume automatically tracks clicks to your website by appending UTM parameters. 
- The base link is `?utm_source=resume`.
- Custom campaigns can be added via the script or by visiting `index.html?ref=MY_REF`.
- The QR code carries the same tag (`?utm_source=resume`, plus `utm_campaign` with `?ref=`),
  unless a personal link code is given with `?code=`.
