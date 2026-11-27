# dsh-supercompress (closed-source distribution)

Reversible session-context compression + on-demand BM25 recall for the DSH
agent: a Go data-plane daemon (`scd`, the persistent session ledger, the
BM25 recall + the compact-ledger faces) behind a thin JS Cordis shell.

This repo is the **closed-source distribution** — the plugin ships as
compiled artifacts only: the daemon as per-platform native binaries, the
shell as the built JS modules. No development source is distributed.
Provenance (source commit, binary sha256s, dist-only modifications) is in
[release.json](release.json); the same file ships inside every tarball.

## Supported platforms

| platform | target | binary inside the tarball |
|---|---|---|
| Linux x86-64 | `linux-x64` | `bin/scd` (ELF, x86-64, static) |
| Linux ARM64 | `linux-arm64` | `bin/scd` (ELF, aarch64, static) |
| macOS Intel | `darwin-x64` | `bin/scd` (Mach-O, x86_64) |
| macOS Apple Silicon | `darwin-arm64` | `bin/scd` (Mach-O, arm64) |

Windows is **not supported**: the Go daemon uses `syscall.Flock` /
`LOCK_EX` (Unix-only file locking, the compact-ledger's write gate). A
Windows build requires porting the locking layer.

## Requirements

- A DSH host with the `@deepseek-ai/dsh-*` packages in the host install
  (the host provides them — the peer note under Install).
- Node >= 20 to run the shell; the daemon binary is native — no toolchain
  needed.

## Host-generation variants (0.2.0+)

The 0.2.0+ dist ships **two host-generation builds** (the KB tutorial's
双代际 build): the `@deepseek-ai/dsh-*` packages and the DI token
vocabulary differ between the **rc.1** host generation (the dsh-Go phone
proot) and the **rc.5+** host generation (the desktop / the newer phone
engines). Concretely the rc.1 generation's `dsh-tools` has no
`ToolContextUnavailableError` export, and it resolves no `llm` /
`tokenMeter` DI tokens. So one static build cannot load + activate on both:

| variant | filename marker | host generation | feature set |
|---|---|---|---|
| `full` | `dsh-supercompress-<v>-full-<plat>.tar.gz` | rc.5+ | every face active (window compaction + LLM digest/tiering/rerank + all data-plane) |
| `rc1host` | `dsh-supercompress-<v>-rc1host-<plat>.tar.gz` | rc.1 | the data-plane faces (ledger / recall / `sc_drill`); the LLM + meter faces run their coded deterministic floor — no crash, no window compaction |

The installers auto-detect the host generation (`dsh --version` → the rc
generation < 5 ⇒ `rc1host`, else `full`); pass the variant explicitly to
override (the phone proot where `dsh` is not on PATH: pass `rc1host`).


## Install

One-liner (the installer lives on the dist repo's main branch; it fetches
the host-generation-matched tarball + `SHA256SUMS` from the releases branch,
verifies, extracts; `[version]` and `[variant]` are optional):

```sh
# auto-detect the host generation (rc.1 -> rc1host, rc.5+ -> full):
curl -fsSL https://raw.githubusercontent.com/stennyc/dsh-supercompress-dist/main/install.sh | sh
# the rc.1 phone host (force the RC1HOST variant):
curl -fsSL https://raw.githubusercontent.com/stennyc/dsh-supercompress-dist/main/install.sh | sh -s -- 0.2.3 rc1host
```

**No curl/wget available?** (the dsh-Go phone proot userland: node is
preinstalled, the download tools are not) — the pure-node installer does the
fetch + the checksum (node:crypto) + the extract (tar). Its default variant
is `rc1host` (the phone); pass `full` for an rc.5+ host:

```sh
node -e "fetch('https://raw.githubusercontent.com/stennyc/dsh-supercompress-dist/main/install-node.mjs').then(r=>r.arrayBuffer()).then(b=>require('fs').writeFileSync('/tmp/install-node.mjs', Buffer.from(b)))"
node /tmp/install-node.mjs            # newest version, the rc1host variant (the phone default)
node /tmp/install-node.mjs 0.2.3 full # the FULL variant (an rc.5+ host)
```

Manual: download `dsh-supercompress-<version>-<variant>-<platform>.tar.gz`
(e.g. `dsh-supercompress-0.2.3-rc1host-linux-arm64.tar.gz`) from
https://github.com/stennyc/dsh-supercompress-dist/tree/releases and verify
with the branch's `SHA256SUMS`. The top-level directory inside every
tarball is `dsh-supercompress-<version>` (unified across variants). Then add
the extracted directory as a `file:` dependency in your DSH profile's
`package.json` and install:

```sh
cd <your-dsh-profile-dir>
pnpm add <path-to-extracted>/dsh-supercompress-<version>
```

> **Peer warning note:** when installing by path, pnpm prints "The linked
> dependency will not resolve the peer dependencies…" — the peers
> (`@deepseek-ai/cordis`, the `dsh-*` services, schemastery) are provided
> by the DSH host install. The warning is expected and harmless; the
> plugin loads from the host's tree.

Finally, the host must reload the plugin (restart the DSH host process).
The package carries **no install scripts** (`postinstall` etc.) — the host
side executes nothing beyond the normal plugin load.

## Configure

All knobs are the volatile config fields documented in the package's
`docs/DETAIL.md` (en) / `docs/DETAIL.zh.md` (zh). The shipped
`cordis.patch.yml` row mounts the bundle with an **empty config** — the
bundle's schemastery schema applies every `.default()` at validation, so a
fresh install starts from the schema defaults. Tune via the Web GUI's
Plugins settings card (the volatile knobs hot-apply, no restart) or by
restating keys in the patch row (patch replaces whole config, no merge —
the dsh-base contract). `daemonPath` / `storePath` stay patch-row fields —
point `daemonPath` at `./bin/scd` inside the package if you move the install.
Store root defaults to `~/.dsh-supercompress/session.jsonl` (per-user
isolated).

## Uninstall

`pnpm remove @stennyc/dsh-supercompress` in the profile (on dsh-Go:
`dsh plugin --profile <profile> remove @stennyc/dsh-supercompress` + delete
the installed directory), then delete `~/.dsh-supercompress` if you also
want the local session ledger gone.

## Security posture

- The daemon is a closed binary: verify the release checksums
  (`SHA256SUMS` on the releases branch; per-tarball sha256 also in
  `release.json`) before use.
- The session ledger is local to your home; nothing leaves the machine.
- The package carries no install scripts.

## License

Proprietary / closed-source. See [LICENSE](LICENSE).
