# Validation Guide

> Expected results are **acceptance criteria**, not completed results. Record your own output. Every claim in your report should be backed by a log or screenshot labelled with host, test and result.

## Running the tests

```bash
scripts/tests.sh baseline          # before peering & routes
scripts/tests.sh forward           # App-A -> App-B
scripts/tests.sh reverse           # App-B -> App-A
scripts/tests.sh ssh-b             # laptop -> bastion -> App-B
scripts/tests.sh isolation         # no public IPv4 on App-A / App-B
scripts/tests.sh routes            # route table dump
scripts/tests.sh failure           # controlled failure + recovery
```

Manual equivalent inside each host:

```bash
hostname
hostname -I
ping -c 4 PEER_PRIVATE_IP
```

## Test table

| Test | Where | Expected |
|---|---|---|
| 01 Baseline | App-A, before peering: `ping -c 4 10.20.1.10` | No replies, 100% packet loss |
| 02 Forward | App-A, after routes: `ping -c 4 10.20.1.10` | 4 received, 0% loss |
| 03 Reverse | App-B, after routes: `ping -c 4 10.10.2.10` | 4 received, 0% loss |
| 04 Private SSH | Laptop: `ssh ewb-app-b` | Shell on App-B through the bastion |
| 05 Isolation | EC2 details | No public IPv4 on App-A and App-B |

## Optional diagnostic: "Active but no routes"

After `05-peering.sh` but **before** `06-routes.sh`, run `scripts/tests.sh baseline` again. It should still fail. This proves Active peering alone does not provide reachability.

## Controlled failure

1. Remove **only** the ICMP echo-request rule (type 8 / code 0) from `10.10.2.10/32` on `ewb-sg-app-b`. Keep SSH.
2. From App-A: `ping -c 4 10.20.1.10` → replies stop (100% loss).
3. Restore the **exact** rule → ping again → replies resume.

`scripts/tests.sh failure` does all three steps and saves both logs.

**Explanation to write:** routes were still correct and peering still Active, so the packet reached App-B's network interface but was dropped by the security group. This isolates the failure to the security layer, not routing.

## Evidence checklist

- [ ] Checkpoints 01–04 screenshots
- [ ] Logs: baseline fail, forward OK, reverse OK, SSH to App-B, failure, recovery
- [ ] Isolation output/screenshot (no public IPv4 on private hosts)
- [ ] Security group inbound rules for all three SGs
- [ ] Cleanup verification output

If the first ping loses a packet while the host finishes booting, wait and repeat the four-packet test. A first-time SSH host-key prompt is normal.
