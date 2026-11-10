# Pinned shared development standards

Source: [wow-addon-standards](https://github.com/nick-sidorin/wow-addon-standards). The exact adopted commit, version and SHA-256 hashes are in [standards.lock.json](standards.lock.json). Root `AGENTS.md` instructs agents to read the copied documents. The addon does not load these files; they are excluded from installable packages.

## Check locally

```bash
python3 scripts/standards.py check
```

This verifies local consistency, not upstream authenticity or product suitability. CI runs it without network access.

## Adopt an update

1. Fetch the standards repository into a separate local clone. Review the changes and choose its full commit SHA, not a moving branch.
2. Create an adoption branch in this repository. Run:

```bash
python3 scripts/standards.py sync --source /path/to/wow-addon-standards --commit <full-reviewed-sha> --target .
bash scripts/run_ci.sh
```

3. Review copied documents, lock changes and any conflict with local product rules. Open a PR. Change root `AGENTS.md` only when the project profile actually needs to change.

The sync tool reads the selected Git snapshot rather than the source working tree. It does not fetch, execute downloaded code, change gameplay or overwrite the root agent instructions. To update the tool itself, separately review the upstream `tools/standards.py` diff and copy it to `scripts/standards.py` in the PR. No game installation, TOC version bump or release is required for documentation updates.
