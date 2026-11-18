#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Forsway Scandinavia AB
# SPDX-License-Identifier: Apache-2.0
#
# Adopts the Go sources generated into tmp/Nchf_ConvergedCharging_gen into
# the committed package:
#   1. removes the package's *.go files the new generation no longer
#      produces (every *.go file in the package but a test is generated),
#   2. copies the generated *.go sources over,
#   3. re-applies the hand-modifications (scripts/postprocess_nchf_handmods.sh).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/tmp/Nchf_ConvergedCharging_gen"
DEST_DIR="${ROOT_DIR}/Nchf_ConvergedCharging"

if [ ! -d "${SRC_DIR}" ]; then
  echo "Source directory not found: ${SRC_DIR}. Run the generator first." >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
shopt -s nullglob

for f in "${DEST_DIR}"/*.go; do
  case "$f" in *_test.go) continue ;; esac
  if [ ! -f "${SRC_DIR}/$(basename "$f")" ]; then
    echo "REMOVE (no longer generated): $(basename "$f")" >&2
    rm "$f"
  fi
done

cp "${SRC_DIR}"/*.go "${DEST_DIR}/"

"${ROOT_DIR}/scripts/postprocess_nchf_handmods.sh" "${DEST_DIR}"
