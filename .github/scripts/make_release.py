#!/usr/bin/env python3
"""Chuẩn bị tệp phát hành: tên cố định + update.json (Agent tự cập nhật).

    make_release.py <thư mục bộ cài> <tag> <owner/repo> <pubspec.yaml>

Thư mục chứa `TramInEasyPOS-Setup-<ver>.exe` và `easypos-print-agent_<ver>_amd64.deb` (do CI build).
Kiểm tra tag khớp `version:` trong pubspec (đẩy nhầm tag thì dừng, không phát hành bản sai). Ghi thêm:
- `TramInEasyPOS-Setup.exe`, `easypos-print-agent_amd64.deb`: tên cố định cho link `releases/latest/download/...`;
- `update.json`: {version, build, notes, windows:{url,sha256}, linux:{url,sha256}}.
"""
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path
from urllib.parse import quote


def read_version(pubspec: str) -> tuple[str, int]:
    m = re.search(r"^version:\s*([0-9]+(?:\.[0-9]+)*)(?:\+([0-9]+))?", pubspec, re.M)
    if not m:
        raise SystemExit("Không đọc được version trong pubspec.yaml")
    return m.group(1), int(m.group(2) or 0)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def build_manifest(version: str, build: int, tag: str, repo: str, exe: Path, deb: Path) -> dict:
    base = f"https://github.com/{repo}/releases/download/{quote(tag)}"
    return {
        "version": version,
        "build": build,
        "windows": {"url": f"{base}/{quote(exe.name)}", "sha256": sha256(exe)},
        "linux": {"url": f"{base}/{quote(deb.name)}", "sha256": sha256(deb)},
    }


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        print(__doc__)
        return 64
    dist, tag, repo, pubspec = Path(argv[1]), argv[2], argv[3], Path(argv[4])
    version, build = read_version(pubspec.read_text(encoding="utf-8"))
    if tag != f"v{version}":
        print(f"Tag {tag} không khớp version trong pubspec ({version}) — sửa pubspec hoặc đẩy lại tag.")
        return 1
    exes = sorted(dist.glob("TramInEasyPOS-Setup-*.exe"))
    debs = sorted(dist.glob("easypos-print-agent_*_amd64.deb"))
    if len(exes) != 1 or len(debs) != 1:
        print(f"Cần đúng 1 .exe và 1 .deb trong {dist}, thấy {len(exes)} / {len(debs)}")
        return 1
    exe, deb = exes[0], debs[0]
    manifest = build_manifest(version, build, tag, repo, exe, deb)
    shutil.copy(exe, dist / "TramInEasyPOS-Setup.exe")
    shutil.copy(deb, dist / "easypos-print-agent_amd64.deb")
    (dist / "update.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
