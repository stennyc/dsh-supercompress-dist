#!/usr/bin/env bash
# build-0.2.2.sh — package the generation-tolerant 0.2.2 dist.
# Two host-generation variants (KB tutorial pit 13: 代际双构建) x 4 unix targets.
# Variant marker lives in the ARCHIVE FILENAME; the top-level dir inside each
# tarball is unified as dsh-supercompress-0.2.2/ (the tutorial's 统一顶层目录).
#   FULL    -> dsh-supercompress-0.2.2-full-<plat>.tar.gz    (rc.5+ host)
#   RC1HOST -> dsh-supercompress-0.2.2-rc1host-<plat>.tar.gz (rc.1 phone host)
# The Go daemon binary is UNCHANGED from 0.1.0 (the 0.2.2 fix is shell-only), so
# the same stripped scd-<goos>-<goarch> binaries are re-materialized per target.
set -euo pipefail
DIST=/root/workspace/dsh-supercompress-dist
DEV=/root/workspace/dsh-supercompress/shell
B=/tmp/sc021base/dsh-supercompress-0.2.1   # the 0.2.1 dist base (the dist-only files: pick-daemon.js / LICENSE / README / empty cordis.patch.yml / package.json files list / release.json)
STG=$DIST/.staging
rm -rf "$STG/dsh-supercompress-0.2.2-full" "$STG/dsh-supercompress-0.2.2-rc1host"
rm -rf "$STG/dsh-supercompress-0.2.2" "$STG/rdrc"
rm -f  "$STG"/dsh-supercompress-0.2.2-*.tar.gz "$STG/SHA256SUMS"

# the runtime shell closure (the generation-tolerant edits)
SHELL_JS="bundle.js cache-keeper.js compaction.js engine-bare.js engine-core.js \
engine-region.js engine.js handoff-gen.js host-base.js host-session.js ipc.js \
llm-guard.js llm-one-shot.js page-llm.js preclean.js predigest.js rerank.js \
summarize-ledger.js tagger.js tiering.js turn-persist.js"

# ── 1. the FULL staging: dev source + dist-only files ─────────────────────────
S=$STG/dsh-supercompress-0.2.2-full
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

# ── 4. package.json: 0.2.2 + the engines.dsh gate + the llm-guard closure ─────
python3 - "$S/package.json" "$B/package.json" <<'PY'
import json, sys
sp, bp = sys.argv[1], sys.argv[2]
d = json.load(open(bp))            # base on the 0.1.0 files list (authoritative closure)
d["version"] = "0.2.2"
files = d.get("files") or []
if "llm-guard.js" not in files: files.insert(1, "llm-guard.js")
d["files"] = files
d["engines"] = { "dsh": ">=0.2.2-rc.5" }   # FULL: rc.5+ host only
json.dump(d, open(sp, "w"), indent=2); open(sp, "a").write("\n")
print("FULL package.json: 0.2.2, engines.dsh >=0.2.2-rc.5, llm-guard.js in files")
PY

# ── 5. release.json: 0.2.2 full-variant provenance ────────────────────────────
python3 - "$S/release.json" "$B/release.json" <<'PY'
import json, sys
sp, bp = sys.argv[1], sys.argv[2]
d = json.load(open(bp))
d["version"] = "0.2.2"; d["variant"] = "full"; d["engines_dsh"] = ">=0.2.2-rc.5"
d["source"]["commit"] = "6b0a045 (Go 55% band removed) + shell closure 67e28ad"
d["source"]["note"] = ("0.2.2 = the retired 55-band / llm55 legacy FULLY CLEANED UP "
  "(owner 2026-11-27): the shell 55-band LLM digest faces (enable55Band key + "
  "emit55BandDigests + _upgrade55Band + the DASHSC_55BAND env + the "
  "_resolveEnable40PreDigest legacy fallback leg) and the Go 55% band block "
  "(EnableBand55 + the deterministic 55% eviction waterline + the DigestEmitCb LLM "
  "upgrade + the ready:llm55 marker) are all REMOVED; the 4 Go binaries are REBUILT "
  "with the removal (the 55% eviction now falls to the 50% band). The route-d LLM "
  "back-fill channel (sc_drill [route-d] directive + the sc_digest tool) rides the "
  "CANONICAL pre40 marker (the unified 40% pre-digest face's marker), NOT the "
  "deprecated llm55. The rc.1-host generation-tolerance + namespace-import + "
  "schemastery-probe + empty-config fixes carry over. This variant targets the rc.5+ host.")
dom = d.setdefault("dist_only_modifications", [])
if not any("schemastery probe" in m for m in dom):
    dom.append("bundle.js: the schemastery config-schema import fallback probes the running "
      "node's global install prefix (process.execPath) instead of hardcoding the build "
      "machine's nvm path — re-applied for 0.2.2 from the 0.1.0 dist patch.")
dom.append("cordis.patch.yml: the shipped mount row restates the dev tree's owner config "
  "overrides as an EMPTY config ({}) — a fresh install starts from the bundle's "
  "schemastery schema defaults.")
