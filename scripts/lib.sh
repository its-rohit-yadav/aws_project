#!/usr/bin/env bash
# Shared helpers. Sourced by every script.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/config.env"
export AWS_DEFAULT_REGION="$AWS_REGION"
STATE="$ROOT/state.env"; touch "$STATE"

log()  { printf '\033[1;34m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

save() { grep -v "^$1=" "$STATE" > "$STATE.tmp" || true; echo "$1=$2" >> "$STATE.tmp"; mv "$STATE.tmp" "$STATE"; }
load() { set +u; source "$STATE"; set -u; }
need() { load; for v in "$@"; do [ -n "${!v:-}" ] || die "Missing $v in state.env - run the earlier scripts first."; done; }

# tags <resource-type> <Name>  ->  tag-specification string
tags() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_NAME}]"; }

# The one ICMP rule used in the controlled-failure test (App-B accepts echo request from App-A)
icmp_rule_b() { echo "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=${APP_A_IP}/32,Description=echo-from-app-a}]"; }
