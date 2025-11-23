#! /usr/bin/env python3
"""Fail if the Scarb.toml rpc url line is staged for commit."""

from __future__ import annotations

import subprocess
import sys


def staged_diff(path: str) -> str:
    """Return the staged diff for `path` or an empty string."""

    result = subprocess.run(
        ["git", "diff", "--cached", "--unified=0", "--", path],
        check=False,
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        # `git diff` returns 0 on success; any other code indicates an error.
        print("pre-commit: failed to inspect staged diff for Scarb.toml", file=sys.stderr)
        print(result.stderr.strip(), file=sys.stderr)
        sys.exit(result.returncode)

    return result.stdout


def main() -> int:
    diff = staged_diff("Scarb.toml")
    if not diff:
        return 0

    for line in diff.splitlines():
        if not line or line[0] not in {"+", "-"}:
            continue
        if line.startswith(("+url", "-url")):
            print(
                "pre-commit: Scarb.toml rpc url must not change; revert or drop it before committing.",
                file=sys.stderr,
            )
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
