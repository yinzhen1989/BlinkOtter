#!/usr/bin/env python3
"""Copy mpv's Homebrew dylib dependency closure into a macOS app."""
import pathlib
import shutil
import subprocess
import sys

app = pathlib.Path(sys.argv[1]).resolve()
frameworks = app / "Contents" / "Frameworks"
frameworks.mkdir(parents=True, exist_ok=True)
exe = app / "Contents" / "MacOS" / "BlinkOtter"
root = pathlib.Path("/opt/homebrew/lib/libmpv.dylib")
if not root.exists():
    raise SystemExit("libmpv.dylib missing. Run: brew install mpv")

def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)

def references(path):
    return [line.strip().split(" (")[0] for line in run("otool", "-L", str(path)).splitlines()[1:]]

def resolve(reference, parent):
    if reference.startswith("/opt/homebrew/"):
        return pathlib.Path(reference)
    if reference.startswith("@loader_path/"):
        candidate = parent.parent / reference.removeprefix("@loader_path/")
        return candidate if candidate.exists() else None
    return None

queue = [root]
copied = {}
while queue:
    original = queue.pop()
    if not original.exists():
        raise SystemExit(f"Missing dynamic library: {original}")
    source = original.resolve()
    name = original.name
    if name in copied:
        if copied[name] != source:
            raise SystemExit(f"Conflicting dylib basename: {name}")
        continue
    destination = frameworks / name
    shutil.copy2(source, destination)
    destination.chmod(0o755)
    copied[name] = source
    for reference in references(source):
        dependency = resolve(reference, source)
        if dependency and dependency.resolve() != source:
            queue.append(dependency)

for name, source in copied.items():
    destination = frameworks / name
    subprocess.run(["install_name_tool", "-id", f"@rpath/{name}", str(destination)], check=True)
    for reference in references(source):
        dependency = resolve(reference, source)
        if dependency and dependency.resolve() != source and dependency.name in copied:
            subprocess.run(["install_name_tool", "-change", reference,
                            f"@rpath/{dependency.name}", str(destination)], check=True)
    subprocess.run(["install_name_tool", "-add_rpath", "@loader_path", str(destination)],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

subprocess.run(["install_name_tool", "-add_rpath", "@executable_path/../Frameworks", str(exe)], check=True)
for reference in references(exe):
    dependency = resolve(reference, exe)
    if dependency and dependency.resolve() == root.resolve():
        subprocess.run(["install_name_tool", "-change", reference,
                        "@rpath/libmpv.dylib", str(exe)], check=True)
third_party = app / "Contents" / "Resources" / "ThirdParty"
third_party.mkdir(parents=True, exist_ok=True)
formulae = sorted({source.parts[4] for source in copied.values()
                  if len(source.parts) > 5 and source.parts[3] == "Cellar"})
for formula in formulae:
    matching = [p for p in copied.values() if p.parts[4] == formula]
    cellar = pathlib.Path("/opt/homebrew/Cellar") / formula / matching[0].parts[5]
    for license_file in cellar.glob("LICENSE*"):
        shutil.copy2(license_file, third_party / f"{formula}-{license_file.name}")
    for license_file in cellar.glob("COPYING*"):
        shutil.copy2(license_file, third_party / f"{formula}-{license_file.name}")
(third_party / "bundled-formulae.txt").write_text("\n".join(formulae) + "\n")
print(f"Bundled {len(copied)} dynamic libraries ({sum(p.stat().st_size for p in frameworks.iterdir()) // 1024 // 1024} MiB)")
