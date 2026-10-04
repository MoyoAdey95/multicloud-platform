#!/usr/bin/env bash
# Builds the app image once and pushes that one build to all three
# registries, then reads the digest back from each registry and fails if
# they differ. Every estate runs the image by digest, so this is what makes
# "the same workload on three clouds" literally true.
#
# Usage: scripts/publish-image.sh [tag]
# The tag defaults to the short hash of the current commit. All three
# registries reject a tag that already exists, so a tag is only ever
# pushed once.
#
# Needs: docker, gcloud, aws (profile "personal"), az, and an applied
# gcp, aws and azure root so their registry outputs exist.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-$(git -C "$ROOT" rev-parse --short HEAD)}"
AWS_PROFILE_NAME="personal"
AWS_REGION="eu-west-2"

registry() {
  terraform -chdir="$ROOT/envs/$1" output -raw registry
}

GCP_REPO="$(registry gcp)/platform-api"
AWS_REPO="$(registry aws)"
AZURE_LOGIN="$(registry azure)"
AZURE_REPO="$AZURE_LOGIN/platform-api"
ACR_NAME="${AZURE_LOGIN%%.*}"

echo "Building platform-api:$TAG for linux/amd64"
docker build --platform linux/amd64 -t "platform-api:$TAG" "$ROOT/app"

echo "Signing in to the three registries"
gcloud auth configure-docker "${GCP_REPO%%/*}" --quiet >/dev/null
aws ecr get-login-password --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${AWS_REPO%%/*}" >/dev/null
az acr login --name "$ACR_NAME" >/dev/null

for repo in "$GCP_REPO" "$AWS_REPO" "$AZURE_REPO"; do
  docker tag "platform-api:$TAG" "$repo:$TAG"
  docker push --quiet "$repo:$TAG"
done

# Read each digest back from the registry itself rather than from the push
# output, so the check is against what the estates will actually pull.
GCP_DIGEST="$(gcloud artifacts docker images describe "$GCP_REPO:$TAG" \
  --format='value(image_summary.digest)')"
AWS_DIGEST="$(aws ecr describe-images --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION" \
  --repository-name platform-api --image-ids "imageTag=$TAG" \
  --query 'imageDetails[0].imageDigest' --output text)"
AZURE_DIGEST="$(az acr repository show --name "$ACR_NAME" \
  --image "platform-api:$TAG" --query digest -o tsv)"

echo
printf '%-6s %s\n' "gcp" "$GCP_DIGEST" "aws" "$AWS_DIGEST" "azure" "$AZURE_DIGEST"

if [[ "$GCP_DIGEST" == "$AWS_DIGEST" && "$AWS_DIGEST" == "$AZURE_DIGEST" ]]; then
  echo "All three registries hold the same image for tag $TAG."
else
  echo "Digests differ for tag $TAG." >&2
  exit 1
fi
