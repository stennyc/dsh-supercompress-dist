#!/usr/bin/env bash
# build-0.2.4.sh — package the per-face-graceful 0.2.4 dist.
# Two host-generation variants x 4 unix targets. The 0.2.4 shell is SHARED by
# both variants (the gate-only static inject + the ctx.get per-face LLM/meter
# access live in the dev tree); the variants differ ONLY in the engines.dsh
# gate (the install-compatibility floor) + the release.json label.
# Variant marker lives in the ARCHIVE FILENAME; the top-level dir inside each
# tarball is unified as dsh-supercompress-0.2.4/.
#   FULL    -> dsh-supercompress-0.2.4-full-<plat>.tar.gz    (rc.5+ host)
#   RC1HOST -> dsh-supercompress-0.2.4-rc1host-<plat>.tar.gz (rc.1 phone host)
# The Go daemon binary is UNCHANGED from 0.2.2/0.2.3 (the 0.2.4 fix is
# shell-only: the per-face inject), so the same 55-band-clean scd binaries are
# re-materialized per target.
set -euo pipefail
DIST=/root/workspace/dsh-supercompress-dist
DEV=/root/workspace/dsh-supercompress/shell
B=/tmp/sc023base/dsh-supercompress-0.2.3   # the 0.2.3 dist base (the dist-only files: pick-daemon.js / LICENSE / README / empty cordis.patch.yml / package.json files list / release.json)
STG=$DIST/.staging
rm -rf "$STG/dsh-supercompress-0.2.4-full" "$STG/dsh-supercompress-0.2.4-rc1host"
rm -rf "$STG/dsh-supercompress-0.2.4" "$STG/rdrc"
rm -f  "$STG"/dsh-supercompress-0.2.4-*.tar.gz "$STG/SHA256SUMS"

# the runtime shell closure (the 0.2.4 per-face edits live in the dev tree)
SHELL_JS="bundle.js cache-keeper.js compaction.js engine-bare.js engine-core.js \
engine-region.js engine.js handoff-gen.js host-base.js host-session.js ipc.js \
llm-guard.js llm-one-shot.js page-llm.js preclean.js predigest.js rerank.js \
summarize-ledger.js tagger.js tiering.js turn-persist.js"

# ── 1. the FULL staging: dev source + dist-only files ─────────────────────────
S=$STG/dsh-supercompress-0.2.4-full
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

# ── 4. package.json: 0.2.4 + the engines.dsh gate + the llm-guard closure ─────
python3 - "$S/package.json" "$B/package.json" <<'PY'
import json, sys
sp, bp = sys.argv[1], sys.argv[2]
d = json.load(open(bp))            # base on the 0.2.3 files list (the authoritative closure)
d["version"] = "0.2.4"
files = d.get("files") or []
if "llm-guard.js" not in files: files.insert(1, "llm-guard.js")
d["files"] = files
d["engines"] = { "dsh": ">=0.2.2-rc.5" }   # FULL: rc.5+ host only (the host gen, NOT the supercompress version)
json.dump(d, open(sp, "w"), indent=2); open(sp, "a").write("\n")
print("FULL package.json: 0.2.4, engines.dsh >=0.2.2-rc.5, llm-guard.js in files")
PY

# ── 5. release.json: 0.2.4 full-variant provenance ────────────────────────────
python3 - "$S/release.json" "$B/release.json" <<'PY'
import json, sys
sp, bp = sys.argv[1], sys.argv[2]
d = json.load(open(bp))
d["version"] = "0.2.4"; d["variant"] = "full"; d["engines_dsh"] = ">=0.2.2-rc.5"
d["source"]["commit"] = "633a234 (0.2.4 shell: per-face gate-only inject + ctx.get) on the 0.2.2/0.2.3 55-band-clean base (dev 67e28ad + 61424a4, Go 6b0a045)"
d["source"]["note"] = ("0.2.4 = the PER-FACE GRACEFUL LLM/meter access (owner 2026-11-27). "
  "The earlier 'rc.1 has no llm/tokenMeter DI tokens' claim was UNVERIFIED / wrong "
  "(the rc.1 host ships dsh-llm + dsh-token-meter). 0.2.3 opened the static inject "
  "face to the full triple, which is an ALL-OR-NOTHING activation gate: a profile "
  "that fails to resolve any token leaves the WHOLE plugin (including the tools / "
  "route-d face) inactive. 0.2.4 fixes that: the static inject is the ACTIVATION "
  "GATE ONLY ([\"tools\"] bundle / [\"sessions\"] engine -- always present), so the "
  "data-plane / tools face is never taken down by a missing optional token; the LLM "
  "+ meter faces are resolved PER-FACE at the call site via the DI container lookup "
  "ctx.get(\"llm\") / ctx.get(\"tokenMeter\") (the host-registered service, "
  "independent of the static inject -- the same pattern dsh-token-meter itself "
  "uses), with a property-read fallback for test fakes + statically-injected hosts. "
  "Both floor deterministically to undefined when a token is genuinely absent. One "
  "shell now serves every host generation. The 55-band / llm55 legacy is the 0.2.2 "
  "cleaned-up base; route-d (marker pre40) remains the LLM-digest floor. This "
  "variant targets the rc.5+ host (the rc.1 host uses the RC1HOST variant).")
