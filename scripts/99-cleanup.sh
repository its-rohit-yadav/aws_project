#!/usr/bin/env bash
# Deletes everything this lab created, in dependency order. SAVE YOUR EVIDENCE FIRST.
source "$(dirname "$0")/lib.sh"; load
read -r -p "Delete ALL lab resources in $AWS_REGION? Evidence saved? (type 'yes'): " a; [ "$a" = yes ] || die "Aborted."
try() { "$@" >/dev/null 2>&1 || warn "skipped/failed: ${*:1:4}"; }
have() { [ -n "${!1:-}" ]; }

IDS=(); for v in BASTION_ID APP_A_ID APP_B_ID; do have "$v" && IDS+=("${!v}"); done
if [ ${#IDS[@]} -gt 0 ]; then
  log "1/6 Terminating instances"; try aws ec2 terminate-instances --instance-ids "${IDS[@]}"
  aws ec2 wait instance-terminated --instance-ids "${IDS[@]}" || true
fi

log "2/6 Removing peer routes and the peering connection"
have RT_A_PRIVATE && try aws ec2 delete-route --route-table-id "$RT_A_PRIVATE" --destination-cidr-block "$VPC_B_CIDR"
have RT_B_PRIVATE && try aws ec2 delete-route --route-table-id "$RT_B_PRIVATE" --destination-cidr-block "$VPC_A_CIDR"
have RT_A_PUBLIC  && try aws ec2 delete-route --route-table-id "$RT_A_PUBLIC"  --destination-cidr-block "$VPC_B_CIDR"
have PCX && try aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$PCX"

log "3/6 Deleting security groups"
for v in SG_BASTION SG_APP_A SG_APP_B; do have "$v" && try aws ec2 delete-security-group --group-id "${!v}"; done

log "4/6 Route tables, subnets, internet gateway"
for v in ASSOC_A_PUBLIC ASSOC_A_PRIVATE ASSOC_B_PRIVATE; do have "$v" && try aws ec2 disassociate-route-table --association-id "${!v}"; done
for v in RT_A_PUBLIC RT_A_PRIVATE RT_B_PRIVATE; do have "$v" && try aws ec2 delete-route-table --route-table-id "${!v}"; done
for v in SUBNET_A_PUBLIC SUBNET_A_PRIVATE SUBNET_B_PRIVATE; do have "$v" && try aws ec2 delete-subnet --subnet-id "${!v}"; done
if have IGW_A; then try aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_A" --vpc-id "$VPC_A"; try aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_A"; fi

log "5/6 Deleting VPCs"
for v in VPC_A VPC_B; do have "$v" && try aws ec2 delete-vpc --vpc-id "${!v}"; done

log "6/6 Key pair"
try aws ec2 delete-key-pair --key-name "$KEY_NAME"
read -r -p "Also delete local key $KEY_FILE ? (y/N): " k; [ "${k:-n}" = y ] && rm -f "$KEY_FILE"
: > "$STATE"; rm -f "$ROOT/ssh/ssh_config"

log "Verification (each list below should be empty):"
F="Name=tag:Project,Values=$PROJECT_TAG"
aws ec2 describe-instances --filters "$F" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'Reservations[].Instances[].InstanceId' --output text
aws ec2 describe-volumes   --filters "$F" --query 'Volumes[].VolumeId' --output text
aws ec2 describe-vpcs      --filters "$F" --query 'Vpcs[].VpcId' --output text
aws ec2 describe-vpc-peering-connections --filters "$F" "Name=status-code,Values=active,pending-acceptance,provisioning" --query 'VpcPeeringConnections[].VpcPeeringConnectionId' --output text
aws ec2 describe-addresses --query 'Addresses[].PublicIp' --output text
warn "Save this output as cleanup evidence and check Billing later (usage reporting can lag)."
