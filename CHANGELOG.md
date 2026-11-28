# Changelog

## 0.2.5 — 2026-11-28

**Defaults alignment + dead-knob cleanup** (owner 2026-11-28: make the current
PC settings the defaults, so the phone / a fresh install starts aligned with the
PC; "全部，除了 provider 和文件路径").

The 0.2.5 shell ships the curated PC settings as the **schema DEFAULTS** — the
shipped config is still `config: {}` (the empty-config philosophy is preserved),
but an empty-config install now resolves to the PC's values:

- `useLedgerSummarizer` / `renderLadder` / `enableLedger` default **ON**
  (the ledger-backed 0-LLM summarizer + the form-ladder render + the live-ledger
  face are the default compaction path; the host LLM stays the fail-open floor).
- `enableBand40` default **OFF** (the 40% pre-digest band off; long pastes wait
  for the 50-90% bands).
- `cacheKeeper` default **ON** — an inert no-op while `ckProviders` is empty;
  activates per provider once a deployment sets `ckProviders`.
- engine `thresholdRatio 0.95` / `headroomTokens 32768` / `retainRatio 0.2`.

**Dead-knob cleanup:**
- `capacityTokens` is now **absent-able** (no schema default — schemastery has
  no `.optional()`; omitting `.default()` makes it unset-able). Previously
  `.default(1000)` kept it permanently set, which — sitting highest in the
  `resolveDistillCapacity` priority chain — dead-coded the **A2 live capacity**
  (host `contextWindow × capacityRatio`). Now absent → env → live ratio → 1000
  floor. The legacy 80%-waterline baseline is retired.
- `tierLlmCap` **removed** from the schema (a pure dead knob — no read sites;
  the per-compact tiering O(N) LLM cap was superseded by the 4-band redesign).

**Deliberately NOT defaulted** (deployment-specific — stay neutral for other
installs, owner: "除了 provider 和文件路径"): `ckProviders` stays `[]`
(per-deployment provider routing), `ledgerGoal` stays `""`, and the file-path
fields (`daemonPath` / `storePath` / `ckAuditPath` / `dshRoot`) keep their
defaults. `enableTiering` is **kept** — it is a live knob (gates the
tiering-ingest face, pinned by test G4), not a dead one.

The 0.2.4 per-face graceful LLM/meter access (gate-only static inject +
`ctx.get` per-face resolution) + the 55-band-clean base are inherited
unchanged. The Go daemon binary is UNCHANGED from 0.2.2/0.2.3/0.2.4 (0.2.5 is a
shell-only change). Shell: 30/30 test files green.

**Phone (rc1host) note:** install the `0.2.5-rc1host` variant to get the aligned
defaults on the phone (the P5 engine-replacement block for the phone's profile
layer is the separate self-contained agent brief, `shell/docs/
P5_PHONE_AGENT_BRIEF.md`).

## 0.2.4 — 2026-11-27

