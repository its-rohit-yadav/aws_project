#!/usr/bin/env bash
# Creates the 3 security groups with least-privilege inbound rules.
source "$(dirname "$0")/lib.sh"; need VPC_A VPC_B

MY_IP="${MY_IP:-$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')}"
[[ "$MY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Could not detect public IPv4. Run: MY_IP=x.x.x.x $0"
log "Your public IPv4: $MY_IP (bastion SSH limited to $MY_IP/32)"; save MY_IP "$MY_IP"

mk_sg() { aws ec2 create-security-group --group-name "$1" --description "$2" --vpc-id "$3" \
  --tag-specifications "$(tags security-group "$1")" --query GroupId --output text; }

SG_BASTION=$(mk_sg ewb-sg-bastion "EWB bastion SSH from admin laptop" "$VPC_A");       save SG_BASTION "$SG_BASTION"
SG_APP_A=$(mk_sg ewb-sg-app-a "EWB App-A SSH from bastion, ICMP from App-B" "$VPC_A"); save SG_APP_A "$SG_APP_A"
SG_APP_B=$(mk_sg ewb-sg-app-b "EWB App-B SSH from bastion, ICMP from App-A" "$VPC_B"); save SG_APP_B "$SG_APP_B"

ssh_rule()  { echo "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$1,Description=$2}]"; }
icmp_rule() { echo "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=$1,Description=$2}]"; }  # type 8 / code 0 = echo request

aws ec2 authorize-security-group-ingress --group-id "$SG_BASTION" --ip-permissions "$(ssh_rule  "$MY_IP/32"      admin-laptop)"    >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_A"   --ip-permissions "$(ssh_rule  "$BASTION_IP/32" from-bastion)"    >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_A"   --ip-permissions "$(icmp_rule "$APP_B_IP/32"   echo-from-app-b)" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_B"   --ip-permissions "$(ssh_rule  "$BASTION_IP/32" from-bastion)"    >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_B"   --ip-permissions "$(icmp_rule "$APP_A_IP/32"   echo-from-app-a)" >/dev/null

log "Inbound rules created:"
aws ec2 describe-security-groups --group-ids "$SG_BASTION" "$SG_APP_A" "$SG_APP_B" \
  --query 'SecurityGroups[].{SG:GroupName,Inbound:IpPermissions[].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]}' --output json
