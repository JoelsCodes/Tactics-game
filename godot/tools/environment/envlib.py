"""Search classified assets and enforce the packaging gate without launching Blender."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

STATUS = {"Production Ready": "REUSE", "Needs Improvement": "ADAPT", "Prototype": "CREATE"}
REQUIRED = {"art", "tactics", "engine", "rights", "delivery"}


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def asset_index(root):
    entries = read(root / "asset_manifest.json")["assets"]
    index = {a["id"]: a for a in entries}
    if len(index) != len(entries) or any(a["status"] not in STATUS for a in entries):
        raise ValueError("Invalid asset manifest")
    for asset in entries:
        if asset["status"] == "Production Ready":
            checks = asset.get("evidence", {})
            path = root / asset["file"]
            if not all(checks.get(k) for k in ("art", "godot", "rights")):
                raise ValueError(f'Incomplete asset qualification: {asset["id"]}')
            if not path.is_file() or digest(path) != asset.get("sha256"):
                raise ValueError(f'Asset changed since qualification: {asset["id"]}')
    return index


def choose(root, query, tags=(), bounds=None):
    terms = query.casefold().split()
    found = []
    for asset in asset_index(root).values():
        text = " ".join(asset.get(k, "") for k in ("id", "name", "category", "description"))
        text = (text+" "+" ".join(asset.get("tags", []))).casefold()
        if not all(t in text for t in terms) or not set(tags).issubset(asset.get("tags", [])):
            continue
        dimensions = asset.get("dimensions_m")
        if bounds and (not dimensions or any(x > m + .001 for x, m in zip(dimensions, bounds))):
            continue
        found.append({"action": STATUS[asset["status"]], **asset})
    found.sort(key=lambda a: (list(STATUS).index(a["status"]), a["id"]))
    return found or [{"action": "CREATE", "reason": "No asset matches this brief and required tags"}]


def package(folder, review_path, output):
    review = read(review_path)
    record = read(folder / "build.json")
    technical = read(folder / "godot-validation.json")
    if review.get("mode") != "battle_map" or record.get("mode") != "battle_map":
        raise ValueError("Release requires a battle map and its authoritative gameplay data")
    checks = review.get("gates", {})
    for gate in REQUIRED:
        evidence = checks.get(gate, {})
        if evidence.get("status") != "pass" or not evidence.get("evidence"):
            raise ValueError(f"Release gate remains open: {gate}")
    if technical.get("status") != "pass" or technical.get("project") != "Hollowmark" or not technical.get("captured_frame"):
        raise ValueError("Hollowmark import validation is required")
    if not (folder / "godot-preview.png").is_file() or digest(folder / "godot-preview.png") != technical.get("frame_sha256"):
        raise ValueError("Godot frame evidence is missing or stale")
    if technical.get("glb_sha256") != record["files"]["map.glb"]:
        raise ValueError("Godot report refers to a different GLB")
    if review.get("files") != record["files"]:
        raise ValueError("Review refers to a different build")
    for name, checksum in record["files"].items():
        if Path(name).name != name or digest(folder / name) != checksum:
            raise ValueError(f"Changed or invalid build artifact: {name}")
    with zipfile.ZipFile(output, "x", zipfile.ZIP_DEFLATED) as archive:
        for name in sorted(record["files"] | {"build.json": 0, "godot-validation.json": 0, "godot-preview.png": 0}):
            archive.write(folder/name, name)
        archive.write(review_path, "review.json")


def main():
    p = argparse.ArgumentParser()
    s = p.add_subparsers(dest="command", required=True)
    find = s.add_parser("search")
    find.add_argument("root", type=Path)
    find.add_argument("query")
    find.add_argument("--tag", action="append", default=[])
    find.add_argument("--fits", nargs=3, type=float, metavar=("X", "Y", "Z"))
    release = s.add_parser("package")
    for arg in ("folder", "review", "output"):
        release.add_argument(arg, type=Path)
    a = p.parse_args()
    if a.command == "search":
        print(json.dumps(choose(a.root,a.query,a.tag,a.fits),indent=2))
    else:
        package(a.folder,a.review,a.output)


if __name__ == "__main__":
    main()