json.dump(d, open(sp, "w"), indent=2); open(sp, "a").write("\n")
print("FULL release.json: 0.2.2 full-variant provenance")
PY

# ── 6. the RC1HOST variant: copy FULL + flip isLegacyInject + the rc.1 gate ───
R=$STG/dsh-supercompress-0.2.2-rc1host
rm -rf "$R"; cp -r "$S" "$R"
python3 - "$R/llm-guard.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
old = "    return typeof __SC_LEGACY !== \"undefined\" && __SC_LEGACY === true;"
new = "    return true; // RC1HOST variant: the __SC_LEGACY=true fold (the rc.1 host)"
assert old in s, "the isLegacyInject fold target was not found in the rc1host llm-guard.js"
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
print("RC1HOST llm-guard.js: folded isLegacyInject=true")
PY
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
d["source"]["note"] = ("0.2.2 RC1HOST = the retired 55-band / llm55 legacy cleaned up, "
  "folded for the rc.1 host generation (the dsh-Go phone host). The Go daemon binary "
  "is REBUILT with the 55% band removed (the 4 stripped scd binaries carry it). "
  "bundle.js namespace-imports dsh-tools and feature-detects "
  "ToolContextUnavailableError (absent from rc.1). isLegacyInject=true: the bundle "
  "declares inject=['tools'] and the engine inject=['sessions']; the LLM + tokenMeter "
  "faces floor deterministically (rc.1 has no llm / tokenMeter DI tokens). On rc.1 "
  "the data-plane faces run (the compact-ledger P0/model write, the BM25 recall, the "
  "sc_drill point-fetch); when a host LLM is unavailable an evicted P1/P2 row's "
  "digest is the compact-time head80 placeholder and the model back-fills it via the "
  "sc_digest tool — the data plane stamps digest_ref='pre40' (the unified 40% "
  "pre-digest face's marker), so the LLM digest quality is model-issued and universal "
  "across host generations. For the FULL feature set use the FULL variant on rc.5+.")
d["generation_note"] = ("The rc.1 host generation lacks the `llm` and `tokenMeter` DI "
  "tokens, so this RC1HOST variant runs the data-plane faces (the compact-ledger "
  "P0/model write, the BM25 recall, the sc_drill point-fetch) and floors the LLM / "
  "meter faces. For the FULL feature set (window compaction + LLM digest/tiering), "
  "use the FULL variant on an rc.5+ host.")
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
print("RC1HOST release.json: rc1host-variant provenance")
PY

# ── 7. materialize bin/scd per platform + tar (unified top-level dir) ────────
# platform -> the release scd binary name
scd_for() { case "$1" in
  linux-x64) echo scd-linux-amd64;; linux-arm64) echo scd-linux-arm64;;
  darwin-x64) echo scd-darwin-amd64;; darwin-arm64) echo scd-darwin-arm64;; esac; }
for VARIANT in full rc1host; do
  VDIR="$STG/dsh-supercompress-0.2.2-$VARIANT"
  # unified top-level dir: tar the CONTENTS as dsh-supercompress-0.2.2/
  for PLAT in linux-x64 linux-arm64 darwin-x64 darwin-arm64; do
    SCDB="$DIST/releases/$(scd_for "$PLAT")"
    [ -f "$SCDB" ] || { echo "MISSING release binary $SCDB"; exit 1; }
    rm -rf "$VDIR/bin/scd"; mkdir -p "$VDIR/bin"
    cp "$SCDB" "$VDIR/bin/scd"; chmod 755 "$VDIR/bin/scd"
    ARCH="$STG/dsh-supercompress-0.2.2-$VARIANT-$PLAT.tar.gz"
    rm -rf "$STG/dsh-supercompress-0.2.2"
    cp -r "$VDIR" "$STG/dsh-supercompress-0.2.2"
    tar czf "$ARCH" -C "$STG" dsh-supercompress-0.2.2
    echo "built $ARCH ($(du -h "$ARCH" | cut -f1))"
  done
done

# ── 8. SHA256SUMS ─────────────────────────────────────────────────────────────
cd "$STG"; : > SHA256SUMS
for f in dsh-supercompress-0.2.2-*.tar.gz; do
  if command -v sha256sum >/dev/null; then sha256sum "$f" >> SHA256SUMS
  else echo "$(shasum -a 256 "$f" | cut -d' ' -f1)  $f" >> SHA256SUMS; fi
done
echo "=== SHA256SUMS ==="; cat SHA256SUMS
echo "=== verify the variant switch actually differs ==="
echo "FULL   llm-guard isLegacyInject line:"; grep -n 'isLegacyInject = ' "$STG/dsh-supercompress-0.2.2-full/llm-guard.js" | head -1
grep -n 'return typeof __SC_LEGACY\|return true; // RC1HOST' "$STG/dsh-supercompress-0.2.2-full/llm-guard.js"
echo "RC1HOST llm-guard isLegacyInject line:"; grep -n 'return true; // RC1HOST\|return typeof __SC_LEGACY' "$STG/dsh-supercompress-0.2.2-rc1host/llm-guard.js"
