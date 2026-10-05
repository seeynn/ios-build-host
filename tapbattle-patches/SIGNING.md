# Tap Battle signing bootstrap

Production signing is deliberately split into two trust levels.

- **Offline root key:** authorizes and revokes release keys. Its private half must never enter GitHub, AWS, ChatGPT, email, or cloud storage.
- **AWS KMS release key:** signs patch manifests. Its private half is non-exportable.
- **GitHub Actions:** receives short-lived AWS credentials through OIDC. No AWS access keys are stored in GitHub.

## One-time setup

1. On an offline machine, run `tools/create-offline-root.sh`. Copy only `root-public.der.b64` into the app as `projectui/patch-root-public-key.der.b64`.
2. In AWS CloudShell, run `tools/aws-bootstrap.sh`. It creates/reuses the GitHub OIDC provider, RSA-3072 SIGN_VERIFY KMS key, and least-privilege signer role.
3. In this GitHub repository, create environment `tapbattle-release` and require manual approval.
4. Add these **repository/environment variables** (they are identifiers, not secrets):
   - `TAPBATTLE_AWS_REGION`
   - `TAPBATTLE_AWS_ROLE_ARN`
   - `TAPBATTLE_AWS_KMS_KEY_ARN`
   - `TAPBATTLE_SIGNING_KEY_ID=release-2026-01`
5. Export the KMS public key, then on the offline root machine run `tools/build-trust-bundle.sh` to create `trusted-keys.properties` and `trusted-keys.sig`. Publish both under `tapbattle-patches/`.
6. Prepare a patch on a branch named `release/patch-N`, then manually run **Sign Tap Battle Patch With AWS KMS** from that branch.
7. Merge only after patch validation passes.
8. After a signed real-device Patch 1 test succeeds, enable `signatureRequired=true` in the app.

## Rotation

Create a new KMS release key/alias, add its public key to a new root-signed trust bundle with a higher `trust.version`, publish that trust bundle, then switch `TAPBATTLE_AWS_KMS_KEY_ARN` and `TAPBATTLE_SIGNING_KEY_ID`.

Keep the old key trusted during a short overlap. Then publish another root-signed trust bundle marking it `revoked`.

## Emergency revocation

Disable the compromised KMS key in AWS immediately. On the offline root machine, increment `trust.version`, mark the compromised key `revoked`, add a replacement key, sign the trust bundle, and publish it.

The app refuses manifests signed by a key that the root-signed trust bundle does not mark as trusted.
