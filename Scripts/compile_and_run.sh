#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"
"${SCRIPT_DIR}/package_app.sh" debug

APP_BUNDLE="${ROOT_DIR}/build/Materialgram.app"
echo "==> Launching ${APP_BUNDLE}..."
open "${APP_BUNDLE}"
