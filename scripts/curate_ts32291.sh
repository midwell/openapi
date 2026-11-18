#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Forsway Scandinavia AB
# SPDX-License-Identifier: Apache-2.0
#
# Produces Nchf_ConvergedCharging/api/ts32291_nchf_convergedcharging.bundled.yaml,
# the single document the Nchf_ConvergedCharging client is generated from.
#
# 1. Fetch. TS 32.291 and every spec it reaches, directly or through another,
#    come from the 3GPP Forge's 5G_APIs repository at a pinned commit, the
#    TSG113-Rel18 tag (TS 32.291 V18.12.0, API 3.2.3), and are checked against
#    their SHA-256. They are cached in tmp/specs/, not committed.
#
# 2. Curate. Each spec is copied to tmp/curated/ with:
#    - trailing whitespace dropped, and $refs into another YAML quoted, so the
#      '#' is not read as a comment;
#    - TS 32.291: "application/ json" read as "application/json", and the
#      TriggerType items ANY_OTHER_SIP_MESSAGE and SIP_BYE_MESSAGE, which the
#      spec runs together on one line, split. Merged, they generate one value
#      that matches neither, so a CHF sending either fails the whole decode;
#    - an integer whose range does not fit an int32 typed "format: int64": one
#      whose maximum is above 2147483647, or that has a minimum but no maximum
#      (widen_integers below), and the integers of TS 32.291 it gives no range
#      for although their source is wider (WIDE_32291). The generator types
#      an integer without a format int32, and a larger value then fails the
#      whole decode. An integer with neither bound stays int32;
#    - GeographicArea given its own discriminator over the seven shapes it
#      holds (see the TS29572 case below);
#    - DateTime, which TS 29.122 and TS 28.623 also define, taken from
#      TS 29.571, and the schemas of TS 28.623 and TS 28.538 whose names
#      TS 29.571 or TS 29.572 give a different schema prefixed "Nrm", so the
#      bundle holds one schema per name.
#
# 3. Bundle. Redocly, pinned by digest, resolves every $ref from TS 32.291
#    into one document that holds only the schemas TS 32.291 reaches, and
#    fails on a $ref it cannot resolve. The generator does not: a single $ref
#    it cannot resolve makes it leave others unresolved too, and it types
#    them as a generic Object, with warnings but without failing (from the
#    first eight specs pinned below alone, about 300 fields). In the bundle,
#    a oneOf or anyOf whose alternatives only require one property or another
#    is removed (see below).
#
# The bundle is not formatted with yamlfmt (the pre-commit hook excludes it):
# it rewrites escaped characters in descriptions, which changes their text.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SPEC_DIR="${ROOT_DIR}/tmp/specs"
CUR_DIR="${ROOT_DIR}/tmp/curated"
BUNDLE="Nchf_ConvergedCharging/api/ts32291_nchf_convergedcharging.bundled.yaml"
REDOCLY="redocly/cli:1.34.5@sha256:187c9838a3455d6e7820a19515982beafa26eb602949a27722976a85a73ea5ff"

FORGE="https://forge.3gpp.org/rep/all/5G_APIs/-/raw"
COMMIT="23e067d6e0ca5cade08e94cd000a6cb721fba037" # tag TSG113-Rel18
ENTRY="TS32291_Nchf_ConvergedCharging"
# Integers TS 32.291 gives no range, whose source is wider than an int32:
# the Unsigned32 AVPs of TS 32.299 (Local-Sequence-Number, Time-Quota-Threshold,
# Unit-Quota-Threshold, Content-Size) and the NGAP UE IDs of TS 38.413
# (AMF UE NGAP ID up to 2^40-1, RAN UE NGAP ID up to 2^32-1).
WIDE_32291="localSequenceNumber|timeQuotaThreshold|unitQuotaThreshold|contentSize|amfUeNgapId|ranUeNgapId"

