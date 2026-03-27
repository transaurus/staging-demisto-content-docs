#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for demisto/content-docs
# Runs on existing source tree (no clone). Installs deps, runs pre-build steps, builds.

# --- Node version ---
# demisto/content-docs uses webpack 5.39 which requires --openssl-legacy-provider on Node 20+
NODE_MAJOR=$(node --version | sed 's/v//' | cut -d. -f1)
echo "[INFO] Using Node $(node --version)"
if [ "$NODE_MAJOR" -lt 16 ]; then
    echo "[ERROR] Node $NODE_MAJOR detected, but this repo requires Node >=16."
    exit 1
fi

# --- Package manager + dependencies ---
# Uses npm (package-lock.json present). Requires --legacy-peer-deps for peer dep conflicts.
npm install --legacy-peer-deps

# --- Pre-build step: patch .npmrc ---
# The repo's .npmrc sets node-options=--max-old-space-size=46080 which overrides NODE_OPTIONS.
# Patch it to include --openssl-legacy-provider (required for Node 20 + webpack 5.39 which uses md4)
# and reduce max-old-space-size to a sane value.
if grep -q 'node-options=--max-old-space-size=46080' .npmrc 2>/dev/null; then
    sed -i 's|node-options=--max-old-space-size=46080|node-options=--openssl-legacy-provider --max-old-space-size=4096|' .npmrc
    echo "[INFO] Patched .npmrc: added --openssl-legacy-provider, reduced max-old-space-size to 4096"
fi

# --- Build ---
npm run build-docusaurus

echo "[DONE] Build complete."
