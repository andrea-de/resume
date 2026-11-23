# Variants: one application, one file

A variant tailors the resume for one application without touching `resume.json`. It is
one JSON file, `variants/<name>.json`, and it is **gitignored**: this repo is public, and
what was written for one company stays on this machine. Only this README and
`example.json` are committed.

```bash
./ref-print.sh k7q --region eu --variant acme
```

`index.html?variant=<name>` shows the same in the browser.

## What a variant can replace

```json
{
  "note": "free text for yourself, never printed",
  "location": "Barcelona, Spain",
  "skillsLine": "TypeScript, React, Node.js, SQL",
  "jobs": {
    "<company, exactly as in resume.json>": {
      "chips": ["TypeScript", "React", "Node.js"],
      "unifiedScope": "Full-Stack Product Engineering",
      "bullets": {
        "<scope of the responsibility>": "The bullet that replaces it."
      }
    }
  }
}
```

Every key is optional.

- `jobs.<company>.chips`: the whole chip row of that job.
- `jobs.<company>.bullets`: single bullets, keyed by the responsibility's `scope` in
  `resume.json` (the scope itself is not printed). Bullets not named keep their text.
- `jobs.<company>.unifiedScope`: the small capitals line under the job's header.
- `skillsLine`: the Skills line at the bottom of the main column.
- `location`: shows the location row (the resume has none by default). `--location` on
  the command line wins over it.

## Hide, not delete

The generic text stays in `resume.json`. What a variant replaces is swapped out before
the page renders, so the replaced bullet or chip is not in the page, the PDF, the Word
file or the plain PDF: not hidden, absent. `check-extract.sh` verifies it after the print.

## What stops a print

- An unknown variant name, a company that is not in `resume.json`, a scope that job does
  not have, or an unknown key: `ref-print.sh` stops before printing.
- After the print the PDF is read back (`check-extract.sh`): a bullet or a chip row that
  wraps onto a second line, a second page, or replaced text still present fails the run
  (exit 1), with the offending line. The limits are measured on the printed page, not
  counted in characters; as a guide a bullet holds about 89 characters and a chip row
  about 66 characters of chip text.
