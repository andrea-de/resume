"""The resume as it prints: resume.json with the region, variant and location applied.

index.html does the same in the browser (loadResume / applyVariant). The Word file, the
plain PDF and check-extract.sh read the data through here, so they show the same text as
the designed PDF.

As a command it validates a variant before a print and names the location it carries:
    python3 tools/resume_data.py --variant acme     # prints the variant's location, if any
"""
import argparse
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = "https://www.andreadecandia.com"
VARIANT_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")


class ResumeError(Exception):
    pass


def strip_tags(text):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", text or "")).strip()


def bare_url(href):
    return re.sub(r"/$", "", re.sub(r"^https?://(www\.)?", "", href))


def load_variant(name):
    """variants/<name>.json, checked against nothing yet (apply_variant does that)."""
    if not VARIANT_NAME.match(name):
        raise ResumeError(f'variant name "{name}" is not valid (letters, digits, - and _)')
    path = os.path.join(REPO, "variants", f"{name}.json")
    if not os.path.exists(path):
        have = sorted(f[:-5] for f in os.listdir(os.path.join(REPO, "variants")) if f.endswith(".json"))
        raise ResumeError(f'unknown variant "{name}": variants/{name}.json not found (have: {", ".join(have) or "none"})')
    try:
        with open(path) as f:
            variant = json.load(f)
    except json.JSONDecodeError as e:
        raise ResumeError(f"variants/{name}.json is not valid JSON: {e}")
    unknown = set(variant) - {"note", "location", "skillsLine", "jobs"}
    if unknown:
        raise ResumeError(f'variant "{name}": unknown key(s) {", ".join(sorted(unknown))}')
    return variant


def apply_variant(resume, variant, name):
    """Swap the variant's text into the resume; returns the generic bullets it replaced."""
    replaced = []
    for company, override in (variant.get("jobs") or {}).items():
        job = next((j for j in resume.get("workExperience", []) if j.get("company") == company), None)
        if job is None:
            raise ResumeError(f'variant "{name}": no job at "{company}" in resume.json')
        unknown = set(override) - {"chips", "bullets", "unifiedScope"}
        if unknown:
            raise ResumeError(f'variant "{name}" / {company}: unknown key(s) {", ".join(sorted(unknown))}')
        if isinstance(override.get("chips"), list):
            job["chips"] = override["chips"]
        if override.get("unifiedScope"):
            job["unifiedScope"] = override["unifiedScope"]
        for scope, text in (override.get("bullets") or {}).items():
            resp = next((r for r in job.get("responsibilities", [])
                         if isinstance(r, dict) and r.get("scope") == scope), None)
            if resp is None:
                raise ResumeError(f'variant "{name}" / {company}: no responsibility with scope "{scope}"')
            replaced += [d for d in resp.get("details") or [] if d != text]
            resp["details"] = [text]
    if variant.get("skillsLine"):
        resume["skillsLine"] = variant["skillsLine"]
    return replaced


def job_chips(job):
    if isinstance(job.get("chips"), list):
        return list(job["chips"])
    chips, seen = [], set()
    for resp in job.get("responsibilities") or []:
        if not isinstance(resp, dict) or not resp.get("tech"):
            continue
        for tech in strip_tags(resp["tech"]).split(","):
            tech = tech.strip()
            if tech and tech.lower() not in seen:
                seen.add(tech.lower())
                chips.append(tech)
    return chips


def job_bullets(job):
    bullets = []
    for resp in job.get("responsibilities") or []:
        if isinstance(resp, dict):
            bullets += resp.get("details") or ([resp["description"]] if resp.get("description") else [])
        elif isinstance(resp, str) and resp.strip():
            bullets.append(resp)
    return bullets


def load(region="us", variant=None, location=None, code=None):
    """The effective resume: a dict of plain values, in the order they print."""
    with open(os.path.join(REPO, "resume.json")) as f:
        resume = json.load(f)

    # Alternates (earlier wordings kept in resume.json, never printed) must not be in a print
    replaced = [alt for job in resume.get("workExperience", []) for resp in job.get("responsibilities") or []
                if isinstance(resp, dict) for alt in resp.get("alternates") or []]
    variant_data = None
    if variant:
        variant_data = load_variant(variant)
        replaced += apply_variant(resume, variant_data, variant)
    location = (location or (variant_data or {}).get("location") or "").strip()

    contacts = {}
    for c in resume.get("contact", []):
        if c.get("hidden") or (c.get("region") and c["region"] != region):
            continue
        kind = c["icon"].replace("-img", "")
        if kind == "website":
            href = f"{SITE}/r/{code}" if code else c["href"]
            # the designed PDF shows the bare domain and links it; plain text shows the link itself
            contacts[kind] = {"text": "andreadecandia.com", "href": href,
                              "plain": bare_url(href) if code else "andreadecandia.com"}
        elif kind == "linkedin":
            contacts[kind] = {"text": bare_url(c["href"]), "href": c["href"]}
        else:
            contacts[kind] = {"text": c["text"], "href": c.get("href")}

    jobs = []
    for job in resume.get("workExperience", []):
        if job.get("hidden"):
            continue
        prefix = job.get("jobTitlePrefix") if not job.get("hidePrefix") else None
        jobs.append({
            "title": f"{prefix} {job['jobTitle']}" if prefix else job["jobTitle"],
            "company": job.get("company", ""),
            "time": job.get("time", ""),
            "scope": job.get("unifiedScope", ""),
            "bullets": job_bullets(job),
            "chips": job_chips(job),
        })

    education = resume.get("education") or {}
    return {
        "name": strip_tags(resume["personalInfo"]["name"]),
        "title": resume["personalInfo"].get("title", ""),
        "about": resume.get("about", ""),
        "contacts": contacts,
        "location": location,
        "jobs": jobs,
        "education": {"school": education.get("school", ""), "degrees": education.get("degrees", []),
                      "description": education.get("description", "")},
        "skillsLine": resume.get("skillsLine", ""),
        "replaced": [r for r in replaced if r not in {b for j in jobs for b in j["bullets"]}],
        "region": region,
        "variant": variant or "",
        "code": code or "",
    }


def all_skills(data):
    """The Skills line first, then every job's technologies not already named."""
    skills, seen = [], set()
    for skill in [s.strip() for s in data["skillsLine"].split(",")] + [c for j in data["jobs"] for c in j["chips"]]:
        if skill and skill.lower() not in seen:
            seen.add(skill.lower())
            skills.append(skill)
    return skills


def add_arguments(parser):
    parser.add_argument("--region", default="us", choices=["us", "eu"])
    parser.add_argument("--variant", default="")
    parser.add_argument("--location", default="")
    parser.add_argument("--code", default="")


def load_from_args(args):
    try:
        return load(args.region, args.variant or None, args.location or None, args.code or None)
    except ResumeError as e:
        sys.exit(f"Error: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Validate a variant; prints the location it carries.")
    add_arguments(parser)
    print(load_from_args(parser.parse_args())["location"])
