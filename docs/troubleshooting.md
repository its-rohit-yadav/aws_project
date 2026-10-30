# Troubleshooting

Check in this order: **instance state → destination IP → subnet route table → security rule**.

| Symptom | What to inspect |
|---|---|
| Bastion SSH times out | Bastion's current public IP; your current public IP `/32` in `ewb-sg-bastion` (it changes!); public subnet association; `0.0.0.0/0` route to the **attached** IGW |
| App-A SSH fails | App-A private IP; TCP 22 from `10.10.1.10/32`; correct key, user `ec2-user`; instance running |
| App-B SSH fails | `ewb-rt-a-public` has `10.20.0.0/16 → pcx`; `ewb-rt-b-private` has the return route; App-B SSH source is the bastion's **private** IP |
| Ping fails after acceptance | Both private route tables; correct pcx and Active state; echo-request rule on the **destination** SG; actual host IPs |
| Peering creation fails | Overlapping CIDRs between the VPCs, including secondary CIDRs |
| `Permission denied (publickey)` | Wrong key pair / `IdentityFile` / username. Routing works if you got this far |
| Fails with custom ACLs | Check both directions, ICMP, and SSH return (ephemeral) ports. Lab assumes default ACLs |
| `dnf update` fails on private hosts | Expected: no NAT/internet egress. Not a peering problem |
| Script: `Missing X in state.env` | Run earlier scripts in order, or `99-cleanup.sh` then start again |
| Bastion unreachable after stop/start | Public IPv4 changed. Re-run `scripts/04-ssh-config.sh` |

## Useful CLI checks

```bash
aws ec2 describe-vpc-peering-connections --query 'VpcPeeringConnections[].[VpcPeeringConnectionId,Status.Code]'
aws ec2 describe-route-tables --filters Name=tag:Project,Values=EWB-VPC-Peering \
  --query 'RouteTables[].[Tags[?Key==`Name`]|[0].Value,Routes[].[DestinationCidrBlock,VpcPeeringConnectionId]]'
ssh -vvv -F ssh/ssh_config ewb-app-b      # see exactly where the connection stalls
```
