#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-$HOME/.tapbattle-offline-root}"

if [ -e "$OUT_DIR/root-private.pem" ]; then
  echo "Refusing to overwrite existing root key: $OUT_DIR/root-private.pem"
  exit 1
fi

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

openssl genpkey   -algorithm RSA   -pkeyopt rsa_keygen_bits:3072   -out "$OUT_DIR/root-private.pem"
chmod 600 "$OUT_DIR/root-private.pem"

openssl pkey   -in "$OUT_DIR/root-private.pem"   -pubout   -outform DER   -out "$OUT_DIR/root-public.der"

openssl base64 -A -in "$OUT_DIR/root-public.der" > "$OUT_DIR/root-public.der.b64"
printf '\n' >> "$OUT_DIR/root-public.der.b64"

echo "Offline root generated in: $OUT_DIR"
echo "KEEP root-private.pem OFFLINE. Never upload it to GitHub, AWS, ChatGPT, email, or cloud storage."
echo "Safe file to copy into the app: $OUT_DIR/root-public.der.b64"
