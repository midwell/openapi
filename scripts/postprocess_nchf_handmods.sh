#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Forsway Scandinavia AB
# SPDX-License-Identifier: Apache-2.0
#
# Re-applies the hand-modifications the committed Nchf_ConvergedCharging
# package carries on top of the generator's output. The adoption step
# (scripts/adopt_nchf_convergedcharging.sh) runs it after every generation.
# Each hand-modification recognises both the generated and the modified form,
# and fails on anything else, so a change in the generator's output is not
# silently passed over.
#
#   1. lenient-decode: models decode with json.Unmarshal, without
#      DisallowUnknownFields, so an attribute added in a later release does
#      not fail the whole answer.
#   2. regexp-commas: the generator escapes each comma in a "regexp=" validate
#      tag ("{5\\,15}") for gopkg.in/validator.v2, which reads commas as rule
#      separators. openapi.Validate takes the whole tag as the pattern, as the
#      models package's tags are written, so the escape is removed.
#   3. openapi-validate: the oneOf wrappers check a candidate with the
#      repository's openapi.Validate instead of gopkg.in/validator.v2, which
#      the repository no longer depends on.
#   4. lenient-problem-details: the oneOf wrappers decode their ProblemDetails
#      candidate, the last one they try, leniently and only when no other
#      candidate matched. Decoded strictly, a ProblemDetails with an attribute
#      added in a later release matches nothing and fails the answer.
#   5. client-staticcheck: client.go's error strings lower-case without
#      trailing punctuation, as in the other clients, and its decode branch
#      for *os.File dropped. It wrote the body to a temporary file through a
#      local copy of the pointer, so the caller never saw it; **os.File
#      still works.
#   6. fui-without-action: MultipleUnitInformation drops a finalUnitIndication
#      whose finalUnitAction is missing, null or empty: the indication only
#      means something through its action. TS 32.291 makes the action
#      mandatory, but free5gc's CHF sends an indication without an action
#      with every grant; the curation makes it optional so that such an
#      answer decodes.
#
# Last, every file gets the repository's SPDX header, and the package is
# formatted with gofmt and with gci at the version the pre-commit hook runs.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PKG_DIR="${1:-${ROOT_DIR}/Nchf_ConvergedCharging}"

fail() {
  echo "ERROR: $*; fix scripts/postprocess_nchf_handmods.sh" >&2
  exit 1
}

