"""Read a printed resume back the way software does and compare it with the data.

    python3 tools/check_extract.py <file.pdf|file.docx> [--plain] [--region us|eu]
                                   [--variant <name>] [--location <text>] [--code <code>]

Designed PDF (default): fails (exit 1) when
  - it is not exactly one page
  - the email, phone, LinkedIn or GitHub address is not found whole in the text
    (pdftotext -raw; the default and -layout modes are checked too, as warnings)
  - the name is not in the first lines
  - a job's header, scope, bullets and chip row are not one contiguous run, in order
  - a bullet, a chip row, a contact row or the Skills line wraps onto a second line, or
    the sidebar's about text takes more than 4 lines
  - a location was asked for and is missing, or text a variant replaced is still there
--plain (the single-column PDF) and .docx: the same content checks, without the layout ones.

Needs only pdftotext and pdfinfo (poppler-utils). About 0.2 s.
"""
import argparse
import os
import re
import subprocess
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import resume_data

NAME_WITHIN = 3  # the name must be inside the first lines of text
ABOUT_MAX_LINES = 4


def squash(text):
    """One line, single spaces, no bullet glyphs, lowercase (scopes print in capitals)."""
    return re.sub(r"\s+", " ", text.replace("•", " ")).strip().lower()


def pdf_text(path, *mode):
    return subprocess.run(["pdftotext", *mode, path, "-"], capture_output=True, text=True, check=True).stdout


def docx_text(path):
    """The paragraphs of a .docx, one per line: every <w:t> inside each <w:p>."""
    with zipfile.ZipFile(path) as z:
        xml = z.read("word/document.xml").decode("utf-8")
        parts = [n for n in z.namelist() if re.match(r"word/(header|footer)\d*\.xml", n)]
    unescape = lambda s: s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"').replace("&apos;", "'").replace("&amp;", "&")
    lines = ["".join(unescape(t) for t in re.findall(r"<w:t(?:\s[^>]*)?>([^<]*)</w:t>", p))
             for p in re.findall(r"<w:p[ >].*?</w:p>", xml, flags=re.S)]
    extras = []
    if "<w:tbl>" in xml:
        extras.append("the document contains a table")
    if "<w:txbxContent" in xml or "<w:drawing" in xml or "<w:pict" in xml:
        extras.append("the document contains a text box or an image")
    if parts:
        extras.append("the document has headers or footers")
    return "\n".join(lines), extras


