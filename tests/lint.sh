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
for f in install.sh scripts/*.sh scripts/lib/*.sh distribution/skills/*/*.sh tests/*.sh; do
  bash -n "$f" || bad "$f"
done

step "ShellCheck (warnings and errors)"
if command -v shellcheck >/dev/null; then
  shellcheck -S warning install.sh scripts/*.sh scripts/lib/*.sh distribution/skills/*/*.sh tests/*.sh || bad "shellcheck"
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

step "Council members: card, tag, voice, strength dial"
C=distribution/skills/council
for p in "$C"/members/[!_]*.md; do
  n="$(basename "$p" .md)"
  grep -qE '^Seat: .+ · Tag: .+$' "$p" || bad "$n: second line must be 'Seat: <role> · Tag: <Name>'"
  grep -qx '## Card' "$p" || bad "$n: no '## Card' section"
  grep -qx '## Full' "$p" || bad "$n: no '## Full' section"
  lines="$(awk '/^## Card/{on=1; next} /^## /{on=0} on && /^- /' "$p" | wc -l)"
  [[ "$lines" -ge 5 && "$lines" -le 8 ]] || bad "$n: Card has $lines bullets (5-8: it's loaded in every chat)"
  for lvl in 1 3 5; do grep -qE "^$lvl: \"" "$p" || bad "$n: Strength dial is missing level $lvl"; done
  tag="$(sed -n 's/^Seat: .*· Tag: //p' "$p")"
  grep -q "Sample: \"$tag: " "$p" || bad "$n: the Card's Sample must start with '$tag: '"
  grep -qE "^${n}[[:space:]]+[a-z]+[[:space:]]+[0-9.]+[[:space:]]+[A-Za-z-]+Neural[[:space:]]+[0-9.]+[[:space:]]+[A-Za-z0-9]{20}$" "$C/members/voices.conf" \
    || bad "$n: needs a full line in members/voices.conf (xai voice, speed, edge voice, speed, elevenlabs id)"
done
tags="$(sed -n 's/^Seat: .*· Tag: //p' "$C"/members/[!_]*.md | tr '[:upper:]' '[:lower:]' | sort)"
[[ -z "$(uniq -d <<<"$tags")" ]] || bad "two members share a tag: $(uniq -d <<<"$tags" | tr '\n' ' ')"

step "Council SOUL: builds, stays lean, carries the guardrails"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/skills"; cp -r "$C" "$tmp/skills/"
B="$tmp/skills/council/build-soul.sh"
PATH=/usr/bin:/bin bash "$B" --no-voice >/dev/null || bad "build-soul (default roster)"
size="$(wc -c <"$tmp/SOUL.md")"
[[ "$size" -le 26000 ]] || bad "default SOUL.md is $size bytes (budget 26000)"
for want in "Marcus speaks last" "disagree about approach, never about facts" "One turn each" "Members advise; only you act" \
            "## Approvals and safety" "## Memory" "(tag \`Marcus:\`)" "On the bench"; do
  grep -qF "$want" "$tmp/SOUL.md" || bad "SOUL.md is missing: $want"
done
for p in "$C"/members/[!_]*.md; do
  n="$(basename "$p" .md)"; [[ "$n" == marcus ]] && continue
  PATH=/usr/bin:/bin bash "$B" --no-voice --roster "marcus $n" >/dev/null || bad "build-soul with $n seated"
  grep -qF "$(sed -n '1s/^# //p' "$p")," "$tmp/SOUL.md" || bad "$n's card isn't in the SOUL when seated"
done
PATH=/usr/bin:/bin bash "$B" --no-voice --bench marcus >/dev/null 2>&1 && bad "Marcus could be benched"
PATH=/usr/bin:/bin bash "$B" --no-voice --defaults >/dev/null
grep -q '^SEATED=' "$tmp/council.conf" || bad "council.conf not written"
[[ -f "$tmp/notes/council.md" ]] || bad "notes/council.md not seeded"

for p in "$C"/members/[!_]*.md; do
  grep -q '^Seat: .*(bench)' "$p" || continue
  n="$(basename "$p" .md)"
  for h in "### Works with" "### Ask " "### When to seat"; do
    grep -q "^$h" "$p" || bad "$n is on the bench but has no '$h' section"
  done
done
PATH=/usr/bin:/bin bash "$B" --no-voice --roster "$(cd "$C/members" && ls [!_]*.md | sed 's/\.md$//' | tr '\n' ' ')" >/dev/null || bad "build-soul with everyone seated"
size="$(wc -c <"$tmp/SOUL.md")"
[[ "$size" -le 30000 ]] || bad "SOUL.md with all members seated is $size bytes (limit 30000)"
PATH=/usr/bin:/bin bash "$B" --no-voice --defaults >/dev/null

step "Deep dives: every module is listed with a host"
for m in distribution/skills/deep-dive/modules/*.md; do
  f="$(basename "$m")"
  area="$(grep -F "| $f |" distribution/skills/deep-dive/SKILL.md | cut -d'|' -f2 | sed 's/^ *//; s/ *$//')"
  [[ -n "$area" ]] || { bad "deep-dive module $f isn't in the modules table"; continue; }
  grep -qE "^\| $area \| [A-Z]" distribution/skills/deep-dive/SKILL.md <<<"$(grep -v "| $f |" distribution/skills/deep-dive/SKILL.md)" || bad "deep-dive area '$area' has no host"
  grep -qF "| $area |" templates/notes/onboarding-plan.md || bad "deep-dive area '$area' isn't on the Life Map template"
done

step "Full council: five panelists, Marcus chairs"
grep -q 'Exactly five panelists' distribution/skills/convene/SKILL.md || bad "convene must say: Exactly five panelists"
grep -q 'Marcus is never one of them' distribution/skills/convene/SKILL.md || bad "convene must keep Marcus as chair, not a panelist"

step "Skills reference only skills that exist"
for s in $(grep -rhoE '`[a-z][a-z-]+` skill|load(s)? (the )?`[a-z][a-z-]+`' distribution/skills | grep -oE '`[a-z-]+`' | tr -d '`' | sort -u); do
  [[ -f "distribution/skills/$s/SKILL.md" ]] || bad "a skill mentions '$s', which doesn't exist"
done

step "Plugins: compile, unit tests, shipped with the profile"
for f in distribution/plugins/*/; do
  n="$(basename "$f")"
  [[ -f "$f/plugin.yaml" && -f "$f/__init__.py" ]] || bad "$n needs plugin.yaml and __init__.py"
  grep -qx "  - plugins/$n" distribution/distribution.yaml || bad "plugins/$n is not in distribution_owned"
  python3 -B -c 'import ast,sys; [ast.parse(open(p).read(), p) for p in sys.argv[1:]]' "$f"*.py || bad "$n: Python syntax"
done
python3 -B tests/council_voices/test_council_voices.py >/dev/null 2>&1 || bad "council-voices tests (run: python3 tests/council_voices/test_council_voices.py)"
python3 -B tests/council_privacy/test_council_privacy.py >/dev/null 2>&1 || bad "council-privacy tests (run: python3 tests/council_privacy/test_council_privacy.py)"

step "Tested Hermes version is recorded"
grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' HERMES_VERSION 2>/dev/null || bad "HERMES_VERSION missing or not x.y.z"

echo
if [[ $fail -eq 0 ]]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $fail
