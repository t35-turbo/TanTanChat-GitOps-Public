#!/bin/bash

# T3 Cloneathon Deployment Setup Script
# This script helps you configure the GitOps repository for deployment

set -e

echo "🚀 T3 Cloneathon GitOps Setup"
echo "==============================="

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ Please edit .env file with your configuration values"
    echo "📖 Then run this script again to apply the configuration"
    exit 0
fi

# Source the .env file
source .env

echo "🔧 Applying configuration..."

# Validate required variables
required_vars=("GITOPS_REPO_URL" "DOMAIN" "POSTGRES_PASSWORD" "BETTER_AUTH_SECRET" "GITHUB_USERNAME" "GITHUB_TOKEN" "BACKEND_IMAGE" "FRONTEND_IMAGE")

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: $var is not set in .env file"
        exit 1
    fi
done

echo "✅ All required variables are set"

# Function to base64 encode
base64_encode() {
    echo -n "$1" | base64
}

# Update ArgoCD application
echo "📝 Updating ArgoCD application..."
sed -i.bak "s|repoURL: https://github.com/YOUR_USERNAME/YOUR_GITOPS_REPO.git|repoURL: $GITOPS_REPO_URL|g" argocd/application.yaml

# Validate kustomization
echo "🔍 Validating kustomization..."
if ! kubectl kustomize manifests/ > /dev/null 2>&1; then
    echo "⚠️  Warning: Kustomization validation failed. Please check your manifests."
    echo "   You can run 'kubectl kustomize manifests/' to see the specific errors."
    echo "   Continuing with setup, but you may need to fix kustomization issues."
else
    echo "✅ Kustomization validation passed"
fi

# Update secrets
echo "🔐 Updating secrets..."
sed -i.bak "s|POSTGRES_PASSWORD: YOUR_POSTGRES_PASSWORD_BASE64|POSTGRES_PASSWORD: $(base64_encode "$POSTGRES_PASSWORD")|g" manifests/secret/secret.yaml
sed -i.bak "s|BETTER_AUTH_SECRET: YOUR_BETTER_AUTH_SECRET_BASE64|BETTER_AUTH_SECRET: $(base64_encode "$BETTER_AUTH_SECRET")|g" manifests/secret/secret.yaml

if [ -n "$REDIS_PASSWORD" ]; then
    sed -i.bak "s|REDIS_PASSWORD: YOUR_REDIS_PASSWORD_BASE64|REDIS_PASSWORD: $(base64_encode "$REDIS_PASSWORD")|g" manifests/secret/secret.yaml
fi

if [ -n "$DISCORD_CLIENT_ID" ]; then
    sed -i.bak "s|DISCORD_CLIENT_ID: YOUR_DISCORD_CLIENT_ID_BASE64|DISCORD_CLIENT_ID: $(base64_encode "$DISCORD_CLIENT_ID")|g" manifests/secret/secret.yaml
fi

if [ -n "$DISCORD_CLIENT_SECRET" ]; then
    sed -i.bak "s|DISCORD_CLIENT_SECRET: YOUR_DISCORD_CLIENT_SECRET_BASE64|DISCORD_CLIENT_SECRET: $(base64_encode "$DISCORD_CLIENT_SECRET")|g" manifests/secret/secret.yaml
fi

# Update image pull secret
echo "🐳 Updating image pull secret..."
sed -i.bak "s|YOUR_GITHUB_USERNAME|$GITHUB_USERNAME|g" manifests/secret/image-pull-secret.yaml
sed -i.bak "s|YOUR_GITHUB_TOKEN|$GITHUB_TOKEN|g" manifests/secret/image-pull-secret.yaml

# Update container images
echo "📦 Updating container images..."
sed -i.bak "s|ghcr.io/YOUR_USERNAME/t3-cloneathon/backend:latest|$BACKEND_IMAGE|g" manifests/backend/deployment.yaml
sed -i.bak "s|ghcr.io/YOUR_USERNAME/t3-cloneathon/frontend:latest|$FRONTEND_IMAGE|g" manifests/frontend/deployment.yaml

# Update domain references
echo "🌐 Updating domain references..."
sed -i.bak "s|your-domain.com|$DOMAIN|g" manifests/configmap/configmap.yaml
sed -i.bak "s|your-domain.com|$DOMAIN|g" manifests/backend/deployment.yaml
sed -i.bak "s|your-domain.com|$DOMAIN|g" manifests/ingress/ingress.yaml

# Clean up backup files
echo "🧹 Cleaning up backup files..."
find . -name "*.bak" -delete

echo ""
echo "✅ Configuration complete!"
echo ""
echo "Next steps:"
echo "1. Commit and push your changes to your GitOps repository"
echo "2. Apply the ArgoCD application: kubectl apply -f argocd/application.yaml"
echo "3. Sync the application in ArgoCD UI or CLI"
echo ""
echo "🎉 Your T3 Cloneathon application is ready to deploy!"
