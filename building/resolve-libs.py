import hashlib
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ElementTree

SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")


def resolve(url, ref):
    if ref and SHA_PATTERN.match(ref):
        return ref
    targets = [f"refs/heads/{ref}", f"refs/tags/{ref}^{{}}", f"refs/tags/{ref}"] if ref else ["HEAD"]
    try:
        output = subprocess.run(["git", "ls-remote", url] + targets, capture_output=True, text=True, timeout=60, check=True).stdout
    except Exception as error:
        print(f"::warning::Could not resolve {url} ({ref or 'HEAD'}): {error}", file=sys.stderr)
        return None
    refs = {}
    for line in output.splitlines():
        parts = line.split("\t")
        if len(parts) == 2:
            refs[parts[1]] = parts[0]
    for target in targets:
        if target in refs:
            return refs[target]
    return None


def main():
    libs_file = sys.argv[1] if len(sys.argv) > 1 else "building/libs.xml"
    extra_files = sys.argv[2:]
    root = ElementTree.parse(libs_file).getroot()
    rows = []
    digest = hashlib.sha256()
    for element in root.iter():
        if element.tag == "git":
            name = element.get("name")
            url = element.get("url")
            ref = element.get("ref")
            commit = resolve(url, ref) or f"unresolved:{ref or 'HEAD'}"
            rows.append((name, ref or "default", commit))
            digest.update(f"git {name} {url} {commit}\n".encode())
        elif element.tag == "lib":
            name = element.get("name")
            version = element.get("version") or "latest"
            rows.append((name, "haxelib", version))
            digest.update(f"lib {name} {version} {element.get('global', '')}\n".encode())
    for path in [libs_file] + extra_files:
        with open(path, "rb") as handle:
            digest.update(handle.read())

    key = digest.hexdigest()[:20]
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a") as handle:
            handle.write(f"key={key}\n")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as handle:
            handle.write("### Libraries\n| Library | Source | Version |\n| --- | --- | --- |\n")
            for name, source, version in rows:
                shown = version[:10] if SHA_PATTERN.match(version) else version
                handle.write(f"| {name} | {source} | `{shown}` |\n")
            handle.write(f"\nCache key: `{key}`\n")
    print(key)


if __name__ == "__main__":
    main()
