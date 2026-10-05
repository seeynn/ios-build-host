#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$HOME/.tapbattle-offline-root"
REL_DIR="$HOME/.tapbattle-release-key"
OUT_DIR="$HOME/.tapbattle-signing-public"

ROOT_PRIVATE="$ROOT_DIR/root-private.pem"
ROOT_PUBLIC="$ROOT_DIR/root-public.der.b64"
RELEASE_PUBLIC="$REL_DIR/release-public.der.b64"

for f in "$ROOT_PRIVATE" "$ROOT_PUBLIC" "$RELEASE_PUBLIC"; do
  [ -f "$f" ] || { echo "Missing: $f"; exit 1; }
done

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

NOW="$(date +%s)"
UNTIL="$((NOW + 31536000))"
PUB_B64="$(tr -d '\r\n\t ' < "$RELEASE_PUBLIC")"

cat > "$OUT_DIR/trusted-keys.properties" <<EOF
trust.version=1
valid.from.epoch=$NOW
valid.until.epoch=$UNTIL
minimum.patch.version=1
key.count=1

key.0.id=release-2026-01
key.0.status=trusted
key.0.algorithm=SHA256withRSA
key.0.valid.from.epoch=$NOW
key.0.valid.until.epoch=$UNTIL
key.0.publicKey=$PUB_B64
EOF

TMP_SIG="$(mktemp)"
trap 'rm -f "$TMP_SIG"' EXIT
openssl dgst -sha256 -sign "$ROOT_PRIVATE" -out "$TMP_SIG" "$OUT_DIR/trusted-keys.properties"
openssl base64 -A -in "$TMP_SIG" > "$OUT_DIR/trusted-keys.sig"
printf '\n' >> "$OUT_DIR/trusted-keys.sig"
cp "$ROOT_PUBLIC" "$OUT_DIR/root-public.der.b64"

echo
echo "Done. Safe-to-share files are in:"
echo "  $OUT_DIR"
echo
ls -1 "$OUT_DIR"
echo
echo "These 3 files are PUBLIC and safe to upload:"
echo "  root-public.der.b64"
echo "  trusted-keys.properties"
echo "  trusted-keys.sig"
echo
echo "Do NOT upload root-private.pem or release-private.pem(.b64)."