def check(path, data, plain, is_docx):
    errors, warnings = [], []
    extras = []
    if is_docx:
        text, extras = docx_text(path)
    else:
        text = pdf_text(path, "-raw")
    errors += extras
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    flat = squash(text)
    designed = not plain and not is_docx

    if designed:
        info = subprocess.run(["pdfinfo", path], capture_output=True, text=True, check=True).stdout
        pages = int(re.search(r"^Pages:\s+(\d+)", info, flags=re.M).group(1))
        if pages != 1:
            errors.append(f"{pages} pages (must be exactly 1)")

    # Name at the top
    top = squash(" ".join(lines[:NAME_WITHIN]))
    if squash(data["name"]) not in top:
        errors.append(f'the name "{data["name"]}" is not in the first {NAME_WITHIN} lines of text (they read: {" / ".join(lines[:NAME_WITHIN])})')

    # Contacts: whole, as text
    contacts = dict(data["contacts"])
    expected = {k: contacts[k]["text"] for k in ("email", "phone", "linkedin", "github") if k in contacts}
    if "website" in contacts:
        expected["website"] = contacts["website"]["text"] if designed else contacts["website"].get("plain", contacts["website"]["text"])
    if data["location"]:
        expected["location"] = data["location"]
    for kind, value in expected.items():
        if squash(value) not in flat:
            errors.append(f"{kind} not found as text: {value}")
        elif designed and value not in lines:
            errors.append(f"{kind} is not alone on one line (wrapped or merged): {value}")
    if not is_docx:
        for mode in ((), ("-layout",)):
            other = squash(pdf_text(path, *mode))
            for kind in ("email", "phone", "linkedin"):
                if kind in expected and squash(expected[kind]) not in other:
                    warnings.append(f'{kind} not found whole with pdftotext {" ".join(mode) or "(default mode)"}')

    # Jobs: header, scope, bullets, chips as one contiguous run, in order
    position = 0
    for job in data["jobs"]:
        if designed:
            block = [job["title"], job["company"], job["time"], job["scope"], *job["bullets"], " ".join(job["chips"])]
        else:
            block = [job["title"], " | ".join(x for x in (job["company"], job["time"]) if x), job["scope"], *job["bullets"],
                     "Tech: " + ", ".join(job["chips"]) if job["chips"] else ""]
        want = squash(" ".join(x for x in block if x))
        at = flat.find(want, position)
        label = f'{job["title"]}, {job["company"]}'
        if at < 0:
            if flat.find(want) >= 0:
                errors.append(f"job out of order: {label}")
            else:
                missing = [b for b in job["bullets"] if squash(b) not in flat]
                detail = f"{len(missing)} bullet(s) not found, first: {missing[0]}" if missing else "its header, bullets and chips are all there but not contiguous"
                errors.append(f"job not read as one block: {label} ({detail})")
        else:
            position = at + len(want)
        if designed:
            for bullet in job["bullets"]:
                if bullet not in lines and squash(bullet) in flat:
                    errors.append(f"bullet wraps onto a second line ({len(bullet)} characters): {bullet}")
            chips = " ".join(job["chips"])
            if chips and chips not in lines and squash(chips) in flat:
                errors.append(f"chip row wraps ({len(job['chips'])} chips, {sum(map(len, job['chips']))} characters): {label}")

    # Skills
    if designed and data["skillsLine"]:
        skills = f'Skills: {data["skillsLine"]}'
        if squash(skills) not in flat:
            errors.append("the Skills line is not in the text")
        elif skills not in lines:
            errors.append(f"the Skills line wraps ({len(skills)} characters)")
    if not designed:
        skills = ", ".join(resume_data.all_skills(data))
        if skills and squash(skills) not in flat:
            errors.append("the Skills list is not in the text")

    # About: at most 4 lines in the sidebar (compared without spaces: it may break at a hyphen)
    if designed and data["about"]:
        tight = lambda t: re.sub(r"\s+", "", t).lower()
        about = tight(data["about"])
        start = next((i for i, l in enumerate(lines) if about.startswith(tight(l))), None)
        count, joined = 0, ""
        while start is not None and joined != about and about.startswith(joined) and start + count < len(lines):
            joined += tight(lines[start + count])
            count += 1
        if joined != about:
            errors.append("the about text is not in the text as one run")
        elif count > ABOUT_MAX_LINES:
            errors.append(f"the about text takes {count} lines (max {ABOUT_MAX_LINES})")

    # A variant's replaced text must be gone
    for old in data["replaced"]:
        if squash(old) in flat:
            errors.append(f"text the variant replaces is still in the file: {old}")

    return errors, warnings


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check how a printed resume reads back as text.")
    parser.add_argument("file")
    parser.add_argument("--plain", action="store_true", help="the single-column PDF: content checks only")
    resume_data.add_arguments(parser)
    args = parser.parse_args()
    data = resume_data.load_from_args(args)
    if not os.path.exists(args.file):
        sys.exit(f"Error: {args.file} not found")
    errors, warnings = check(args.file, data, args.plain, args.file.lower().endswith(".docx"))
    for w in warnings:
        print(f"  warning: {w}")
    if errors:
        print(f"EXTRACTION CHECK FAILED: {args.file}")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    layout = "" if args.plain or args.file.lower().endswith(".docx") else ", one page, nothing wrapped"
    print(f"Extraction check OK: {os.path.basename(args.file)} (name, contacts, {len(data['jobs'])} jobs in order{layout})")
