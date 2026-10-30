#!/usr/bin/env bash
# Generates ssh/ssh_config (git-ignored) so ~/.ssh/config never has to be edited.
source "$(dirname "$0")/lib.sh"; need BASTION_PUBLIC_IP
OUT="$ROOT/ssh/ssh_config"
cat > "$OUT" <<CFG
Host ewb-bastion
    HostName $BASTION_PUBLIC_IP
    User ec2-user
    IdentityFile $KEY_FILE
    IdentitiesOnly yes

Host ewb-app-a
    HostName $APP_A_IP
    User ec2-user
    IdentityFile $KEY_FILE
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName $APP_B_IP
    User ec2-user
    IdentityFile $KEY_FILE
    IdentitiesOnly yes
    ProxyJump ewb-bastion
CFG
log "Wrote $OUT"
echo "Try:  ssh -F ssh/ssh_config ewb-bastion   then   ssh -F ssh/ssh_config ewb-app-a"
echo "If the bastion is stopped/started its public IP changes - re-run this script."