**Per-face graceful LLM/meter access** (owner 2026-11-27: "我认为上 0.2.4 比较
妥当"). 0.2.3 works on the phone, but its full-face static `inject` is an
**all-or-nothing activation gate**: a profile that fails to resolve any of
`llm`/`tokenMeter`/`tools` leaves the *whole* plugin — including the tools /
route-d face — inactive. 0.2.4 makes the faces per-face graceful:

- The static `inject` is now the **activation gate ONLY** (`["tools"]` bundle /
  `["sessions"]` engine — always present), so the data-plane / tools / route-d
  face is **never** taken down by a missing optional token.
- `safeLlm` / `safeTokenMeter` resolve the LLM + meter faces **per-face** at the
  call site via the DI container lookup `ctx.get("llm")` / `ctx.get("tokenMeter")`
  (the host-registered service, independent of the static inject — the same
  pattern `dsh-token-meter` itself uses), with a property-read fallback. Both
  floor deterministically to `undefined` when a token is genuinely absent.
- **One shell now serves every host generation** (the host-generation split is
  gone); the variants differ only in the `engines.dsh` gate (rc.5 vs rc.1) + the
  release.json label. The Go binary is the unchanged 0.2.2/0.2.3 55-band-clean
  one (Go `6b0a045`).

## 0.2.3 — 2026-11-27

**The rc1host variant gets the FULL inject face** (owner 2026-11-27: "你查了
deepseek harness rc1 了？没有替代方案？" → correction). The earlier claim that
the rc.1 host lacks the `llm`/`tokenMeter` DI tokens was **unverified / wrong**:
the rc.1 host ships `@deepseek-ai/dsh-llm` (registers `ctx.llm`) +
`@deepseek-ai/dsh-token-meter` (registers `ctx.tokenMeter`), so the phone **can
run the full feature set without a host upgrade**.

- **RC1HOST variant**: now carries the full inject face
  (`inject=['llm','tokenMeter','tools']`, `isLegacyInject=false`) + the rc.1
  gate (`engines.dsh >=0.2.2-rc.1`). The 40% pre-digest LLM face + window
  compression run on rc.1 when the host resolves `ctx.llm` / `ctx.tokenMeter`;
  they floor deterministically only if a token is absent (the `safeLlm` /
  `safeTokenMeter` guards). `route-d` (`sc_drill [route-d]` + `sc_digest`,
  marker `pre40`) remains the LLM-digest floor when `ctx.llm` is unavailable.
- **CAVEAT** (documented in release.json): the static `inject` is an
  all-or-nothing activation gate — if the phone's rc.1 profile does **not**
  resolve all three tokens, the whole plugin (including the tools face) stays
  inactive; verify on-device that the plugin activates + the LLM face works.
- The shell + Go binary are **unchanged from 0.2.2** (the 55-band / llm55
  cleanup; dev `67e28ad` + `61424a4`, Go `6b0a045`). Only the rc1host variant's
  inject face is opened.

## 0.2.2 — 2026-11-27

The retired **55-band / llm55 legacy fully cleaned up** (owner 2026-11-27 全清:
"llm55 不是已经弃用了吗？怎么没有清干净"). The 55-band LLM digest face was
retired at the 4-band redesign step 3 (consolidated into the unified 40%
pre-digest face, marker `pre40`) but the residual stayed; it is now removed
end-to-end, and 0.2.1's flaw (building the route-d back-fill on the deprecated
`llm55` marker) is fixed.

- **shell (dev tree `67e28ad` + `61424a4`)**: the `enable55Band` schema key +
  the `emit55BandDigests` face + the dead `_upgrade55Band` engine method + the
  `DASHSC_55BAND` env key + the `_resolveEnable40PreDigest` legacy fallback leg
  are all removed; the retired 55% waterline 3rd `distill` arg (`enable_band_55`)
  is dropped (the signature is now `distill(cap, degraded, cooldown)` — which
  also fixes a cooldown-alignment slip the 3rd-arg removal had introduced).
- **Go (dev tree `6b0a045`, 4 binaries rebuilt)**: the 55% band block
  (`EnableBand55` + the deterministic 55% eviction waterline + the `DigestEmitCb`
  LLM upgrade + the `ready:llm55` marker) is removed from the data plane; the
  55% eviction now falls to the 50% band. `go test -count=1` all green.
- **route-d (0.2.1's flaw fixed)**: the `sc_drill` `[route-d]` directive + the
  `sc_digest` back-fill tool now stamp the **canonical `pre40` marker** (the
  unified 40% pre-digest face's marker), NOT the deprecated `ready:llm55` —
  so the model back-fill is consistent with the current face across all
  host generations.
- The rc.1-host generation-tolerance + namespace-import + schemastery-probe +
  empty-config fixes + the route-d channel carry over from 0.2.1.

> **Net effect:** the `rc1host` 0.2.2 build loads + activates + no-crash on the
> rc.1 phone host (as 0.2.0/0.2.1); the data-plane faces run; when a host LLM
> is unavailable an evicted P1/P2 row's digest is the compact-time head80
> placeholder and the agent model back-fills it via `sc_digest` (the data plane
> stamps `digest_ref='pre40'`). For the FULL feature set (window compaction +
> LLM digest/tiering) use the `full` variant on an rc.5+ host.

## 0.2.1 — 2026-11-27

The route-d LLM back-fill channel (owner 2026-11-27, ported from the filemem
handoff floor — KB `4e5a93ef` / filemem commit `3c9fd7d`), so an rc.1 host
(no `llm` / `tokenMeter` DI tokens) can still obtain LLM digest quality: the
LLM work is done by the **calling model** (already running on the host's own
provider) and written back through the existing data-plane `digest` face. No
host LLM API, no key management, universal across host generations; the
deterministic head80 floor stands when the model skips. Shipped as both
variants (`full` + `rc1host`, 4 unix targets each).

- **`sc_drill`**: on the floor (`safeLlm(ctx)` undefined — the rc1host host
  generation or a transient miss) an evicted P1/P2 row's response carries a
  trailing `[route-d]` model_directive naming the `sc_digest` channel + the
  canonical `digest_ref` marker. Suppressed with `ctx.llm` present (the 55-band
  face auto-upgrades there) and on P0 rows (kept, no digest placeholder).
- **`sc_digest`** (new agent tool, both variants): the model writes
  `{ sha16, digest }` and the data plane (the Go `digest` cmd: `SetDigest` +
  the durable digest-ref marker) stamps the segment's `digest_ref` to
  `ready:llm55` (the 55-band face respects it; the marker survives a daemon
  restart). Fail-open: an unknown handle is reported, not thrown.
- The Go daemon binary is **UNCHANGED** (the channel reuses the existing
  `digest` IPC; the 0.1.0/0.2.0 stripped `scd` is re-materialized as-is).
- Source: dev tree commit `3ff93c6` (the 0.2.0 generation-tolerance commit
  `03f46f8` + the route-d port). 247 shell tests pass (242 + the 5 route-d
  cases).

> **Net effect for the phone (rc.1):** the `rc1host` 0.2.1 build loads +
> activates + no-crash (as 0.2.0) **and** — via route-d — the agent model can
> author LLM digests on its own provider and persist them (the data plane
> stamps `digest_ref=ready:llm55`). The automatic window compaction still
> requires an rc.5+ host (no `tokenMeter` on rc.1); use the `full` variant
> there.

## 0.2.0 — 2026-11-27

Host-generation tolerance (owner: the phone rc.1 host's 0.1.0 install
failed to load). The 0.1.0 build was cut against the rc.5-generation
`@deepseek-ai/dsh-tools`, whose export table has
`ToolContextUnavailableError`; the rc.1 host generation (the dsh-Go phone
proot) lacks that export, so 0.1.0's static named import threw a load-time
`SyntaxError` and the plugin entry never activated on the phone. 0.2.0
ships **two host-generation variants** (the KB tutorial's 双代际 build,
`isLegacyInject` switched by the esbuild `--define __SC_LEGACY` fold):

- **`full`** (`dsh-supercompress-0.2.0-full-<plat>.tar.gz`,
  `engines.dsh >=0.2.2-rc.5`): the rc.5+ host. Every face active — window
  compaction + LLM digest/tiering/rerank + all data-plane.
- **`rc1host`** (`dsh-supercompress-0.2.0-rc1host-<plat>.tar.gz`,
  `engines.dsh >=0.2.2-rc.1`): the rc.1 phone host. `bundle.js` now
  namespace-imports `dsh-tools` and feature-detects
  `ToolContextUnavailableError` (falls back to
  `ToolExecutorUnavailableError`); the bundle declares `inject=["tools"]`
  and the engine `inject=["sessions"]` (the DI tokens the rc.1 generation
  resolves); every `ctx.llm` / `ctx.tokenMeter` access goes through the
  `llm-guard.js` `safeLlm` / `safeTokenMeter` try/catch accessors. Since
  rc.1 resolves no `llm` / `tokenMeter` tokens, the LLM + meter faces run
  their coded deterministic floor here — the data-plane faces (ledger /
  recall / `sc_drill`) stay active, and no face crashes.
- JS runtime: 22 modules (the 0.1.0 closure + the new `llm-guard.js`) +
  `client/`. The Go daemon binary is **unchanged from 0.1.0** (the fix is
  shell-only) and re-materialized per target as-is.
- The installers (`install.sh`, `install-node.mjs`) auto-detect the host
  generation (`dsh --version` → rc gen < 5 ⇒ `rc1host`, else `full`) and
  fetch the matching variant; pass the variant explicitly to override
  (the phone proot: `rc1host`).

> **If you want the FULL feature set (window compaction + LLM digest) on the
> phone, the rc.1 host cannot provide it** — rc.1 has no `tokenMeter` /
> `llm` DI tokens. Upgrade the phone host to rc.5+ and use the `full`
> variant; the `rc1host` variant is the no-crash data-plane fallback for
> staying on rc.1.

## 0.1.0 — 2026-11-27

Initial closed-source distribution build.

- Four daemon targets: `linux-x64`, `linux-arm64`, `darwin-x64`,
  `darwin-arm64` (Go `CGO_ENABLED=0 -trimpath`, static on linux; built from
  the dev tree at commit `945f2ce` + the in-flight render-ladder
  demote-wash hardening — see `release.json` for the full provenance).
- JS runtime: the import-closure of the built shell (21 modules +
  `client/`), no source, no tests.
- `bundle.js` dist-only modification: the schemastery config-schema import
  fallback probes the running node's global install prefix instead of
  hardcoding the build machine's nvm path (see `release.json`
  `dist_only_modifications`).
- The shipped `cordis.patch.yml` row mounts the bundle with an empty
  config (schema defaults); the owner-deployment overrides live only in
  the private dev tree.
- Windows is unsupported (the daemon's `syscall.Flock` write gate is
  Unix-only) — no `windows-*` target ships.
