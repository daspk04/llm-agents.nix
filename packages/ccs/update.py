#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#bun nixpkgs#git nixpkgs#jq --command python3

"""Custom update script for ccs package to force newer TypeScript."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    fetch_github_latest_release,
    load_hashes,
    regenerate_bun_nix,
    save_hashes,
    should_update,
)
from updater.nix import nix_prefetch_url

PKG_DIR = Path(__file__).parent
FLAKE_ROOT = PKG_DIR.parent.parent
HASHES_FILE = PKG_DIR / "hashes.json"
BUN_NIX = PKG_DIR / "bun.nix"

OWNER = "kaitranntt"
REPO = "ccs"


def main() -> None:
    """Update the ccs package."""
    data = load_hashes(HASHES_FILE)
    current = data.get("version", "0.0.0")
    latest = fetch_github_latest_release(OWNER, REPO)

    print(f"Current: {current}, Latest: {latest}")

    force = not BUN_NIX.exists()

    if not force and not should_update(current, latest):
        print("Already up to date")
        return

    print(f"Updating ccs from {current} to {latest}")

    # Step 1: Calculate new source hash
    print("Calculating source hash...")
    url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/v{latest}.tar.gz"
    src_hash = nix_prefetch_url(url, unpack=True)
    print(f"  source hash: {src_hash}")

    # Step 2: Update hashes.json
    save_hashes(HASHES_FILE, {"version": latest, "hash": src_hash})
    print("Updated hashes.json")

    # Step 3: Clone, patch and regenerate
    ref = f"v{latest}"
    with tempfile.TemporaryDirectory() as tmpdir:
        repo_dir = Path(tmpdir) / REPO
        print(f"Cloning {OWNER}/{REPO} at {ref}...")
        subprocess.run(
            [
                "git",
                "clone",
                "--depth=1",
                f"--branch={ref}",
                f"https://github.com/{OWNER}/{REPO}.git",
                str(repo_dir),
            ],
            check=True,
            capture_output=True,
        )

        # Merge ui dependencies into root package.json instead of using workspaces
        print(
            "Patching package.json to merge ui dependencies and use TypeScript 5.7..."
        )
        pkg_json_path = repo_dir / "package.json"
        pkg_json = json.loads(pkg_json_path.read_text())

        ui_pkg_json = json.loads((repo_dir / "ui" / "package.json").read_text())

        if "devDependencies" not in pkg_json:
            pkg_json["devDependencies"] = {}
        if "dependencies" not in pkg_json:
            pkg_json["dependencies"] = {}

        for dep_type in ["dependencies", "devDependencies"]:
            if dep_type in ui_pkg_json:
                for pkg, ver in ui_pkg_json[dep_type].items():
                    if pkg != "typescript":
                        pkg_json[dep_type][pkg] = ver

        # Check where typescript is and update it
        if "typescript" in pkg_json.get("dependencies", {}):
            pkg_json["dependencies"]["typescript"] = "^5.7.0"
        else:
            pkg_json["devDependencies"]["typescript"] = "^5.7.0"

        # Upgrade bun-types to support TS 5.7+
        pkg_json["devDependencies"]["bun-types"] = "^1.2.0"

        # Add missing types for UI build
        pkg_json["devDependencies"]["@types/prismjs"] = "^1.26.0"

        # Add missing types for backend to fix TS2742 errors
        pkg_json["devDependencies"]["@types/express-serve-static-core"] = "^4.19.0"
        pkg_json["devDependencies"]["@types/express"] = "^4.17.0"

        pkg_json_path.write_text(json.dumps(pkg_json, indent=2))

        # Generate new bun.lock
        print("Refreshing bun.lock...")
        subprocess.run(
            ["bun", "install", "--lockfile-only"],
            cwd=repo_dir,
            check=True,
            capture_output=True,
        )

        # Generate patch for source tarball
        print("Generating fix-stale-bun-lock.patch...")
        # We need both package.json and bun.lock changes in the patch
        # Initialize git in the temp repo to generate diff
        subprocess.run(
            ["git", "add", "package.json", "bun.lock"],
            cwd=repo_dir,
            check=True,
            capture_output=True,
        )
        diff_result = subprocess.run(
            ["git", "diff", "--staged"],
            cwd=repo_dir,
            check=True,
            capture_output=True,
            text=True,
        )
        (PKG_DIR / "fix-stale-bun-lock.patch").write_text(diff_result.stdout)

        # Regenerate bun.nix
        regenerate_bun_nix(repo_dir / "bun.lock", BUN_NIX, FLAKE_ROOT)

    print(f"Updated ccs to {latest}")


if __name__ == "__main__":
    main()
