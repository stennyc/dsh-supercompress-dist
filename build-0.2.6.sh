#!/usr/bin/env bash
# build-0.2.6.sh — package the VARIANT-BRANCHED 0.2.6 dist (owner 2026-11-28:
# "你需要分支" — the phone host rc.1 presents the settings card as a GENERATED
# form from the Config schema; the local host rc.5 presents a HAND-DRAWN card
# that the shared schema does not drive. So the aligned values live in the
# RC1HOST variant's SHIPPED CONFIG, not in the shared schema).
# Two host-generation variants x 4 unix targets. The 0.2.6 shell is SHARED by
# both variants (the NEUTRAL schema defaults + the dead-knob cleanup live in
# the dev tree); the variants differ in (1) the engines.dsh gate and
# (2) the SHIPPED CONFIG: the RC1HOST variant ships the curated PC settings as
# a NON-EMPTY config (the phone's generated card picks them up); the FULL
# variant ships the EMPTY config (the local hand-drawn card is untouched).
# Variant marker lives in the ARCHIVE FILENAME; the top-level dir inside each
# tarball is unified as dsh-supercompress-0.2.6/.
#   FULL    -> dsh-supercompress-0.2.6-full-<plat>.tar.gz    (rc.5+ host)
#   RC1HOST -> dsh-supercompress-0.2.6-rc1host-<plat>.tar.gz (rc.1 phone host)
# The Go daemon binary is UNCHANGED from 0.2.2/0.2.3 (the 0.2.6 fix is
# shell-only: the per-face inject), so the same 55-band-clean scd binaries are
# re-materialized per target.
set -euo pipefail
DIST=/root/workspace/dsh-supercompress-dist
DEV=/root/workspace/dsh-supercompress/shell
B=/tmp/sc026base/dsh-supercompress-0.2.5   # the 0.2.4 dist base (the dist-only files: pick-daemon.js / LICENSE / README / empty cordis.patch.yml / package.json files list / release.json)
STG=$DIST/.staging
rm -rf "$STG/dsh-supercompress-0.2.6-full" "$STG/dsh-supercompress-0.2.6-rc1host"
rm -rf "$STG/dsh-supercompress-0.2.6" "$STG/rdrc"
rm -f  "$STG"/dsh-supercompress-0.2.6-*.tar.gz "$STG/SHA256SUMS"

# the runtime shell closure (the 0.2.6 per-face edits live in the dev tree)
SHELL_JS="bundle.js cache-keeper.js compaction.js engine-bare.js engine-core.js \
engine-region.js engine.js handoff-gen.js host-base.js host-session.js ipc.js \
llm-guard.js llm-one-shot.js page-llm.js preclean.js predigest.js rerank.js \
summarize-ledger.js tagger.js tiering.js turn-persist.js"

# ── 1. the FULL staging: dev source + dist-only files ─────────────────────────
S=$STG/dsh-supercompress-0.2.6-full
mkdir -p "$S/client" "$S/docs" "$S/locale" "$S/bin"
for f in $SHELL_JS; do cp "$DEV/$f" "$S/$f"; done
cp "$DEV/client/client.js" "$S/client/"
cp "$DEV/docs/DETAIL.md" "$DEV/docs/DETAIL.zh.md" "$S/docs/"
cp "$DEV/locale/en.json" "$DEV/locale/zh.json" "$S/locale/"
cp "$DEV/icon.svg" "$S/" 2>/dev/null || true
cp "$B/pick-daemon.js" "$B/LICENSE" "$B/README.md" "$S/"

# ── 2. the dist-only schemastery probe (dev hardcodes the nvm path; dist probes)
python3 - "$S/bundle.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
old = '''  try {
    // host install path (dsh 0.2.2-rc.5 global node install)
    z = (await import("/root/.nvm/versions/node/v24.20.0/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/schemastery/lib/index.mjs")).default;
  } catch {
    z = undefined;
  }'''
