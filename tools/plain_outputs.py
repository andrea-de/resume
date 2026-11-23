"""Plain single-column versions of the resume, from the same data as the designed PDF.

    .venv/bin/python tools/plain_outputs.py <name> [--region us|eu] [--variant <name>]
                                            [--location <text>] [--code <code>]

Writes <name>.docx (Word) and .plain-<name>.html (make-plain.sh prints that to
<name>-plain.pdf and removes it). Both are made for software that reads resumes: one
column, real headings, name and contacts first as plain text, each job as title,
company | dates, bullets and a "Tech:" line, then Education and Skills. No tables, text
boxes, headers, footers or images; no hyperlink fields in the Word file (some readers
drop their text).
"""
import argparse
import html
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import resume_data


def contact_lines(data):
    """Two lines of contacts: [(text, href or None), ...] each."""
    c = data["contacts"]
    first = [(c[k]["text"], c[k].get("href")) for k in ("email", "phone") if k in c]
    if data["location"]:
        first.append((data["location"], None))
    second = [(c[k].get("plain", c[k]["text"]), c[k].get("href")) for k in ("linkedin", "github", "website") if k in c]
    return [first, second]


def write_html(data, path):
    e = html.escape
    link = lambda text, href: f'<a href="{e(href)}">{e(text)}</a>' if href else e(text)
    out = [
        '<!doctype html><html lang="en"><head><meta charset="utf-8">',
        f'<title>{e(data["name"])} - {e(data["title"])} - Resume</title>',
        # sized so the generic resume fills one Letter page
        "<style>@page{size:letter;margin:0.4in 0.5in}"
        "body{font:8.7pt/1.2 Helvetica,Arial,'Liberation Sans',sans-serif;color:#111;margin:0}"
        "h1{font-size:18pt;margin:0}h2{font-size:11pt;margin:5pt 0 2pt;border-bottom:1px solid #999}"
        "h3{font-size:9.5pt;margin:4pt 0 0}p{margin:0.5pt 0}ul{margin:1pt 0 1pt 16pt;padding:0}li{margin:0}"
        "a{color:inherit;text-decoration:none}</style></head><body>",
        f'<h1>{e(data["name"])}</h1>',
        f'<p>{e(data["title"])}</p>',
    ]
    out += ["<p>" + " | ".join(link(t, h) for t, h in line) + "</p>" for line in contact_lines(data) if line]
    if data["about"]:
        out += ["<h2>Summary</h2>", f'<p>{e(data["about"])}</p>']
    out.append("<h2>Work Experience</h2>")
    for job in data["jobs"]:
        out.append(f'<h3>{e(job["title"])}</h3>')
        out.append(f'<p>{e(" | ".join(x for x in (job["company"], job["time"]) if x))}</p>')
        if job["scope"]:
            out.append(f'<p><i>{e(job["scope"])}</i></p>')
        if job["bullets"]:
            out.append("<ul>" + "".join(f"<li>{e(b)}</li>" for b in job["bullets"]) + "</ul>")
        if job["chips"]:
            out.append(f'<p>Tech: {e(", ".join(job["chips"]))}</p>')
    ed = data["education"]
    if ed["school"]:
        out += ["<h2>Education</h2>", f'<h3>{e(ed["school"])}</h3>']
        if ed["degrees"]:
            out.append(f'<p>{e(", ".join(ed["degrees"]))}</p>')
        if ed["description"]:
            out.append(f'<p>{e(ed["description"])}</p>')
    skills = resume_data.all_skills(data)
    if skills:
        out += ["<h2>Skills</h2>", f'<p>{e(", ".join(skills))}</p>']
    out.append("</body></html>")
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")


def write_docx(data, path):
    from docx import Document
    from docx.shared import Inches, Pt

    doc = Document()
    for section in doc.sections:
        section.page_width, section.page_height = Inches(8.5), Inches(11)
        section.left_margin = section.right_margin = Inches(0.7)
        section.top_margin = section.bottom_margin = Inches(0.6)
    doc.core_properties.author = data["name"]
    doc.core_properties.title = f'{data["name"]} - {data["title"]} - Resume'
    doc.styles["Normal"].font.size = Pt(10.5)

    def para(text, italic=False, style=None):
        p = doc.add_paragraph(style=style)
        p.paragraph_format.space_after = Pt(2)
        p.add_run(text).italic = italic
        return p

    doc.add_heading(data["name"], 0)
    para(data["title"])
    for line in contact_lines(data):
        if line:
            para(" | ".join(text for text, _ in line))
    if data["about"]:
        doc.add_heading("Summary", 1)
        para(data["about"])
    doc.add_heading("Work Experience", 1)
    for job in data["jobs"]:
        doc.add_heading(job["title"], 2)
        para(" | ".join(x for x in (job["company"], job["time"]) if x))
        if job["scope"]:
            para(job["scope"], italic=True)
        for bullet in job["bullets"]:
            para(bullet, style="List Bullet")
        if job["chips"]:
            para("Tech: " + ", ".join(job["chips"]))
    ed = data["education"]
    if ed["school"]:
        doc.add_heading("Education", 1)
        doc.add_heading(ed["school"], 2)
        if ed["degrees"]:
            para(", ".join(ed["degrees"]))
        if ed["description"]:
            para(ed["description"])
    skills = resume_data.all_skills(data)
    if skills:
        doc.add_heading("Skills", 1)
        para(", ".join(skills))
    doc.save(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Write <name>.docx and .plain-<name>.html")
    parser.add_argument("name")
    parser.add_argument("--no-docx", action="store_true", help="only the HTML (python-docx not needed)")
    resume_data.add_arguments(parser)
    args = parser.parse_args()
    data = resume_data.load_from_args(args)
    os.chdir(resume_data.REPO)
    write_html(data, f".plain-{args.name}.html")
    if not args.no_docx:
        write_docx(data, f"{args.name}.docx")
