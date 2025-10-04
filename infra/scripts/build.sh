#!/usr/bin/env bash
# IMPORTANT: run this from the project root please :)
set -e

TF_ACTION=${1:-"plan"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_FILE="sixsevenlabs_${TF_ACTION}_${TIMESTAMP}.out"

if [[ "$TF_ACTION" != "plan" && "$TF_ACTION" != "apply" && "$TF_ACTION" != "destroy" ]]; then
  echo "Invalid argument. Use 'plan', 'apply', or 'destroy'."
  exit 1
fi

echo "Building project with TF_ACTION=${TF_ACTION}"

echo "[PACKAGE] Packaging Lambdas..."
chmod +x ./infra/scripts/package_lambdas.sh
./infra/scripts/package_lambdas.sh 2>&1 | sed 's/^/    /'

echo "[TERRAFORM] Running Terraform ${TF_ACTION}..."
cd infra/terraform
terraform init 2>&1 | sed 's/^/    /'
terraform plan -out="$OUT_FILE" -var-file=".tfvars" 2>&1 | sed 's/^/    /'

if [[ "$TF_ACTION" == "apply" ]]; then
    echo ""
    echo "========================================="
    echo "🚨 MANUAL APPROVAL REQUIRED"
    echo "========================================="
    echo "You are about to APPLY the Terraform plan."
    echo ""
    read -p "Do you want to continue? (yes/no): " APPROVAL
    
    if [[ "$APPROVAL" != "yes" ]]; then
        echo "❌ Apply cancelled."
        exit 0
    fi

    echo "[TERRAFORM] >>>> Applying Terraform plan from $OUT_FILE..."
    terraform apply "$OUT_FILE" 2>&1 | sed 's/^/    /'
elif [[ "$TF_ACTION" == "destroy" ]]; then
    echo ""
    echo "========================================="
    echo "🚨 MANUAL APPROVAL REQUIRED"
    echo "========================================="
    echo "You are about to DESTROY infrastructure!"
    echo ""
    echo "Type 'destroy' to confirm:"
    read -p "> " APPROVAL
    
    if [[ "$APPROVAL" != "destroy" ]]; then
        echo "❌ Destroy cancelled."
        exit 0
    fi

    echo "[TERRAFORM] >>>> Destroying Terraform resources..."
    terraform destroy -var-file=".tfvars" 2>&1 | sed 's/^/    /'
fi

echo "Done!"