new = '''  // host global-install probe: <node prefix>/lib/node_modules — either a
  // hoisted top-level schemastery or the nested copy under the global
  // @deepseek-ai/dsh install. (dist-only: the dev tree hardcodes the build
  // machine's nvm path here; the dist artifact probes process.execPath's
  // prefix instead.)
  try {
    const exe = typeof process !== "undefined" ? (process.execPath || "") : "";
    const bi = exe.lastIndexOf("/bin/");
    if (bi >= 0) {
      const prefix = exe.slice(0, bi);
      for (const c of [
        prefix + "/lib/node_modules/@deepseek-ai/schemastery/lib/index.mjs",
        prefix + "/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/schemastery/lib/index.mjs",
      ]) {
        try { z = (await import(c)).default; break; } catch { /* next candidate */ }
      }
    }
  } catch {
    z = undefined;
  }'''
assert old in s, "the nvm schemastery block was not found in the FULL staging bundle.js"
s = s.replace(old, new, 1)
assert "/root/.nvm" not in s, "an nvm hardcode survived the probe patch"
open(p, "w", encoding="utf-8").write(s)
print("FULL bundle.js: applied the dist-only schemastery probe")
PY

# ── 3. the dist-only empty config ─────────────────────────────────────────────
cp "$B/cordis.patch.yml" "$S/cordis.patch.yml"

# ── 4. package.json: 0.2.6 + the engines.dsh gate + the llm-guard closure ─────
python3 - "$S/package.json" "$B/package.json" <<'PY'
import json, sys
sp, bp = sys.argv[1], sys.argv[2]
d = json.load(open(bp))            # base on the 0.2.3 files list (the authoritative closure)
d["version"] = "0.2.6"
files = d.get("files") or []
if "llm-guard.js" not in files: files.insert(1, "llm-guard.js")
d["files"] = files
d["engines"] = { "dsh": ">=0.2.2-rc.5" }   # FULL: rc.5+ host only (the host gen, NOT the supercompress version)
json.dump(d, open(sp, "w"), indent=2); open(sp, "a").write("\n")
print("FULL package.json: 0.2.6, engines.dsh >=0.2.2-rc.5, llm-guard.js in files")
PY

# ── 5. release.json: 0.2.6 full-variant provenance ────────────────────────────
python3 - "$S/release.json" "$B/release.json" <<'PY'
import json, sys
sp, bp = sys.argv[1], sys.argv[2]
d = json.load(open(bp))
d["version"] = "0.2.6"; d["variant"] = "full"; d["engines_dsh"] = ">=0.2.2-rc.5"
d["source"]["commit"] = "696f461 (0.2.6 shell: revert the align-defaults to NEUTRAL + keep the dead-knob cleanup) on the 0.2.5 per-face-graceful base"
d["source"]["note"] = ("0.2.6 = the VARIANT BRANCH (owner 2026-11-28: 你需要分支). The "
  "0.2.5 'align the defaults' was a UNIFIED approach that wrongly conflated the "
  "two host generations: the phone host (rc.1, dsh-go) renders its settings card "
  "as a GENERATED form from the Config schema, while the local host (rc.5, web) "
  "renders a HAND-DRAWN card (client.js) the shared schema does not drive. So a "
  "single shared schema default affected the two hosts differently (and broke "
  "the local card's mirror). 0.2.6 BRANCHES by dist variant: the shared schema "
  "reverts to NEUTRAL (useLedgerSummarizer / renderLadder / enableLedger default "
  "OFF, enableBand40 no default, cacheKeeper default OFF, engine 0.8/65536/0.16); "
  "the FULL variant (the local / rc.5+ host) ships the EMPTY config, so its "
  "hand-drawn card + card-save layer are untouched. The aligned values move to "
  "the RC1HOST variant's shipped NON-EMPTY config (see the rc1host variant). The "
  "dead-knob cleanup is KEPT (generation-agnostic): capacityTokens absent-able "
  "(the A2 live capacity reachable), tierLlmCap removed, the orphan 'k' dropped. "
  "enableTiering kept (a live knob, pinned by test G4). The 0.2.4 per-face "
  "graceful LLM/meter access + the 55-band-clean base are inherited unchanged; "
  "the Go daemon binary is UNCHANGED (shell-only change). This variant targets "
  "the rc.5+ host; the rc.1 phone host uses the RC1HOST variant.")
