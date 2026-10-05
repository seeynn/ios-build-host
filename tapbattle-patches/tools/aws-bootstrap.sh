#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-central-1}"
GITHUB_OWNER="${GITHUB_OWNER:-seeynn}"
GITHUB_REPO="${GITHUB_REPO:-ios-build-host}"
GITHUB_ENVIRONMENT="${GITHUB_ENVIRONMENT:-tapbattle-release}"
ROLE_NAME="${ROLE_NAME:-TapBattlePatchSignerRole}"
KEY_ALIAS="${KEY_ALIAS:-alias/tapbattle-patch-release-2026-01}"

command -v aws >/dev/null || { echo "AWS CLI is required."; exit 1; }

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

# GitHub repositories created after 2026-07-15 use immutable OIDC
# subjects containing permanent owner/repository numeric IDs. Resolve them from
# GitHub's public repository metadata so the AWS trust policy matches exactly.
GITHUB_META="$(python3 - <<'PY'
import json, os, urllib.request
owner=os.environ.get("GITHUB_OWNER","seeynn")
repo=os.environ.get("GITHUB_REPO","ios-build-host")
with urllib.request.urlopen(f"https://api.github.com/repos/{owner}/{repo}", timeout=15) as r:
    data=json.load(r)
print(data["owner"]["id"], data["id"])
PY
)"
read GITHUB_OWNER_ID GITHUB_REPO_ID <<< "$GITHUB_META"
OIDC_SUBJECT="repo:${GITHUB_OWNER}@${GITHUB_OWNER_ID}/${GITHUB_REPO}@${GITHUB_REPO_ID}:environment:${GITHUB_ENVIRONMENT}"

if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  aws iam create-open-id-connect-provider     --url https://token.actions.githubusercontent.com     --client-id-list sts.amazonaws.com >/dev/null
fi

if aws kms describe-key --key-id "$KEY_ALIAS" --region "$AWS_REGION" >/dev/null 2>&1; then
  KEY_ARN="$(aws kms describe-key --key-id "$KEY_ALIAS" --region "$AWS_REGION" --query KeyMetadata.Arn --output text)"
else
  KEY_ARN="$(aws kms create-key     --region "$AWS_REGION"     --key-spec RSA_3072     --key-usage SIGN_VERIFY     --description "Tap Battle patch release signing key 2026-01"     --tags TagKey=Application,TagValue=TapBattle TagKey=Purpose,TagValue=PatchSigning     --query KeyMetadata.Arn     --output text)"
  aws kms create-alias --region "$AWS_REGION" --alias-name "$KEY_ALIAS" --target-key-id "$KEY_ARN"
fi

TRUST_POLICY="$(mktemp)"
PERMISSION_POLICY="$(mktemp)"
PUB_DER="$(mktemp)"
trap 'rm -f "$TRUST_POLICY" "$PERMISSION_POLICY" "$PUB_DER"' EXIT

cat > "$TRUST_POLICY" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "$OIDC_ARN"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "$OIDC_SUBJECT"
      }
    }
  }]
}
JSON

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "file://$TRUST_POLICY"
else
  aws iam create-role     --role-name "$ROLE_NAME"     --description "OIDC-only GitHub role for Tap Battle manifest signing"     --assume-role-policy-document "file://$TRUST_POLICY" >/dev/null
fi

cat > "$PERMISSION_POLICY" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "SignTapBattlePatchManifestsOnly",
    "Effect": "Allow",
    "Action": ["kms:Sign", "kms:GetPublicKey", "kms:DescribeKey"],
    "Resource": "$KEY_ARN"
  }]
}
JSON

aws iam put-role-policy   --role-name "$ROLE_NAME"   --policy-name TapBattlePatchSigning   --policy-document "file://$PERMISSION_POLICY"

ROLE_ARN="$(aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)"
aws kms get-public-key   --region "$AWS_REGION"   --key-id "$KEY_ARN"   --query PublicKey   --output text | base64 --decode > "$PUB_DER"

echo
echo "AWS signing setup complete."
echo "TAPBATTLE_AWS_REGION=$AWS_REGION"
echo "TAPBATTLE_AWS_ROLE_ARN=$ROLE_ARN"
echo "TAPBATTLE_AWS_KMS_KEY_ARN=$KEY_ARN"
echo "TAPBATTLE_SIGNING_KEY_ID=release-2026-01"
echo "GITHUB_OIDC_SUBJECT=$OIDC_SUBJECT"
echo
echo "Release public key (DER, Base64):"
openssl base64 -A -in "$PUB_DER"
echo
echo
echo "The KMS private key is non-exportable and remains inside AWS KMS."
