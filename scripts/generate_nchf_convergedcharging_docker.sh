#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Forsway Scandinavia AB
# SPDX-License-Identifier: Apache-2.0
#
# Regenerates Nchf_ConvergedCharging from TS 32.291 with a pinned
# openapi-generator, the version the other clients in this repository were
# generated with:
#
#   scripts/generate_nchf_convergedcharging_docker.sh
#
# bundles the curated specs (scripts/curate_ts32291.sh), generates from the
# bundle into tmp/, fails if the generator could not resolve a $ref, adopts
# the result into Nchf_ConvergedCharging/, re-applies the hand-modifications
# (scripts/postprocess_nchf_handmods.sh) and builds the package. A
# regeneration of an unchanged spec leaves `git status` clean.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="openapitools/openapi-generator-cli:v7.25.0@sha256:2ab0a9680222de65dc9d3baf861aa02b99e1b80c211d8221ebf3ae8f8a102524"
OUT="tmp/Nchf_ConvergedCharging_gen"
LOG="${ROOT_DIR}/tmp/generate.log"

"${ROOT_DIR}/scripts/curate_ts32291.sh"

rm -rf "${ROOT_DIR:?}/${OUT}"
if ! docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "${ROOT_DIR}:/local" \
  "${IMAGE}" generate \
  -i /local/Nchf_ConvergedCharging/api/ts32291_nchf_convergedcharging.bundled.yaml \
  -g go \
  -o "/local/${OUT}" \
  --skip-validate-spec \
  --global-property apiTests=false,modelTests=false,apiDocs=false,modelDocs=false \
  --additional-properties=packageName=Nchf_ConvergedCharging,isGoSubmodule=false,enumClassPrefix=true \
  >"${LOG}" 2>&1; then
  tail -20 "${LOG}" >&2
  exit 1
fi

# The generator types a property whose $ref it cannot resolve as a generic
# Object, or as a type it does not define, with a warning but without
# failing. ("Failed to get the schema name: null", which it logs once, names
# no $ref.)
if grep -E 'Error obtaining the datatype from ref|Failed to get the schema name|is not defined|Exception while resolving' "${LOG}" |
  grep -v 'Failed to get the schema name: null$' >&2; then
  echo "ERROR: the generator could not resolve the \$refs above; see ${LOG}" >&2
  exit 1
fi

"${ROOT_DIR}/scripts/adopt_nchf_convergedcharging.sh"
rm -rf "${ROOT_DIR:?}/${OUT}"
(cd "${ROOT_DIR}" && GOWORK=off go build ./Nchf_ConvergedCharging/)
