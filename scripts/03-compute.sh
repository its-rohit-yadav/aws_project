#!/usr/bin/env bash
# Creates the key pair (private key stays on your laptop) and launches bastion, App-A, App-B.
source "$(dirname "$0")/lib.sh"; need SUBNET_A_PUBLIC SUBNET_A_PRIVATE SUBNET_B_PRIVATE SG_BASTION SG_APP_A SG_APP_B

if [ -f "$KEY_FILE" ]; then warn "$KEY_FILE exists - reusing it (key pair '$KEY_NAME' must exist in $AWS_REGION)"
else
  log "Creating key pair $KEY_NAME -> $KEY_FILE"
  mkdir -p "$(dirname "$KEY_FILE")"
  aws ec2 create-key-pair --key-name "$KEY_NAME" --key-type rsa --tag-specifications "$(tags key-pair "$KEY_NAME")" \
    --query KeyMaterial --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
fi

AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
      --query Parameter.Value --output text)
log "Amazon Linux 2023 AMI: $AMI"; save AMI "$AMI"

launch() { # name subnet private-ip sg assign-public(true|false)
  aws ec2 run-instances --image-id "$AMI" --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" \
    --network-interfaces "DeviceIndex=0,SubnetId=$2,PrivateIpAddress=$3,Groups=$4,AssociatePublicIpAddress=$5" \
    --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=8,VolumeType=gp3,DeleteOnTermination=true}' \
    --metadata-options HttpTokens=required,HttpEndpoint=enabled \
    --tag-specifications "$(tags instance "$1")" "$(tags volume "$1")" \
    --query 'Instances[0].InstanceId' --output text
}

log "Launching instances"
save BASTION_ID "$(launch ewb-bastion "$SUBNET_A_PUBLIC"  "$BASTION_IP" "$SG_BASTION" true)"
save APP_A_ID   "$(launch ewb-app-a   "$SUBNET_A_PRIVATE" "$APP_A_IP"   "$SG_APP_A"   false)"
save APP_B_ID   "$(launch ewb-app-b   "$SUBNET_B_PRIVATE" "$APP_B_IP"   "$SG_APP_B"   false)"
load
log "Waiting for status checks to pass (a few minutes)..."
aws ec2 wait instance-status-ok --instance-ids "$BASTION_ID" "$APP_A_ID" "$APP_B_ID"

save BASTION_PUBLIC_IP "$(aws ec2 describe-instances --instance-ids "$BASTION_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
log "Checkpoint 02 (App-A and App-B PublicIp must be None):"
aws ec2 describe-instances --instance-ids "$BASTION_ID" "$APP_A_ID" "$APP_B_ID" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,Id:InstanceId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress}' --output table
