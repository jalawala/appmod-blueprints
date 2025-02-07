#!/bin/bash
set -e -o pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
# source ${REPO_ROOT}/setups/utils.sh

echo -e "${GREEN}Installing with the following options: ${NC}"
echo -e "${GREEN}----------------------------------------------------${NC}"
echo -e "${PURPLE}\nTargets:${NC}"
echo "AWS profile (if set): ${AWS_PROFILE}"
echo "AWS account number: $(aws sts get-caller-identity --query "Account" --output text)"

# The rest of the steps are defined as a Terraform module. Parse the config to JSON and use it as the Terraform variable file. This is done because JSON doesn't allow you to easily place comments.
cd "${REPO_ROOT}/platform/infra/terraform/mgmt/terraform/mgmt-cluster"
terraform init -upgrade
terraform apply -auto-approve

aws eks --region us-west-2 update-kubeconfig --name modern-engineering

#kubectl apply -f ./karpenter.yaml # This is responsible for installing Karpenter to the management cluster. Commenting it out since EKS Auto should cover it.
kubectl apply -f ./auto-mode.yaml

# Wait until custom node pool is ready (ensures new nodes are provisioned before scaling down default)
#echo "Waiting for custom node pool to become ready..."
#until kubectl get nodes | grep "Ready"; do
#  echo "Waiting for nodes to be ready..."
#  sleep 10
#done

# Scale down the default 'general-purpose' node pool to 0
#echo "Scaling down the default general-purpose node pool..."
#eksctl scale nodegroup --cluster modern-engineering --name general-purpose --nodes=0

echo "DONE ELI."

#export GITHUB_URL=$(yq '.repo_url' ${REPO_ROOT}/platform/infra/terraform/mgmt/setups/config.yaml)

# Set up ArgoCD. We will use ArgoCD to install all components.
#cd "${REPO_ROOT}/platform/infra/terraform/mgmt/setups/argocd/"
#./install.sh
#cd -

# The rest of the steps are defined as a Terraform module. Parse the config to JSON and use it as the Terraform variable file. This is done because JSON doesn't allow you to easily place comments.
#cd "${REPO_ROOT}/platform/infra/terraform/mgmt/terraform/mgmt-cluster/day2-ops"
#pwd
#yq -o json '.'  "${REPO_ROOT}/platform/infra/terraform/mgmt/setups/config.yaml" > ${REPO_ROOT}/platform/infra/terraform/mgmt/terraform/mgmt-cluster/day2-ops/terraform.tfvars.json

#terraform init -upgrade
#terraform apply -auto-approve
