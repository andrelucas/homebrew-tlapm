"""Refresh the formula from the public TLAPM rolling release metadata."""

import hashlib
import json
import re
from datetime import datetime
from pathlib import Path
from urllib.request import Request, urlopen


def github_json(path):
    request = Request(
        f"https://api.github.com/repos/tlaplus/tlapm/{path}",
        headers={"Accept": "application/vnd.github+json"},
    )
    with urlopen(request, timeout=30) as response:
        return json.load(response)


rolling = next(
    (
        release for release in github_json("releases")
        if release["prerelease"] and not release["draft"]
        and "rolling pre-release" in (release["name"] or "").lower()
        and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+-pre", release["tag_name"])
    ),
    None,
)
if rolling is None:
    raise SystemExit("No TLAPM rolling pre-release found")

tag = rolling["tag_name"]
commit = github_json(f"commits/{tag}")
sha = commit["sha"]
if not re.fullmatch(r"[0-9a-f]{40}", sha):
    raise SystemExit(f"No valid commit SHA found for {tag}")
committed = datetime.strptime(commit["commit"]["committer"]["date"], "%Y-%m-%dT%H:%M:%SZ")
url = f"https://github.com/tlaplus/tlapm/archive/{sha}.tar.gz"
version = f"{tag}.{committed:%Y%m%d%H%M%S}"

formula = Path(__file__).resolve().parents[1] / "Formula" / "tlapm.rb"
original = formula.read_text()
pins = re.findall(r'^  url "([^"\n]+)"\n  version "([^"\n]+)"\n  sha256 "([0-9a-f]{64})"$',
                  original, re.MULTILINE)
if len(pins) != 1:
    raise SystemExit("Expected one URL, version and SHA-256 block in Formula/tlapm.rb")
old_url, old_version, old_digest = pins[0]
if (url, version) != (old_url, old_version):
    with urlopen(url, timeout=60) as archive:
        digest = hashlib.sha256(archive.read()).hexdigest()
    old_pins = f'  url "{old_url}"\n  version "{old_version}"\n  sha256 "{old_digest}"'
    new_pins = f'  url "{url}"\n  version "{version}"\n  sha256 "{digest}"'
    updated = original.replace(old_pins, new_pins, 1)
    # Bottle checksums apply to the previously packaged source version.
    updated = re.sub(r"\n  bottle do\n(?:    [^\n]*\n)*  end\n", "", updated)
    formula.write_text(updated)
print(f"TLAPM {version} ({sha[:7]})")