# <spec> <sha256 of the file at COMMIT>
PINNED="
TS32291_Nchf_ConvergedCharging 3d22a08c37f75be5a505e87e2180576696419ef70a38ac2cc9076bfac51f586e
TS29571_CommonData aaff81ee4d8b5d75b6b7c0c995fe3e4b3bd11145a217ddf09595f550e99ef514
TS29512_Npcf_SMPolicyControl bb326c207f74c92ef303816964af3036cc3f9b268d6240e7c2abc3eceb6770fc
TS29520_Nnwdaf_EventsSubscription 6603c6af385accee815a5bbc76152fb52afbed66167ced9f0ac96f1a9ebe7dee
TS28538_EdgeNrm 07310dcca1128ea69302bc69b8e1383164738da3c12f2f6702494723da547bba
TS28623_ComDefs 43fd19dd0c6ced2ca122c3760215a47718c35dae0f2ef5a0cc3a61e160e4743c
TS28623_GenericNrm 75d5b3345ac3da62a12099f9820473bb3385a0f196cde48b588b7dd9b7ca998f
TS28541_NrNrm 710bb14c098f0bfd37db8f5434c2cabcfc95c1b4ad369af9e454676966c5990a
TS28541_SliceNrm 967942eff1963bfe612af020e5fe4ad6ff1134475ae8a6676ac232bc0c2a62c1
TS29122_CommonData 63844493dc494c677d1bf9d53939f3279096fb8b63e4e86e7b8d09b7138923d2
TS29508_Nsmf_EventExposure 97f739b75024f1d45b211220a82c39e48f5e7d5e32ed19d22b6c0477dfbae4cd
TS29510_Nnrf_AccessToken 6878a7dc76a0cb8f14d18b98b6727412c0bf68f60fe94ec7ed9b22daaeafd36c
TS29510_Nnrf_NFDiscovery cb55d9118634dfa888e6b2574daf80bbfb70ee0048ca77ecda68a999a25bce96
TS29510_Nnrf_NFManagement 1f0aba0b0234637a0ab876d690cdb30384b11f0fbaf44d9f7447f1fe27acfbbe
TS29517_Naf_EventExposure 193190bd7916af692c84a3e9b3e5ad28d31a51fc46292f284dbaf01bd058c03b
TS29522_AMPolicyAuthorization 4333322faf520db15e885b52743e3cf3e3235e8a5c1c89c73b4bed84ee9b2f74
TS29531_Nnssf_NSSelection 1b6b5dd1a19f7256b02ef850135580f17a1f444493703bf57c8795e9141e16c5
TS29554_Npcf_BDTPolicyControl 9dd9e32af85c9d0f1059fb7a409d07283fe1b740756b65f9fc4bd353151a96c4
TS29572_Nlmf_Location 2590d73f3a36643fb712f8ea3074680a3d129406533fb0dc7164ec0375e025ee
"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

rm -rf "${CUR_DIR}"
mkdir -p "${SPEC_DIR}" "${CUR_DIR}"

# 1. Fetch and check every pinned spec.
echo "${PINNED}" | while read -r spec sum; do
  [ -n "${spec}" ] || continue
  src="${SPEC_DIR}/${spec}.yaml"
  if [ ! -f "${src}" ] || [ "$(sha256 "${src}")" != "${sum}" ]; then
    curl -sSfL -o "${src}" "${FORGE}/${COMMIT}/${spec}.yaml"
  fi
  if [ "$(sha256 "${src}")" != "${sum}" ]; then
    echo "ERROR: ${spec}.yaml at ${COMMIT} does not have the pinned SHA-256" >&2
    exit 1
  fi
done

