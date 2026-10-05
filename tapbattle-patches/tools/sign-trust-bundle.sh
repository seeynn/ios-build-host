#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 ROOT_PRIVATE_PEM TRUSTED_KEYS_PROPERTIES OUTPUT_SIGNATURE"
  exit 2
fi

ROOT_PRIVATE="$1"
TRUST_FILE="$2"
OUT_SIG="$3"

test -f "$ROOT_PRIVATE"
test -f "$TRUST_FILE"

TMP_SIG="$(mktemp)"
trap 'rm -f "$TMP_SIG"' EXIT

openssl dgst -sha256 -sign "$ROOT_PRIVATE" -out "$TMP_SIG" "$TRUST_FILE"
openssl base64 -A -in "$TMP_SIG" > "$OUT_SIG"
printf '\n' >> "$OUT_SIG"

echo "Signed trust bundle: $OUT_SIG"