dom = d.setdefault("dist_only_modifications", [])
if not any("schemastery probe" in m for m in dom):
    dom.append("bundle.js: the schemastery config-schema import fallback probes the running "
       "node's global install prefix (process.execPath) instead of hardcoding the build "
       "machine's nvm path — re-applied for 0.2.4 from the 0.1.0 dist patch.")
dom.append("cordis.patch.yml: the shipped mount row restates the dev tree's owner config "
  "overrides as an EMPTY config ({}) — a fresh install starts from the bundle's "
  "schemastery schema defaults.")
json.dump(d, open(sp, "w"), indent=2); open(sp, "a").write("\n")
print("FULL release.json: 0.2.4 full-variant provenance")
PY

# ── 6. the RC1HOST variant: copy FULL + the rc.1 gate (NO llm-guard flip: the shell is shared) ─
R=$STG/dsh-supercompress-0.2.4-rc1host
rm -rf "$R"; cp -r "$S" "$R"
python3 - "$R/package.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["engines"] = { "dsh": ">=0.2.2-rc.1" }
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
print("RC1HOST package.json: engines.dsh >=0.2.2-rc.1")
PY
python3 - "$R/release.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["variant"] = "rc1host"; d["engines_dsh"] = ">=0.2.2-rc.1"
d["source"]["note"] = ("0.2.4 RC1HOST = the phone-generation variant with the PER-FACE "
  "GRACEFUL LLM/meter access (owner 2026-11-27). It ships the SAME shell as the FULL "
  "variant (the gate-only static inject + the ctx.get per-face LLM/meter resolution), "
  "differing ONLY in the engines.dsh gate (>=0.2.2-rc.1, so it installs on the rc.1 "
  "phone host). The rc.1 host HAS the llm + tokenMeter faces (dsh-llm + "
  "dsh-token-meter, verified), so when the phone's rc.1 profile resolves ctx.llm / "
  "ctx.tokenMeter the full feature set (window compaction + 40% pre-digest LLM digest "
  "+ the data plane) runs WITHOUT a host upgrade. Per-face graceful: the static inject "
  "is the activation gate ONLY ([\"tools\"] / [\"sessions\"]), so a missing optional "
  "token NEVER takes down the data-plane / tools / route-d face -- the LLM + meter "
  "faces resolve via the ctx.get container lookup and floor deterministically to the "
  "route-d / deterministic floor when a token is genuinely absent. The 55-band / "
  "llm55 legacy is the 0.2.2 cleaned-up base. No host upgrade required.")
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
  VDIR="$STG/dsh-supercompress-0.2.4-$VARIANT"
  # unified top-level dir: tar the CONTENTS as dsh-supercompress-0.2.4/
  for PLAT in linux-x64 linux-arm64 darwin-x64 darwin-arm64; do
    SCDB="$DIST/releases/$(scd_for "$PLAT")"
    [ -f "$SCDB" ] || { echo "MISSING release binary $SCDB"; exit 1; }
    rm -rf "$VDIR/bin/scd"; mkdir -p "$VDIR/bin"
    cp "$SCDB" "$VDIR/bin/scd"; chmod 755 "$VDIR/bin/scd"
    ARCH="$STG/dsh-supercompress-0.2.4-$VARIANT-$PLAT.tar.gz"
    rm -rf "$STG/dsh-supercompress-0.2.4"
    cp -r "$VDIR" "$STG/dsh-supercompress-0.2.4"
    tar czf "$ARCH" -C "$STG" dsh-supercompress-0.2.4
    echo "built $ARCH ($(du -h "$ARCH" | cut -f1))"
  done
done

# ── 8. SHA256SUMS ─────────────────────────────────────────────────────────────
cd "$STG"; : > SHA256SUMS
for f in dsh-supercompress-0.2.4-*.tar.gz; do
  if command -v sha256sum >/dev/null; then sha256sum "$f" >> SHA256SUMS
  else echo "$(shasum -a 256 "$f" | cut -d' ' -f1)  $f" >> SHA256SUMS; fi
done
echo "=== SHA256SUMS ==="; cat SHA256SUMS
echo "=== verify the 0.2.4 per-face design (both variants: gate-only inject + ctx.get) ==="
echo "FULL    bundle.js inject line:"; grep -n 'export const inject = \["tools"\]' "$STG/dsh-supercompress-0.2.4-full/bundle.js"
echo "FULL    engine-bare static inject line:"; grep -n 'static inject = \["sessions"\]' "$STG/dsh-supercompress-0.2.4-full/engine-bare.js"
echo "RC1HOST bundle.js inject line (same shared shell):"; grep -n 'export const inject = \["tools"\]' "$STG/dsh-supercompress-0.2.4-rc1host/bundle.js"
echo "ctx.get per-face (safeLlm):"; grep -n 'const viaGet = safeGet(ctx, "llm")' "$STG/dsh-supercompress-0.2.4-full/llm-guard.js"
echo "engines gates:"; grep '"dsh"' "$STG/dsh-supercompress-0.2.4-full/package.json"; grep '"dsh"' "$STG/dsh-supercompress-0.2.4-rc1host/package.json"