# 2. Curate.
for spec in $(echo "${PINNED}" | cut -d' ' -f1); do
  fix=""
  case "${spec}" in
  TS32291_*)
    fix='s/application\/\s+json/application\/json/g;'
    fix+='s/^( +)- ANY_OTHER_SIP_MESSAGE +- SIP_BYE_MESSAGE\n/$1- ANY_OTHER_SIP_MESSAGE\n$1- SIP_BYE_MESSAGE\n/m;'
    fix+="s/^( +)(${WIDE_32291}):\n(\1  )type: integer\n/\$1\$2:\n\$3type: integer\n\$3format: int64\n/mg;"
    ;;
  TS29572_*)
    # GeographicArea discriminates its seven shapes by the "shape" of
    # GADShape, whose mapping also names two local shapes GeographicArea does
    # not hold. The generator emits a branch for every name in the mapping,
    # and one for a shape it holds no field for does not compile.
    fix='s/(\n    GeographicArea:\n      description: [^\n]*\n      anyOf:\n((?:        - \$ref: [^\n]*\n)+))/$1      discriminator:\n        propertyName: shape\n        mapping:\n          POINT: "#\/components\/schemas\/Point"\n          POINT_UNCERTAINTY_CIRCLE: "#\/components\/schemas\/PointUncertaintyCircle"\n          POINT_UNCERTAINTY_ELLIPSE: "#\/components\/schemas\/PointUncertaintyEllipse"\n          POLYGON: "#\/components\/schemas\/Polygon"\n          POINT_ALTITUDE: "#\/components\/schemas\/PointAltitude"\n          POINT_ALTITUDE_UNCERTAINTY: "#\/components\/schemas\/PointAltitudeUncertainty"\n          ELLIPSOID_ARC: "#\/components\/schemas\/EllipsoidArc"\n/;'
    ;;
  esac
  perl -0777 -pe "
    s/[ \\t]+\$//mg;
    ${fix}
    s/(\\\$ref:\\s*)(TS[0-9A-Za-z_]+\\.[Yy][Aa][Mm][Ll]#[^\\n]+)/\$1'\$2'/g;
  " "${SPEC_DIR}/${spec}.yaml" >"${CUR_DIR}/${spec}.yaml"
done

# DateTime, which TS 29.122 and TS 28.623 define as TS 29.571 does, a string
# of format date-time, is TS 29.571's wherever it is referred to.
for spec in TS29122_CommonData TS28623_ComDefs; do
  perl -0777 -pi -e "s{'#/components/schemas/DateTime'}{'TS29571_CommonData.yaml#/components/schemas/DateTime'}g;" "${CUR_DIR}/${spec}.yaml"
  perl -0777 -pi -e "s{${spec}\\.yaml#/components/schemas/DateTime'}{TS29571_CommonData.yaml#/components/schemas/DateTime'}g;" "${CUR_DIR}"/*.yaml
done

# Schemas of the management specs (TS 28.623, TS 28.538) whose names TS 29.571
# or TS 29.572 also define, with a different schema, are prefixed "Nrm", so
# the bundle can hold both: <spec> <names>.
NRM_RENAMES="
TS28623_ComDefs Mcc|Mnc|PlmnId|Tac
TS28623_GenericNrm Tac|Tai
TS28538_EdgeNrm GeographicalCoordinates
"
echo "${NRM_RENAMES}" | while read -r spec names; do
  [ -n "${spec}" ] || continue
  perl -0777 -pi -e "s/^    (${names}):\$/    Nrm\$1:/mg; s{'#/components/schemas/(${names})'}{'#/components/schemas/Nrm\$1'}g;" \
    "${CUR_DIR}/${spec}.yaml"
  perl -0777 -pi -e "s{(${spec}\\.yaml#/components/schemas/)(${names})'}{\$1Nrm\$2'}g;" "${CUR_DIR}"/*.yaml
done

# widen_integers types "format: int64" every integer schema whose maximum
# exceeds 2147483647, or that has a minimum but no maximum (Uinteger, Uint64
# and the like: the spec bounds them only below). A "format: int32" such a
# schema carries, as TS 29.571's Uint32Rm does, is replaced.
widen_integers() {
  perl -0777 -pi -e '
    my @l = split /^/m;
    my $ind = sub { $_[0] =~ /^( *)(- )?/; length($1) + ($2 ? 2 : 0) };
    my $key = sub { $_[0] =~ /^ *(?:- )?([A-Za-z\$]+):\s*(.*?)\s*(?:#.*)?$/ ? ($1, $2) : () };
    for (my $i = 0; $i < @l; $i++) {
      next unless $l[$i] =~ /^ *(?:- )?type: integer\s*$/;
      my $n = $ind->($l[$i]);
      my @sib = ($i);
      if ($l[$i] !~ /^ *- /) {
        for (my $k = $i - 1; $k >= 0; $k--) {
          next if $l[$k] =~ /^\s*(#.*)?$/;
          my $m = $ind->($l[$k]);
          last if $m < $n;
          next if $m > $n;
          unshift @sib, $k;
          last if $l[$k] =~ /^ *- /;
        }
      }
      for (my $j = $i + 1; $j < @l; $j++) {
        next if $l[$j] =~ /^\s*(#.*)?$/;
        my $m = $ind->($l[$j]);
        last if $m < $n || ($m == $n && $l[$j] =~ /^ *- /);
        push @sib, $j if $m == $n;
      }
      my %v; my $fmt;
      for my $s (@sib) {
        my ($k, $val) = $key->($l[$s]);
        next unless defined $k;
        $v{$k} = $val;
        $fmt = $s if $k eq "format";
      }
      my $wide = defined $v{maximum} ? $v{maximum} > 2147483647 : defined $v{minimum};
      next unless $wide;
      if (defined $fmt) {
        $l[$fmt] =~ s/format: int32\b/format: int64/;
      } else {
        splice @l, $i + 1, 0, (" " x $n) . "format: int64\n";
      }
    }
    $_ = join "", @l;
  ' "$1"
}
for f in "${CUR_DIR}"/*.yaml; do
  widen_integers "$f"
done

# The fixes must have applied: a silent miss would regenerate a different client.
entry="${CUR_DIR}/${ENTRY}.yaml"
if grep -q 'application/ json' "${entry}"; then
  echo "ERROR: an 'application/ json' media type survived curation" >&2
  exit 1
fi
if grep -q 'ANY_OTHER_SIP_MESSAGE *- SIP_BYE_MESSAGE' "${entry}" || ! grep -q -- '- SIP_BYE_MESSAGE$' "${entry}"; then
  echo "ERROR: the TriggerType items ANY_OTHER_SIP_MESSAGE and SIP_BYE_MESSAGE are not split" >&2
  exit 1
fi
if [ "$(perl -0777 -ne "print scalar(() = m/^ +(?:${WIDE_32291}):\\n +type: integer\\n/mg)" "${entry}")" != 11 ] ||
  [ "$(perl -0777 -ne "print scalar(() = m/^ +(?:${WIDE_32291}):\\n +type: integer\\n +format: int64\\n/mg)" "${entry}")" != 11 ]; then
  echo "ERROR: an integer of TS 32.291 listed in WIDE_32291 is not typed int64 after curation" >&2
  exit 1
fi
for name in Uint32 Uint64 Uinteger ChargingId; do
  if ! perl -0777 -ne "exit(!m/\\n    ${name}:\\n(?:(?!    \\S).*\\n)*?      format: int64\\n/)" "${CUR_DIR}/TS29571_CommonData.yaml"; then
    echo "ERROR: ${name} in TS 29.571 is not typed int64 after curation" >&2
    exit 1
  fi
done
if ! perl -0777 -ne 'exit(!m/\n    GeographicArea:\n(?:(?!    \S).*\n)*?      discriminator:\n/)' "${CUR_DIR}/TS29572_Nlmf_Location.yaml"; then
  echo "ERROR: GeographicArea in TS 29.572 has no discriminator of its own after curation" >&2
  exit 1
fi

# 3. Bundle.
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "${ROOT_DIR}:/local" \
  -w /local \
  "${REDOCLY}" bundle "tmp/curated/${ENTRY}.yaml" -o tmp/bundle.yaml

# A oneOf or anyOf whose alternatives only require one property or another
# ("exactly one of cgi, sai or lai shall be present") is removed. In its
# presence the generator writes the schema's struct without json tags and
# without the imports its fields need; without it, the struct is the same
# but for those. The client does not check which alternative is present.
n=$(perl -0777 -ne 'while (/^( +)(?:oneOf|anyOf):\n(?:\1  - required:\n(?:\1      - \S+\n)+)+(?!\1  - )/mg) { $n++ } print $n + 0' "${ROOT_DIR}/tmp/bundle.yaml")
perl -0777 -pi -e 's/^( +)(?:oneOf|anyOf):\n(?:\1  - required:\n(?:\1      - \S+\n)+)+(?!\1  - )//mg' "${ROOT_DIR}/tmp/bundle.yaml"
echo "removed ${n} required-only oneOf/anyOf" >&2

{
  # REUSE-IgnoreStart
  echo "# SPDX-FileCopyrightText: 2026 Forsway Scandinavia AB"
  echo "# SPDX-License-Identifier: Apache-2.0"
  # REUSE-IgnoreEnd
  echo "#"
  echo "# Bundled by scripts/curate_ts32291.sh from 3GPP 5G_APIs ${ENTRY}.yaml"
  echo "# and the specs it refers to, at ${COMMIT} (TSG113-Rel18); do not edit."
  echo
  cat "${ROOT_DIR}/tmp/bundle.yaml"
} >"${ROOT_DIR}/${BUNDLE}"

# Redocly gives a schema whose name another, different schema already holds a
# prefixed name ("schemas-PlmnId"). Every such clash is resolved above, by name.
if awk '/^  schemas:/{s=1;next} s && /^  [^ ]/{s=0} s && /^    [^ ]/' "${ROOT_DIR}/${BUNDLE}" | grep -vqE '^    [A-Za-z0-9]+:$'; then
  echo "ERROR: the bundle renamed a schema whose name clashes with another; add it to NRM_RENAMES" >&2
  exit 1
fi
echo "bundled ${BUNDLE}" >&2
