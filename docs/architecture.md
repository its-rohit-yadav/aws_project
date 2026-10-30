# Architecture and Design Decisions

## Components

| Layer | Component | Reason |
|---|---|---|
| Network | VPC A `10.10.0.0/16`, VPC B `10.20.0.0/16` | Non-overlapping ranges, required for peering |
| Edge | One internet gateway on VPC A only | Single controlled entry point; VPC B has none |
| Subnets | A-public, A-private, B-private (all /24, same AZ) | Public only where internet entry is needed |
| Routing | 3 custom route tables, explicit associations | Nothing depends on the VPC main route table |
| Link | Peering `ewb-a-b-peer` (requester A, accepter B) | Private, direct VPC-to-VPC connectivity |
| Access | Bastion + SSH ProxyJump | Admin without public IPs or copied keys on servers |
| Firewall | 3 security groups with `/32` sources | Least privilege |

## Traffic flows

**1. Admin to bastion:** laptop → internet → IGW → public subnet (`0.0.0.0/0 → igw`) → bastion. Allowed by `ewb-sg-bastion` (TCP 22 from your `/32`).

**2. Admin to App-A:** laptop → bastion → (VPC A `local` route) → App-A. The bastion opens a *second* SSH connection; the laptop's key never leaves the laptop. Allowed by `ewb-sg-app-a` (TCP 22 from `10.10.1.10/32`).

**3. Admin to App-B:** laptop → bastion → `10.20.0.0/16 → pcx` in `ewb-rt-a-public` → App-B. Reply: App-B → `10.10.0.0/16 → pcx` in `ewb-rt-b-private` → bastion. Allowed by `ewb-sg-app-b` (TCP 22 from the bastion's **private** IP, because that is the source address App-B sees).

**4. App-A to App-B ping (forward):** `ewb-rt-a-private` `10.20.0.0/16 → pcx` → peering → App-B. Destination SG must allow ICMP echo request from `10.10.2.10/32`.

**5. App-B reply / App-B to App-A (return):** `ewb-rt-b-private` `10.10.0.0/16 → pcx` → App-A. For App-B-initiated pings, `ewb-sg-app-a` must allow echo request from `10.20.1.10/32`.

## Why each route exists

| Route | Why it is needed | What breaks without it |
|---|---|---|
| `0.0.0.0/0 → igw` (public RT) | Gives the public subnet internet entry | Bastion unreachable from laptop |
| `10.20.0.0/16 → pcx` (a-private) | App-A must know VPC B is reached via peering | Forward ping fails (no route) |
| `10.10.0.0/16 → pcx` (b-private) | Return path; B has no other way to reach A | Requests arrive, replies are lost → ping/SSH time out |
| `10.20.0.0/16 → pcx` (a-public) | Bastion's own subnet must reach VPC B for ProxyJump | `ssh ewb-app-b` hangs while App-A ping works |
| Private RTs: **no** `0.0.0.0/0` | Keeps App-A / App-B off the internet | (n/a, intentional) |

The `10.20.0.0/16` peering route is **more specific** than `0.0.0.0/0`, so the longest-prefix match sends VPC B traffic through the peering connection, not the IGW.

## Why each security group rule exists

| Rule | Why |
|---|---|
| bastion: TCP 22 from my `/32` | Only the admin's current IP can reach the only public host |
| app-a: TCP 22 from `10.10.1.10/32` | Only the bastion can administer App-A |
| app-b: TCP 22 from `10.10.1.10/32` | Only the bastion can administer App-B (the peering preserves the bastion's private source IP) |
| app-a: ICMP echo from `10.20.1.10/32` | Permits App-B → App-A tests only |
| app-b: ICMP echo from `10.10.2.10/32` | Permits App-A → App-B tests only; removed in the controlled failure |

Security groups are **stateful**, so no inbound rule is needed for replies. Network ACLs are left at the default allow-all (custom ACLs would also need return/ephemeral-port rules).