# --- 1. lenient-decode ---
n=0
for f in "${PKG_DIR}"/model_*.go; do
  grep -q 'decoder\.DisallowUnknownFields()' "$f" || continue
  perl -0777 -pi -e '
    s{\tdecoder := json\.NewDecoder\(bytes\.NewReader\(data\)\)\n\tdecoder\.DisallowUnknownFields\(\)\n\terr = decoder\.Decode\(&(var\w+)\)}
     {\t// Decoded leniently: an unknown attribute does not fail the decode\n\t// (scripts/postprocess_nchf_handmods.sh).\n\terr = json.Unmarshal(data, &$1)}g;
  ' "$f"
  grep -q 'decoder\.DisallowUnknownFields()' "$f" && fail "the strict decoder in $(basename "$f") has an unexpected form"
  # The strict decoder was the only use of "bytes".
  grep -q 'bytes\.' "$f" || perl -0777 -pi -e 's/\n\t"bytes"//' "$f"
  n=$((n + 1))
done
echo "1. lenient-decode: ${n} model(s)" >&2

# --- 2. regexp-commas ---
n=$( (grep -l 'validate:"regexp=[^"]*\\\\,' "${PKG_DIR}"/*.go || true) | wc -l | tr -d ' ')
perl -pi -e 's{(validate:"regexp=[^"]*)}{ (my $t = $1) =~ s/\\\\,/,/g; $t }ge' "${PKG_DIR}"/*.go
grep -q 'validate:"regexp=[^"]*\\,' "${PKG_DIR}"/*.go && fail "an escaped comma survived in a validate tag"
echo "2. regexp-commas: ${n} file(s)" >&2

# --- 3. openapi-validate ---
n=0
for f in "${PKG_DIR}"/*.go; do
  grep -q '"gopkg.in/validator.v2"' "$f" || continue
  perl -0777 -pi -e 's{\t"gopkg.in/validator.v2"\n}{\t"github.com/omec-project/openapi/v2"\n}; s{\bvalidator\.Validate\(}{openapi.Validate(}g' "$f"
  n=$((n + 1))
done
grep -q 'validator\.' "${PKG_DIR}"/*.go && fail "a validator.v2 use survived"
echo "3. openapi-validate: ${n} file(s)" >&2

# --- 4. lenient-problem-details ---
n=0
for f in "${PKG_DIR}"/model_*.go; do
  grep -q '&dst\.ProblemDetails)' "$f" || continue
  perl -0777 -ne 'exit(!m{// try to unmarshal data into ProblemDetails\n(?:(?!// try to unmarshal data into).)*\z}s)' "$f" ||
    fail "ProblemDetails is not the last candidate in $(basename "$f")"
  if grep -q 'err = newStrictDecoder(data).Decode(&dst.ProblemDetails)' "$f"; then
    perl -0777 -pi -e '
      s#\terr = newStrictDecoder\(data\)\.Decode\(&dst\.ProblemDetails\)\n\tif err == nil \{\n#\t// Decoded leniently, and only when no other candidate matched\n\t// (scripts/postprocess_nchf_handmods.sh).\n\terr = json.Unmarshal(data, &dst.ProblemDetails)\n\tif err == nil && match == 0 {\n#
    ' "$f"
  fi
  grep -q 'if err == nil && match == 0 {' "$f" || fail "the ProblemDetails candidate in $(basename "$f") has an unexpected form"
  n=$((n + 1))
done
[ "${n}" -gt 0 ] || fail "no oneOf wrapper has a ProblemDetails candidate"
echo "4. lenient-problem-details: ${n} wrapper(s)" >&2

# --- 5. client-staticcheck ---
CLIENT="${PKG_DIR}/client.go"
STATICCHECK='
  $n = 0;
  $n += s{errors\.New\("Cannot specify postBody and multipart form at the same time\."\)}{errors.New("cannot specify postBody and multipart form at the same time")};
  $n += s{errors\.New\("Cannot specify postBody and x-www-form-urlencoded form at the same time\."\)}{errors.New("cannot specify postBody and x-www-form-urlencoded form at the same time")};
  $n += s{errors\.New\("Unknown type with GetActualInstance but no unmarshalObj\.UnmarshalJSON defined"\)}{errors.New("unknown type with GetActualInstance but no unmarshalObj.UnmarshalJSON defined")};
  $n += s{fmt\.Errorf\("invalid body type %s\\n", contentType\)}{fmt.Errorf("invalid body type %s", contentType)};
  $n += s{\tif f, ok := v\.\(\*os\.File\); ok \{\n.*?\n\t\}\n(\tif f, ok := v\.\(\*\*os\.File\); ok \{)}{$1}s;
'
# Count the matches on a copy first: the file is written only if all five match.
matches=$(perl -0777 -ne "${STATICCHECK}"' print $n' "${CLIENT}")
if [ "${matches}" = 5 ]; then
  perl -0777 -pi -e "${STATICCHECK}" "${CLIENT}"
  echo "5. client-staticcheck: applied" >&2
elif [ "${matches}" = 0 ] && grep -q 'cannot specify postBody and multipart form' "${CLIENT}" && ! grep -q 'v.(\*os.File)' "${CLIENT}"; then
  echo "5. client-staticcheck: already applied" >&2
else
  fail "client.go matches ${matches} of the 5 expected patterns"
fi

# --- 6. fui-without-action ---
MUI="${PKG_DIR}/model_multiple_unit_information.go"
[ "$(grep -l 'FinalUnitIndication \*FinalUnitIndication' "${PKG_DIR}"/model_*.go)" = "${MUI}" ] ||
  fail "a model other than MultipleUnitInformation holds a FinalUnitIndication"
if grep -q 'A finalUnitIndication without a finalUnitAction is absent' "${MUI}"; then
  echo "6. fui-without-action: already applied" >&2
elif perl -0777 -ne 'exit(!m/\n\t\*o = MultipleUnitInformation\(varMultipleUnitInformation\)\n/)' "${MUI}"; then
  perl -0777 -pi -e '
    s#\n\t\*o = MultipleUnitInformation\(varMultipleUnitInformation\)\n#\n\t// A finalUnitIndication without a finalUnitAction is absent\n\t// (scripts/postprocess_nchf_handmods.sh).\n\tif fui := varMultipleUnitInformation.FinalUnitIndication; fui != nil \&\&\n\t\t(fui.FinalUnitAction == nil || fui.FinalUnitAction.String == nil || *fui.FinalUnitAction.String == "") {\n\t\tvarMultipleUnitInformation.FinalUnitIndication = nil\n\t}\n\n\t*o = MultipleUnitInformation(varMultipleUnitInformation)\n#;
  ' "${MUI}"
  echo "6. fui-without-action: applied" >&2
else
  fail "MultipleUnitInformation.UnmarshalJSON has an unexpected form"
fi

# --- SPDX header ---
n=0
for f in "${PKG_DIR}"/*.go; do
  head -n 3 "$f" | grep -q 'SPDX-License-Identifier' && continue
  # REUSE-IgnoreStart
  { printf '// SPDX-FileCopyrightText: 2026 Forsway Scandinavia AB\n// SPDX-License-Identifier: Apache-2.0\n\n'; cat "$f"; } >"$f.tmp"
  # REUSE-IgnoreEnd
  mv "$f.tmp" "$f"
  n=$((n + 1))
done
echo "SPDX header: ${n} file(s)" >&2

# --- formatting, as the gci hook does it ---
gofmt -w "${PKG_DIR}"
(cd "${PKG_DIR}" && GOWORK=off go run github.com/daixiang0/gci@v0.14.0 write ./*.go)
