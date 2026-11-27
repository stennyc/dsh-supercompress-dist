# Changelog

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
