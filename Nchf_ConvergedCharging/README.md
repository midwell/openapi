<!--
SPDX-FileCopyrightText: 2026 Forsway Scandinavia AB
SPDX-License-Identifier: Apache-2.0
-->

# Nchf_ConvergedCharging

Go client for the CHF's Nchf_ConvergedCharging service, 3GPP TS 32.291
V18.12.0 (Rel-18, API 3.2.3), generated with OpenAPI Generator 7.25.0. The
package is self-contained: it carries its own models, as TS 32.291 refers to
schemas the `models` package does not have.

Read and write the models through their accessors and constructors (`GetX`,
`GetXOk`, `HasX`, `SetX`, `NewX`) rather than their fields.

## Source

`api/ts32291_nchf_convergedcharging.bundled.yaml` is the single document the
client is generated from. `scripts/curate_ts32291.sh` produces it:

1. **Fetch.** TS 32.291 and the 18 specs it reaches, directly or through
   another, come from the 3GPP Forge's 5G_APIs repository
   (`forge.3gpp.org/rep/all/5G_APIs`) at tag `TSG113-Rel18`
   (`23e067d6e0ca5cade08e94cd000a6cb721fba037`). Each file's SHA-256 is
   checked.
2. **Curate.**
   - `application/ json` is read as `application/json`, and the TriggerType
     items `ANY_OTHER_SIP_MESSAGE` and `SIP_BYE_MESSAGE`, which TS 32.291 runs
     together on one line, are split. Merged, they generate one value that
     matches neither.
   - An integer whose range does not fit an `int32` is typed `int64`: one whose
     maximum is above 2147483647 (`Uint32`, `Uint64`), or that has a minimum
     but no maximum (`Uinteger`, `PacketDelBudget`), and those TS 32.291
     gives no range although their source is wider: `localSequenceNumber`,
     `timeQuotaThreshold`, `unitQuotaThreshold` and `contentSize` (Unsigned32
     in TS 32.299), and `amfUeNgapId` and `ranUeNgapId` (TS 38.413). The
     generator types an integer without a format `int32`, and a larger value
     fails the whole decode. A `Uint64` above 2^63-1 still does not fit, and
     an integer with neither bound, such as `DurationSec`, stays `int32`.
   - `GeographicArea` gets its own discriminator, mapping only the seven shapes
     it holds. It inherits one from `GADShape` that also names two local
     shapes, and the generator writes a branch for each name in it.
   - Where TS 29.122 or TS 28.623 define `DateTime` as TS 29.571 does, TS
     29.571's is used, and the schemas of TS 28.623 and TS 28.538 whose names
     TS 29.571 or TS 29.572 give a different schema are prefixed `Nrm`
     (`NrmPlmnId`), so the bundle holds one schema per name.
3. **Bundle.** Redocly, pinned by digest, resolves every `$ref` into one
   document holding only the schemas TS 32.291 reaches, and fails on one it
   cannot resolve. A `oneOf` or `anyOf` whose alternatives only require one
   property or another ("exactly one of cgi, sai or lai") is removed: with it,
   the generator writes the struct without json tags and without the imports
   its fields need. The client does not check which alternative is present.
   This applies to `IMSAddress`, `ServingNodeAddress`, `MbsSessionId`,
   `MbsServiceArea`, `ServerAddressingInfo`, `GlobalRanNodeId`,
   `UtraLocation`, `GeraLocation`, `IpAddr`, `GeoDistributionInfo` and
   `Area`.

The generator is given the bundle rather than the specs because Redocly fails
on a `$ref` it cannot resolve, and the generator does not: a single `$ref` it
cannot resolve makes it leave others unresolved too, and it types them as a
generic `Object`, with warnings but without failing.

## Regenerating

```bash
scripts/generate_nchf_convergedcharging_docker.sh
```

Needs Docker, Go and network access. It produces the bundle, generates from
it with the pinned generator image, fails if the generator reports a `$ref` it
could not resolve, adopts the result and re-applies the hand-modifications
below. A regeneration from the same source leaves `git status` clean.

## Hand-modifications

`scripts/postprocess_nchf_handmods.sh` applies these on every regeneration:

1. **Lenient decode.** Models decode with `json.Unmarshal`, without
   `DisallowUnknownFields`, so an attribute added in a later release of the
   spec does not fail the whole answer. The `oneOf` wrappers still try a
   candidate with a strict decoder, which a model with required properties
   overrides with its own lenient one; `ChargingNotifyResponse`, which has
   none, decodes strictly there.
2. **Unescaped regexp commas.** The generator escapes each comma in a
   `regexp=` validate tag (`{5\,15}`) for `gopkg.in/validator.v2`, which reads
   commas as rule separators. `openapi.Validate` takes the whole tag as the
   pattern, as the `models` package's tags are written, so the escape is
   removed.
3. **`openapi.Validate`** checks a `oneOf` candidate, as in the `models`
   package, instead of `gopkg.in/validator.v2`.
4. **Lenient ProblemDetails.** The `oneOf` wrappers of the error answers decode
   their ProblemDetails candidate, the last one they try, leniently and only
   when no other candidate matched. The other candidates are still told apart
   by their required properties, but for `ChargingNotifyResponse` in
   `ChargingdataPost400Response1`, a wrapper no operation of the client uses.
5. **`client.go` passes staticcheck:** error strings lower-case without
   trailing punctuation, as in the other clients, and the decode branch for
   `*os.File` dropped. It wrote the body to a temporary file through a local
   copy of the pointer, so the caller never saw it; `**os.File` still works.

Every generated file gets the repository's SPDX header and is formatted with
`gofmt` and `gci`.
