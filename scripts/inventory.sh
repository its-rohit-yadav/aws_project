#!/usr/bin/env bash
# Prints the resource inventory as a Markdown table (paste into your report).
source "$(dirname "$0")/lib.sh"; load
printf '| Resource | ID | CIDR / IP |\n|---|---|---|\n'
printf '| ewb-vpc-a | %s | %s |\n| ewb-vpc-b | %s | %s |\n' "$VPC_A" "$VPC_A_CIDR" "$VPC_B" "$VPC_B_CIDR"
printf '| ewb-a-public | %s | %s |\n| ewb-a-private | %s | %s |\n| ewb-b-private | %s | %s |\n' "$SUBNET_A_PUBLIC" "$SUBNET_A_PUBLIC_CIDR" "$SUBNET_A_PRIVATE" "$SUBNET_A_PRIVATE_CIDR" "$SUBNET_B_PRIVATE" "$SUBNET_B_PRIVATE_CIDR"
printf '| ewb-igw-a | %s | - |\n| ewb-rt-a-public | %s | - |\n| ewb-rt-a-private | %s | - |\n| ewb-rt-b-private | %s | - |\n' "$IGW_A" "$RT_A_PUBLIC" "$RT_A_PRIVATE" "$RT_B_PRIVATE"
printf '| ewb-sg-bastion | %s | - |\n| ewb-sg-app-a | %s | - |\n| ewb-sg-app-b | %s | - |\n| ewb-a-b-peer | %s | - |\n' "$SG_BASTION" "$SG_APP_A" "$SG_APP_B" "${PCX:-n/a}"
printf '| ewb-bastion | %s | %s + public %s |\n| ewb-app-a | %s | %s |\n| ewb-app-b | %s | %s |\n' "$BASTION_ID" "$BASTION_IP" "${BASTION_PUBLIC_IP:-?}" "$APP_A_ID" "$APP_A_IP" "$APP_B_ID" "$APP_B_IP"
