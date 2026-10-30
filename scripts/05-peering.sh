#!/usr/bin/env bash
# Requests and accepts the VPC peering connection (same account, same Region).
source "$(dirname "$0")/lib.sh"; need VPC_A VPC_B
log "Requesting peering: requester VPC A -> accepter VPC B"
PCX=$(aws ec2 create-vpc-peering-connection --vpc-id "$VPC_A" --peer-vpc-id "$VPC_B" \
      --tag-specifications "$(tags vpc-peering-connection ewb-a-b-peer)" \
      --query VpcPeeringConnection.VpcPeeringConnectionId --output text)
save PCX "$PCX"
aws ec2 wait vpc-peering-connection-exists --vpc-peering-connection-ids "$PCX"
log "Accepting $PCX (required even inside one account)"
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id "$PCX" >/dev/null
for _ in $(seq 1 20); do
  S=$(aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$PCX" --query 'VpcPeeringConnections[0].Status.Code' --output text)
  [ "$S" = active ] && break; sleep 3
done
log "Checkpoint 03:"
aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$PCX" \
  --query 'VpcPeeringConnections[0].{Id:VpcPeeringConnectionId,Name:Tags[?Key==`Name`]|[0].Value,Status:Status.Code,Requester:RequesterVpcInfo.[VpcId,CidrBlock],Accepter:AccepterVpcInfo.[VpcId,CidrBlock]}' --output json
warn "Peering is ACTIVE but traffic still fails until routes exist. Run 06-routes.sh next."
