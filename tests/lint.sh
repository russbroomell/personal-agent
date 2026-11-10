#!/usr/bin/env bash
# Fast checks for every change; GitHub runs these on each pull request.
# Run locally before opening one:   bash tests/lint.sh
# Needs: shellcheck (apt install shellcheck, or pip install shellcheck-py), python3 with PyYAML.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
fail=0
step() { printf '\n== %s\n' "$*"; }
bad()  { printf '  FAIL %s\n' "$*"; fail=1; }

step "Shell syntax"
for f in scripts/*.sh scripts/lib/*.sh distribution/skills/*/*.sh tests/*.sh; do
  bash -n "$f" || bad "$f"
done

step "ShellCheck (warnings and errors)"
if command -v shellcheck >/dev/null; then
  shellcheck -S warning scripts/*.sh scripts/lib/*.sh distribution/skills/*/*.sh tests/*.sh || bad "shellcheck"
else
  echo "  shellcheck not installed; skipped"
fi

step "Python"
python3 -m py_compile scripts/memory-card/server.py || bad "memory-card/server.py"

step "Skills: valid frontmatter with name and description"
python3 - <<'PY' || fail=1
import pathlib, sys, yaml
bad = 0
for p in sorted(pathlib.Path("distribution/skills").glob("*/SKILL.md")):
    text = p.read_text()
    if not text.startswith("---\n"):
        print(f"  FAIL {p}: no frontmatter"); bad = 1; continue
    try:
        meta = yaml.safe_load(text.split("---\n", 2)[1])
    except yaml.YAMLError as e:
        print(f"  FAIL {p}: {e}"); bad = 1; continue
    for key in ("name", "description"):
        if not meta.get(key):
            print(f"  FAIL {p}: missing {key}"); bad = 1
    if meta.get("name") != p.parent.name:
        print(f"  FAIL {p}: name '{meta.get('name')}' != folder '{p.parent.name}'"); bad = 1
print("  ok" if not bad else "")
sys.exit(bad)
PY

step "Config files parse"
python3 - <<'PY' || fail=1
import yaml, sys
for f in ("distribution/config.yaml", "distribution/distribution.yaml"):
    try:
        yaml.safe_load(open(f))
    except Exception as e:
        print(f"  FAIL {f}: {e}"); sys.exit(1)
print("  ok")
PY

step "Characters: each has a voice and builds a SOUL"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/skills"; cp -r distribution/skills/persona-switch "$tmp/skills/"
for p in distribution/skills/persona-switch/personas/[!_]*.md; do
  n="$(basename "$p" .md)"
  grep -qE "^${n}[[:space:]]" distribution/skills/persona-switch/personas/voices.conf || bad "$n has no line in voices.conf"
  PATH=/usr/bin:/bin bash "$tmp/skills/persona-switch/build-soul.sh" "$n" >/dev/null || bad "build-soul $n"
  grep -q "House rules\|house rules\|## " "$tmp/SOUL.md" || bad "SOUL for $n looks empty"
done

step "Tested Hermes version is recorded"
grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' HERMES_VERSION 2>/dev/null || bad "HERMES_VERSION missing or not x.y.z"

echo
if [[ $fail -eq 0 ]]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $fail
