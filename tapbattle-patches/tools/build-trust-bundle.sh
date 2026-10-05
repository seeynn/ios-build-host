#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 7 ]; then
  echo "Usage: $0 ROOT_PRIVATE_PEM RELEASE_PUBLIC_DER TRUST_VERSION KEY_ID VALID_FROM_EPOCH VALID_UNTIL_EPOCH OUT_DIR"
  exit 2
fi

ROOT_PRIVATE="$1"
RELEASE_PUBLIC="$2"
TRUST_VERSION="$3"
KEY_ID="$4"
VALID_FROM="$5"
VALID_UNTIL="$6"
OUT_DIR="$7"

mkdir -p "$OUT_DIR"
PUB_B64="$(openssl base64 -A -in "$RELEASE_PUBLIC")"

cat > "$OUT_DIR/trusted-keys.properties" <<EOF
trust.version=$TRUST_VERSION
valid.from.epoch=$VALID_FROM
valid.until.epoch=$VALID_UNTIL
minimum.patch.version=1
key.count=1

key.0.id=$KEY_ID
key.0.status=trusted
key.0.algorithm=SHA256withRSA
key.0.valid.from.epoch=$VALID_FROM
key.0.valid.until.epoch=$VALID_UNTIL
key.0.publicKey=$PUB_B64
EOF

openssl dgst -sha256   -sign "$ROOT_PRIVATE"   -out "$OUT_DIR/trusted-keys.sig.bin"   "$OUT_DIR/trusted-keys.properties"

openssl base64 -A -in "$OUT_DIR/trusted-keys.sig.bin" > "$OUT_DIR/trusted-keys.sig"
printf '\n' >> "$OUT_DIR/trusted-keys.sig"
rm -f "$OUT_DIR/trusted-keys.sig.bin"

echo "Created root-signed trust bundle in $OUT_DIR"
echo "To revoke a release key later: mark its status=revoked, increment trust.version, and sign again with the offline root."