dom = d.setdefault("dist_only_modifications", [])
if not any("schemastery probe" in m for m in dom):
    dom.append("bundle.js: the schemastery config-schema import fallback probes the running "
       "node's global install prefix (process.execPath) instead of hardcoding the build "
       "machine's nvm path — re-applied for 0.2.6 from the 0.1.0 dist patch.")
dom.append("cordis.patch.yml: the shipped mount row restates the dev tree's owner config "
  "overrides as an EMPTY config ({}) — a fresh install starts from the bundle's "
  "schemastery schema defaults.")
json.dump(d, open(sp, "w"), indent=2); open(sp, "a").write("\n")
print("FULL release.json: 0.2.6 full-variant provenance")
PY

# ── 6. the RC1HOST variant: copy FULL + the rc.1 gate (NO llm-guard flip: the shell is shared) ─
R=$STG/dsh-supercompress-0.2.6-rc1host
rm -rf "$R"; cp -r "$S" "$R"
python3 - "$R/package.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["engines"] = { "dsh": ">=0.2.2-rc.1" }
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
print("RC1HOST package.json: engines.dsh >=0.2.2-rc.1")
PY
# ── THE BRANCH: the RC1HOST variant ships the ALIGNED config (the curated PC
# settings, main-row values that differ from the neutral schema defaults). The
# phone's settings card is a GENERATED form from the Config schema, so it picks
# these up directly. The FULL variant keeps the base's EMPTY config (the local
# host's hand-drawn card + its card-save layer are untouched). Only the
# non-neutral main-row values are set; the neutral defaults (persistUserTurns /
# userSource / hostBackfill / enableCompaction / enable40PreDigest /
# hostPressureFactor / liveUserTrim / the file paths) are left to the schema,
# and the deployment-specific ones (ckProviders / ledgerGoal / capacityTokens)
# stay neutral. ──
cat > "$R/cordis.patch.yml" <<'YML'
# dsh-supercompress 0.2.6 RC1HOST (the phone-generation variant).
#
# THE BRANCH (owner 2026-11-28): the phone host (rc.1, dsh-go) renders its
# settings card as a GENERATED form from the Config schema, so this variant
# ships the curated PC settings as a NON-EMPTY config. The local host (rc.5,
# web) uses a HAND-DRAWN card + its card-save layer, so the FULL variant ships
# the EMPTY config (the base) and is untouched. Only the main-row values that
# differ from the neutral schema defaults are set here.
- insert:
    - id: dsh-supercompress
      name: '@stennyc/dsh-supercompress'
      config:
        # the ledger-backed 0-LLM summarizer + the form-ladder render + the
        # live-ledger face are the default compaction path on the phone:
        useLedgerSummarizer: true
        renderLadder: true
        enableLedger: true
        # the 40% pre-digest band is OFF (long pastes wait for the 50-90%):
        enableBand40: false
        # the prefix-cache keepalive (an inert no-op while ckProviders is
        # empty; activates per provider once a deployment sets ckProviders):
        cacheKeeper: true
YML
echo "RC1HOST cordis.patch.yml: the aligned (non-empty) config -- the branch"
python3 - "$R/release.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["variant"] = "rc1host"; d["engines_dsh"] = ">=0.2.2-rc.1"
d["source"]["note"] = ("0.2.6 RC1HOST = the phone-generation variant of the VARIANT "
  "BRANCH (owner 2026-11-28). It ships the SAME neutral shell as the FULL variant "
  "but a NON-EMPTY cordis.patch.yml carrying the curated PC settings (the aligned "
  "main-row values: useLedgerSummarizer / renderLadder / enableLedger ON, "
  "enableBand40 OFF, cacheKeeper ON-inert) -- because the phone host (rc.1, "
  "dsh-go) renders its settings card as a GENERATED form from the Config schema, "
  "so a phone that installs 0.2.6-rc1host starts ALIGNED with the owner's PC via "
  "the shipped config (not via the shared schema, which stays NEUTRAL so the "
  "local hand-drawn card is untouched). The FULL variant ships the EMPTY config. "
  "The deployment-specific knobs (ckProviders / ledgerGoal / capacityTokens / the "
  "file paths) stay neutral. The 0.2.4 per-face graceful LLM/meter access is "
  "inherited: when the phone's rc.1 profile resolves ctx.llm / ctx.tokenMeter the "
  "full feature set runs WITHOUT a host upgrade; per-face graceful floors keep the "
  "data-plane / tools / route-d face up when an optional token is absent. No host "
  "upgrade required. (The P5 engine-tuning block -- thresholdRatio 0.95 / "
  "headroomTokens 32768 / retainRatio 0.2 on the engine row -- is NOT in the dist "
  "config; it is the profile-layer P5 block the phone agent adds per the "
  "self-contained agent brief.)")
