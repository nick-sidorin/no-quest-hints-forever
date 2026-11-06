#!/usr/bin/env python3
"""Validate the Forever addon manifest and build a verified installable ZIP.

The .toc file is the single source of truth for runtime contents. This avoids
publishing a build that passes Lua tests but accidentally omits a new module.
No third-party Python dependencies are required.
"""
from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parent.parent
ADDON = ROOT / "NoQuestHintsForever"
TOC = ADDON / "NoQuestHintsForever.toc"
LICENSE = ADDON / "LICENSE"
VERSION_RE = re.compile(r"^## Version:\s*(\d+\.\d+\.\d+)\s*$")
REL_PATTERN = re.compile(r"^[A-Za-z0-9._/-]+$")


def manifest() -> tuple[str, list[str]]:
    if not TOC.is_file() or not LICENSE.is_file():
        raise ValueError("Missing addon TOC or LICENSE")

    contents = TOC.read_text(encoding="utf-8-sig").splitlines()
    versions = [m.group(1) for line in contents if (m := VERSION_RE.match(line))]
    if len(versions) != 1:
        raise ValueError("Expected exactly one three-part version in TOC")

    listed: list[str] = []
    for line in contents:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if not REL_PATTERN.fullmatch(line):
            raise ValueError(f"Unexpected TOC path: {line!r}")
        part = PurePosixPath(line.replace("\\", "/"))
        if part.is_absolute() or ".." in part.parts or str(part) != line.replace("\\", "/"):
            raise ValueError(f"Unsafe TOC entry: {line!r}")
        if part.suffix.lower() not in {".lua", ".xml"}:
            raise ValueError(f"Unsupported runtime entry: {line!r}")
        relative = f"NoQuestHintsForever/{part.as_posix()}"
        if relative in listed:
            raise ValueError(f"Repeated TOC entry: {relative}")
        if not (ROOT / relative).is_file():
            raise ValueError(f"TOC references missing file: {relative}")
        listed.append(relative)

    if not listed or listed[0] != "NoQuestHintsForever/Localization.lua":
        raise ValueError("TOC unexpectedly empty or localization no longer loads first")

    actual_sources = {
        f"NoQuestHintsForever/{path.name}"
        for path in ADDON.iterdir()
        if path.is_file() and path.suffix.lower() in {".lua", ".xml"}
    }
    if set(listed) != actual_sources:
        raise ValueError(
            f"Runtime files differ from TOC; missing in manifest: {sorted(actual_sources - set(listed))}; "
            f"missing from disk: {sorted(set(listed) - actual_sources)}"
        )

    return versions[0], [
        "NoQuestHintsForever/NoQuestHintsForever.toc",
        *listed,
        "NoQuestHintsForever/LICENSE",
    ]


def verify_zip(output: Path, expected: list[str]) -> None:
    with zipfile.ZipFile(output) as archive:
        names = archive.namelist()
        if names != expected or len(names) != len(set(names)):
            raise ValueError(f"Archive contents differ from TOC: {names!r}")
        if archive.testzip() is not None:
            raise ValueError("Corrupt ZIP member")
        for name in names:
            if archive.read(name) != (ROOT / name).read_bytes():
                raise ValueError(f"ZIP contents differ from source: {name}")


def main() -> None:
    version, expected = manifest()
    if len(sys.argv) == 2 and sys.argv[1] == "--check":
        print(f"Verified TOC v{version} and {len(expected)} installable files")
        return
    if len(sys.argv) != 2:
        raise ValueError("Usage: python3 scripts/package_addon.py --check | dist/NoQuestHintsForever-vX.Y.Z.zip")
    path = Path(sys.argv[1])
    pattern = re.compile(
        rf"NoQuestHintsForever-v{re.escape(version)}(?:-(?:alpha|beta)(?:\.\d+)?)?\.zip$"
    )
    if not pattern.fullmatch(path.name):
        raise ValueError(f"ZIP name does not match TOC version v{version}: {path.name}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in expected:
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, (ROOT / name).read_bytes())
    verify_zip(path, expected)
    print(f"Built and verified {path} with {len(expected)} exact runtime files")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"RELEASE GATE FAILED: {error}", file=sys.stderr)
        sys.exit(1)
