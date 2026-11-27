#!/usr/bin/env node
// dsh-supercompress installer for environments without curl/wget (the dsh-Go
// phone proot userland: node is preinstalled, the download tools are not).
// Fetches the tarball + SHA256SUMS from the dist repo's releases branch over
// https (node's global fetch), verifies the checksum with node:crypto (no
// sha256sum binary needed), and extracts with tar.
//
// Usage:  node install-node.mjs [version] [variant]
//   no args        = the newest version, the host-generation-matched variant
//   0.2.0          = that exact version, auto-detected variant
//   0.2.0 rc1host  = that exact version, the RC1HOST variant (the rc.1 phone host)
//   0.2.0 full     = that exact version, the FULL variant (the rc.5+ host)
// The target platform is derived from the running node (arch + platform).
//
// VARIANT (host generation): the 0.2.0+ dist ships two host-generation builds
// (the dsh-tools export + the llm/tokenMeter DI tokens differ between the rc.1
// phone host and the rc.5+ host). This node-only installer targets the dsh-Go
// phone proot, so its DEFAULT is the RC1HOST variant; pass `full` for an
// rc.5+ host. Auto-detection (`dsh --version`) is tried first when available.
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const BASE = "https://raw.githubusercontent.com/stennyc/dsh-supercompress-dist/releases";
const VER = process.argv[2] || "";
const VARIANT_ARG = process.argv[3] || "";

// platform -> the releases-branch target name
function targetName() {
  const p = process.platform, a = process.arch;
  if (p === "linux" && (a === "x64" || a === "amd64")) return "linux-x64";
  if (p === "linux" && (a === "arm64" || a === "aarch64")) return "linux-arm64";
  if (p === "darwin" && a === "arm64") return "darwin-arm64";
  if (p === "darwin" && a === "x64") return "darwin-x64";
  throw new Error("unsupported platform: " + p + "-" + a + " (the releases branch ships: linux-x64, linux-arm64, darwin-x64, darwin-arm64; Windows is not supported — the daemon uses syscall.Flock, Unix-only)");
}
const TARGET = targetName();

// resolve the host-generation variant: explicit arg > auto-detect > the
// node-only-installer default (rc1host — it targets the phone proot).
function resolveVariant() {
  if (VARIANT_ARG === "full" || VARIANT_ARG === "rc1host") return VARIANT_ARG;
  try {
    const out = spawnSync("dsh", ["--version"], { encoding: "utf8" }).stdout || "";
    const m = out.match(/([0-9]+\.[0-9]+\.[0-9]+)-rc\.([0-9]+)/);
    if (m) {
      const gen = parseInt(m[2], 10);
      if (gen < 5) return "rc1host";
      return "full";
    }
  } catch { /* no dsh CLI on PATH — fall to the installer default */ }
  return "rc1host";
}
const VARIANT = resolveVariant();

async function main() {
  const sumsUrl = BASE + "/SHA256SUMS";
  const sums = (await (await fetch(sumsUrl)).text()).trim().split("\n");
  const versions = [...new Set(sums.map((l) => {
    const m = l.match(/dsh-supercompress-([0-9][0-9.]*)-(full|rc1host)-(linux|darwin)-\w+\.tar\.gz/);
    return m ? m[1] : null;
  }).filter(Boolean))].sort().pop();
  const version = VER || versions;
  const file = "dsh-supercompress-" + version + "-" + VARIANT + "-" + TARGET + ".tar.gz";
  const line = sums.find((l) => l.trimEnd().endsWith("  " + file) || l.includes("  " + file));
  if (!line) { console.error("no checksum row for " + file); process.exit(1); }
  const want = line.trim().split(/\s+/)[0];

  console.log("fetching " + file + " (variant: " + VARIANT + ") ...");
  const buf = Buffer.from(await (await fetch(BASE + "/" + file)).arrayBuffer());
  const got = crypto.createHash("sha256").update(buf).digest("hex");
  if (got !== want) { console.error("CHECKSUM MISMATCH for " + file); process.exit(1); }
  console.log(file + ": checksum ok");

  const tmp = path.join(os.tmpdir(), file);
  fs.writeFileSync(tmp, buf);
  const r = spawnSync("tar", ["-xzf", tmp], { stdio: "inherit" });
  if (r.status !== 0) { console.error("tar extraction failed (is tar available in this environment?)"); process.exit(1); }
  fs.unlinkSync(tmp);
  const dir = "dsh-supercompress-" + version;
  console.log("");
  console.log("extracted: " + path.join(process.cwd(), dir));
  console.log("next: add the directory as a file: dependency in your DSH profile's package.json (pnpm add <path>), or on a dsh-Go host: dsh plugin --profile <your-app-profile> add <path>");
  if (VARIANT === "rc1host") {
    console.log("variant note: this is the RC1HOST build (the rc.1 host generation). The LLM + tokenMeter faces run");
    console.log("their deterministic floor here — on rc.1 the core window compaction is data-plane only (ledger/recall/drill).");
    console.log("For the full feature set, use the FULL variant on an rc.5+ host: node install-node.mjs " + version + " full");
  }
}
main().catch((e) => { console.error(e.message || e); process.exit(1); });