d["generation_note"] = ("The rc.1 host has the `llm` and `tokenMeter` faces (dsh-llm + "
  "dsh-token-meter, verified 2026-11-27), so this variant runs the full feature set on "
  "rc.1 when the host resolves ctx.llm / ctx.tokenMeter; the LLM / meter faces floor "
  "gracefully (the route-d / deterministic floor) when a token is absent -- and the "
  "data-plane / tools / route-d face is NEVER taken down by a missing optional token "
  "(the 0.2.3 all-or-nothing inject gate is gone). No host upgrade required.")
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
print("RC1HOST release.json: rc1host-variant provenance")
PY

# ── 7. materialize bin/scd per platform + tar (unified top-level dir) ────────
# platform -> the release scd binary name
scd_for() { case "$1" in
  linux-x64) echo scd-linux-amd64;; linux-arm64) echo scd-linux-arm64;;
  darwin-x64) echo scd-darwin-amd64;; darwin-arm64) echo scd-darwin-arm64;; esac; }
for VARIANT in full rc1host; do
  VDIR="$STG/dsh-supercompress-0.2.6-$VARIANT"
  # unified top-level dir: tar the CONTENTS as dsh-supercompress-0.2.6/
  for PLAT in linux-x64 linux-arm64 darwin-x64 darwin-arm64; do
    SCDB="$DIST/releases/$(scd_for "$PLAT")"
    [ -f "$SCDB" ] || { echo "MISSING release binary $SCDB"; exit 1; }
    rm -rf "$VDIR/bin/scd"; mkdir -p "$VDIR/bin"
    cp "$SCDB" "$VDIR/bin/scd"; chmod 755 "$VDIR/bin/scd"
    ARCH="$STG/dsh-supercompress-0.2.6-$VARIANT-$PLAT.tar.gz"
    rm -rf "$STG/dsh-supercompress-0.2.6"
    cp -r "$VDIR" "$STG/dsh-supercompress-0.2.6"
    tar czf "$ARCH" -C "$STG" dsh-supercompress-0.2.6
    echo "built $ARCH ($(du -h "$ARCH" | cut -f1))"
  done
done

# ── 8. SHA256SUMS ─────────────────────────────────────────────────────────────
cd "$STG"; : > SHA256SUMS
for f in dsh-supercompress-0.2.6-*.tar.gz; do
  if command -v sha256sum >/dev/null; then sha256sum "$f" >> SHA256SUMS
  else echo "$(shasum -a 256 "$f" | cut -d' ' -f1)  $f" >> SHA256SUMS; fi
done
echo "=== SHA256SUMS ==="; cat SHA256SUMS
echo "=== verify the 0.2.6 per-face design (both variants: gate-only inject + ctx.get) ==="
echo "FULL    bundle.js inject line:"; grep -n 'export const inject = \["tools"\]' "$STG/dsh-supercompress-0.2.6-full/bundle.js"
echo "FULL    engine-bare static inject line:"; grep -n 'static inject = \["sessions"\]' "$STG/dsh-supercompress-0.2.6-full/engine-bare.js"
echo "RC1HOST bundle.js inject line (same shared shell):"; grep -n 'export const inject = \["tools"\]' "$STG/dsh-supercompress-0.2.6-rc1host/bundle.js"
echo "ctx.get per-face (safeLlm):"; grep -n 'const viaGet = safeGet(ctx, "llm")' "$STG/dsh-supercompress-0.2.6-full/llm-guard.js"
echo "engines gates:"; grep '"dsh"' "$STG/dsh-supercompress-0.2.6-full/package.json"; grep '"dsh"' "$STG/dsh-supercompress-0.2.6-rc1host/package.json"
