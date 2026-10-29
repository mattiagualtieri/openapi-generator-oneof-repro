#!/usr/bin/env bash
# Prints a readable PASS/FAIL summary after `mvn generate-sources` has run.
# Usage: mvn generate-sources && ./check.sh
set -euo pipefail
cd "$(dirname "$0")"

check() {
    local label="$1" dir="$2"
    local models
    models=$(find "$dir" -name '*.java' -path '*/model/*' -exec basename {} \; 2>/dev/null | sort | tr '\n' ' ')
    if [ "$models" = "Circle.java " ]; then
        echo "PASS  $label -> $models"
    else
        echo "FAIL  $label -> ${models:-<no models generated, did you run 'mvn generate-sources'?>}"
    fi
}

check "spec.yaml (Shape has a description)      " target/generated-with-description
check "spec-no-description.yaml (control case)  " target/generated-without-description

cat <<'EOF'

Expected on a working generator: both PASS (Circle.java only).
Actual on openapi-generator 7.22.0+: the first one FAILs, also generating
Shape.java and changing the request body type from Circle to Shape.
EOF
