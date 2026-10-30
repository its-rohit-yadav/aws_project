#!/usr/bin/env bash
# Creates both VPCs, subnets, IGW (VPC A only) and the three route tables with explicit associations.
source "$(dirname "$0")/lib.sh"; load
[ -z "${VPC_A:-}" ] || die "state.env already has resources. Run scripts/99-cleanup.sh first."

log "Creating VPC A ($VPC_A_CIDR)"
VPC_A=$(aws ec2 create-vpc --cidr-block "$VPC_A_CIDR" --tag-specifications "$(tags vpc ewb-vpc-a)" --query Vpc.VpcId --output text)
aws ec2 wait vpc-available --vpc-ids "$VPC_A"; save VPC_A "$VPC_A"

log "Creating VPC B ($VPC_B_CIDR) - no internet gateway"
VPC_B=$(aws ec2 create-vpc --cidr-block "$VPC_B_CIDR" --tag-specifications "$(tags vpc ewb-vpc-b)" --query Vpc.VpcId --output text)
aws ec2 wait vpc-available --vpc-ids "$VPC_B"; save VPC_B "$VPC_B"

mk_subnet() { aws ec2 create-subnet --vpc-id "$1" --cidr-block "$2" --availability-zone "$AZ" \
  --tag-specifications "$(tags subnet "$3")" --query Subnet.SubnetId --output text; }

log "Creating subnets"
SUBNET_A_PUBLIC=$(mk_subnet "$VPC_A" "$SUBNET_A_PUBLIC_CIDR" ewb-a-public);   save SUBNET_A_PUBLIC "$SUBNET_A_PUBLIC"
SUBNET_A_PRIVATE=$(mk_subnet "$VPC_A" "$SUBNET_A_PRIVATE_CIDR" ewb-a-private); save SUBNET_A_PRIVATE "$SUBNET_A_PRIVATE"
SUBNET_B_PRIVATE=$(mk_subnet "$VPC_B" "$SUBNET_B_PRIVATE_CIDR" ewb-b-private); save SUBNET_B_PRIVATE "$SUBNET_B_PRIVATE"

# Keep public IPv4 auto-assign OFF on every subnet. The bastion gets its public IP at launch only.
for s in "$SUBNET_A_PUBLIC" "$SUBNET_A_PRIVATE" "$SUBNET_B_PRIVATE"; do
  aws ec2 modify-subnet-attribute --subnet-id "$s" --no-map-public-ip-on-launch
done

log "Creating and attaching internet gateway ewb-igw-a to VPC A"
IGW_A=$(aws ec2 create-internet-gateway --tag-specifications "$(tags internet-gateway ewb-igw-a)" --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_A" --vpc-id "$VPC_A"; save IGW_A "$IGW_A"

mk_rt() { aws ec2 create-route-table --vpc-id "$1" --tag-specifications "$(tags route-table "$2")" --query RouteTable.RouteTableId --output text; }

log "Creating route tables + explicit subnet associations"
RT_A_PUBLIC=$(mk_rt "$VPC_A" ewb-rt-a-public);   save RT_A_PUBLIC "$RT_A_PUBLIC"
RT_A_PRIVATE=$(mk_rt "$VPC_A" ewb-rt-a-private); save RT_A_PRIVATE "$RT_A_PRIVATE"
RT_B_PRIVATE=$(mk_rt "$VPC_B" ewb-rt-b-private); save RT_B_PRIVATE "$RT_B_PRIVATE"

save ASSOC_A_PUBLIC  "$(aws ec2 associate-route-table --route-table-id "$RT_A_PUBLIC"  --subnet-id "$SUBNET_A_PUBLIC"  --query AssociationId --output text)"
save ASSOC_A_PRIVATE "$(aws ec2 associate-route-table --route-table-id "$RT_A_PRIVATE" --subnet-id "$SUBNET_A_PRIVATE" --query AssociationId --output text)"
save ASSOC_B_PRIVATE "$(aws ec2 associate-route-table --route-table-id "$RT_B_PRIVATE" --subnet-id "$SUBNET_B_PRIVATE" --query AssociationId --output text)"

log "Adding 0.0.0.0/0 -> IGW to the PUBLIC route table only"
aws ec2 create-route --route-table-id "$RT_A_PUBLIC" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_A" >/dev/null

log "Checkpoint 01 - private route tables must show only the local route:"
aws ec2 describe-route-tables --route-table-ids "$RT_A_PUBLIC" "$RT_A_PRIVATE" "$RT_B_PRIVATE" \
  --query 'RouteTables[].{Table:Tags[?Key==`Name`]|[0].Value,Associations:Associations[].SubnetId,Routes:Routes[].[DestinationCidrBlock,GatewayId]}' --output json
