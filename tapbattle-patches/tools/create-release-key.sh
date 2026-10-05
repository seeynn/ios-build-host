#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-$HOME/.tapbattle-release-key}"

if [ -e "$OUT_DIR/release-private.pem" ]; then
  echo "Refusing to overwrite existing release key: $OUT_DIR/release-private.pem"
  exit 1
fi

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

openssl genpkey   -algorithm RSA   -pkeyopt rsa_keygen_bits:3072   -out "$OUT_DIR/release-private.pem"
chmod 600 "$OUT_DIR/release-private.pem"

openssl pkey   -in "$OUT_DIR/release-private.pem"   -pubout   -outform DER   -out "$OUT_DIR/release-public.der"

openssl base64 -A -in "$OUT_DIR/release-public.der" > "$OUT_DIR/release-public.der.b64"
printf '\n' >> "$OUT_DIR/release-public.der.b64"

openssl base64 -A -in "$OUT_DIR/release-private.pem" > "$OUT_DIR/release-private.pem.b64"
printf '\n' >> "$OUT_DIR/release-private.pem.b64"
chmod 600 "$OUT_DIR/release-private.pem.b64"

echo "Release signing key created in: $OUT_DIR"
echo "Upload ONLY release-private.pem.b64 to the protected GitHub environment secret:"
echo "  TAPBATTLE_RELEASE_PRIVATE_KEY_B64"
echo
echo "release-public.der.b64 is safe to use in the root-signed trust bundle."
echo "Keep release-private.pem and release-private.pem.b64 private."
