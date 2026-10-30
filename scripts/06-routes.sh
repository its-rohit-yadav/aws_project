#!/usr/bin/env bash
# Adds peering routes on BOTH sides (+ public subnet, because the bastion's ProxyJump connects to App-B).
source "$(dirname "$0")/lib.sh"; need PCX RT_A_PRIVATE RT_B_PRIVATE RT_A_PUBLIC
log "ewb-rt-a-private : $VPC_B_CIDR -> $PCX  (App-A to VPC B)"
aws ec2 create-route --route-table-id "$RT_A_PRIVATE" --destination-cidr-block "$VPC_B_CIDR" --vpc-peering-connection-id "$PCX" >/dev/null
log "ewb-rt-b-private : $VPC_A_CIDR -> $PCX  (return path to VPC A)"
aws ec2 create-route --route-table-id "$RT_B_PRIVATE" --destination-cidr-block "$VPC_A_CIDR" --vpc-peering-connection-id "$PCX" >/dev/null
log "ewb-rt-a-public  : $VPC_B_CIDR -> $PCX  (bastion SSH to App-B)"
aws ec2 create-route --route-table-id "$RT_A_PUBLIC"  --destination-cidr-block "$VPC_B_CIDR" --vpc-peering-connection-id "$PCX" >/dev/null
log "Checkpoint 04:"
aws ec2 describe-route-tables --route-table-ids "$RT_A_PUBLIC" "$RT_A_PRIVATE" "$RT_B_PRIVATE" \
  --query 'RouteTables[].{Table:Tags[?Key==`Name`]|[0].Value,Associations:Associations[].SubnetId,Routes:Routes[].[DestinationCidrBlock,GatewayId||VpcPeeringConnectionId,State]}' --output json
