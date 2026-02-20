# Resume Project

This resume is built with **Petite-Vue** and **UnoCSS**. Because it dynamically fetches data from `resume.json` and `icons.json`, it **must be served via a web server** to work correctly.

## How to View
If you open `index.html` directly in your browser as a file (`file://...`), the data will fail to load due to browser CORS security restrictions.

### Option 1: Using Node.js (Recommended)
```bash
npx serve .
```

### Option 2: Using Python
```bash
python3 -m http.server
```

Once running, visit `http://localhost:3000` (or the port provided) to view the resume.
