#!/usr/bin/env bash
# Runs verification tests from your laptop and saves REAL output into evidence/logs/.
# Usage: scripts/tests.sh baseline|forward|reverse|ssh-b|isolation|routes|failure|all-after-routes
source "$(dirname "$0")/lib.sh"; need APP_A_ID APP_B_ID
SSHF=(ssh -F "$ROOT/ssh/ssh_config" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
LOGDIR="$ROOT/evidence/logs"; mkdir -p "$LOGDIR"

run() { # run <label> <command...>  -> prints, saves with timestamp, records exit code
  local label=$1; shift; local f; f="$LOGDIR/$(date +%Y%m%d-%H%M%S)-$label.log"
  { echo "# test: $label"; echo "# utc: $(date -u +%FT%TZ)"; echo "# cmd: $*"; "$@" || echo "# exit code: $?"; } 2>&1 | tee "$f" || true
  echo; }

ping_from() { run "$1" "${SSHF[@]}" "$2" "echo host=\$(hostname) ip=\$(hostname -I); ping -c 4 -W 2 $3"; }

case "${1:-}" in
  baseline)  ping_from 01-baseline-app-a-to-app-b ewb-app-a "$APP_B_IP" ;;  # BEFORE peering/routes: expect 100% loss
  forward)   ping_from 02-forward-app-a-to-app-b  ewb-app-a "$APP_B_IP" ;;  # expect 0% loss
  reverse)   ping_from 03-reverse-app-b-to-app-a  ewb-app-b "$APP_A_IP" ;;  # expect 0% loss
  ssh-b)     run 04-private-ssh-app-b "${SSHF[@]}" ewb-app-b 'echo "Connected to $(hostname) as $(whoami)"; hostname -I' ;;
  isolation) run 05-isolation aws ec2 describe-instances --instance-ids "$APP_A_ID" "$APP_B_ID" \
               --query 'Reservations[].Instances[].{Id:InstanceId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress}' --output table ;;
  routes)    run 06-routes aws ec2 describe-route-tables --route-table-ids "$RT_A_PUBLIC" "$RT_A_PRIVATE" "$RT_B_PRIVATE" \
               --query 'RouteTables[].{Table:Tags[?Key==`Name`]|[0].Value,Routes:Routes[].[DestinationCidrBlock,GatewayId||VpcPeeringConnectionId]}' --output json ;;
  failure)
    log "Controlled failure: removing ONLY the ICMP echo rule on ewb-sg-app-b (SSH rule stays)"
    aws ec2 revoke-security-group-ingress --group-id "$SG_APP_B" --ip-permissions "$(icmp_rule_b)" >/dev/null
    sleep 5; ping_from 07-failure-icmp-rule-removed ewb-app-a "$APP_B_IP"          # expect 100% loss
    log "Restoring the exact rule"
    aws ec2 authorize-security-group-ingress --group-id "$SG_APP_B" --ip-permissions "$(icmp_rule_b)" >/dev/null
    sleep 5; ping_from 08-recovery-icmp-rule-restored ewb-app-a "$APP_B_IP" ;;     # expect 0% loss
  all-after-routes) "$0" forward; "$0" reverse; "$0" ssh-b; "$0" isolation; "$0" routes ;;
  *) die "usage: $0 baseline|forward|reverse|ssh-b|isolation|routes|failure|all-after-routes" ;;
esac
