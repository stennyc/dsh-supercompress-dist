# Changelog

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
