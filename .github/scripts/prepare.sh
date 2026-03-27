#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/demisto/content-docs"
BRANCH="master"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

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

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

# --- Pre-build step: patch .npmrc ---
# The repo's .npmrc sets node-options=--max-old-space-size=46080 which overrides NODE_OPTIONS.
# Patch it to include --openssl-legacy-provider (required for Node 20 + webpack 5.39 which uses md4)
# and reduce max-old-space-size to a sane value.
if grep -q 'node-options=--max-old-space-size=46080' .npmrc 2>/dev/null; then
    sed -i 's|node-options=--max-old-space-size=46080|node-options=--openssl-legacy-provider --max-old-space-size=4096|' .npmrc
    echo "[INFO] Patched .npmrc: added --openssl-legacy-provider, reduced max-old-space-size to 4096"
fi

echo "[DONE] Repository is ready for docusaurus commands."
