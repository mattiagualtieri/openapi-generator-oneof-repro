# openapi-generator: `description` breaks single-member `oneOf` simplification (7.22.0+)

## Summary

The `spring` generator is supposed to simplify a `oneOf` schema with exactly
one `$ref` sub-schema into just that sub-schema: no separate model is
generated for the wrapper, and anything that references it (a request body,
in this repro) uses the sub-schema's type directly.

This still works in 7.21.0. Starting with **7.22.0**, and still broken in
**7.26.0** (latest version at the time of writing), it only works if the
wrapper schema has **no `description`**. Add a `description:` to the
wrapper and the generator keeps it as its own model, changing the type used
in the request body. This is a surprising, easy-to-miss trigger: a
no-op-looking field (a schema description) changes generated code.

## Try it

Just Maven, no manual downloads:

```bash
mvn generate-sources
./check.sh
```

```
PASS  spec.yaml (Shape has a description)       -> Circle.java
PASS  spec-no-description.yaml (control case)   -> Circle.java
```
on a working generator, or:
```
FAIL  spec.yaml (Shape has a description)       -> Circle.java Shape.java
PASS  spec-no-description.yaml (control case)   -> Circle.java
```
on 7.22.0+.

Test a specific version:

```bash
mvn clean generate-sources -Dopenapi-generator.version=7.21.0 && ./check.sh   # passes
mvn clean generate-sources -Dopenapi-generator.version=7.22.0 && ./check.sh   # fails
mvn clean generate-sources -Dopenapi-generator.version=7.26.0 && ./check.sh   # still fails
```

`pom.xml` pins the version to `7.26.0` by default (the `openapi-generator.version`
property); override it with `-D` as shown above.

## Files

- `pom.xml` — runs `openapi-generator-maven-plugin` twice, once per spec
  below, each into its own `target/generated-*` directory.
- `spec.yaml` — `Shape` is a `oneOf` with one `$ref` (`Circle`) **and a
  `description`**. Triggers the bug on 7.22.0+.
- `spec-no-description.yaml` — identical, minus the `description` on
  `Shape`. Generates correctly on every version; this is the control case
  proving the `description` is the trigger, not the `oneOf` itself.
- `check.sh` — reads `target/` after `mvn generate-sources` and prints a
  PASS/FAIL summary.

## What was ruled out

Earlier passes over this bug suspected the `discriminator` keyword, since
that was present in the spec that surfaced this downstream. It is **not**
the cause — removing it while keeping the `description` still reproduces
the bug, and removing the `description` while keeping the discriminator
makes the bug disappear. `spec.yaml` has no discriminator at all, by design,
to keep the repro minimal.

These generator flags were also tried (via the CLI directly) and none
restore the old behavior:

- `--openapi-normalizer SIMPLIFY_ONEOF_ANYOF=true` (even forced explicitly)
- `--openapi-normalizer REPLACE_ONE_OF_BY_DISCRIMINATOR_MAPPING=true` — this
  actually produces no API operation at all for this spec shape, so it
  isn't a usable workaround either
- `legacyDiscriminatorBehavior=true` / `false`

## Root cause (known, from a downstream project's PR)

[SAP/cloud-sdk-java#1179](https://github.com/SAP/cloud-sdk-java/pull/1179)
pinpoints it:

> 7.22.0 added description transfers in
> `ModelUtils.simplifyOneOfAnyOfWithOnlyOneNonNullSubSchema` when
> simplifying `oneOf` schemas. This triggered an existing normalizer step
> `OpenAPINormalizer.normalizeReferenceSchema` that thought the
> `description` was alongside the `$ref` in the spec, which is not allowed.

A fix for that mechanism was merged upstream in
[openapi-generator#23361](https://github.com/OpenAPITools/openapi-generator/pull/23361)
(2026-04-01, in `ModelUtils.java`). This repro shows it isn't (fully)
effective: 7.26.0, well after that merge, still reproduces the bug.

No public GitHub issue was found for this on `OpenAPITools/openapi-generator`
as of 2026-10-29 (searched `is:issue normalizeReferenceSchema`,
`is:issue simplifyOneOfAnyOfWithOnlyOneNonNullSubSchema`, and variations on
"oneOf description 7.22").

## Workaround

Remove the `description` from the wrapper schema, or point whatever
references it (request body, response, property, ...) directly at the
concrete sub-schema instead of the wrapper. Both require a spec change;
no generator flag avoids this.
