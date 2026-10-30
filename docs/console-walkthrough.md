# Console Walkthrough (same lab, no CLI)

Use Region **Asia Pacific (Mumbai) ap-south-1**. Add tags `Project=EWB-VPC-Peering` and `Student=<your name>` to everything. Record every resource ID in the report.

## 1. VPC A
1. VPC → **Your VPCs → Create VPC → VPC only**. Name `ewb-vpc-a`, IPv4 `10.10.0.0/16`, no IPv6, tenancy Default.
2. **Subnets → Create subnet** in VPC A: `ewb-a-public` `10.10.1.0/24` and `ewb-a-private` `10.10.2.0/24`, same AZ.
3. **Internet gateways → Create** `ewb-igw-a` → **Actions → Attach to a VPC** → `ewb-vpc-a`.
4. **Route tables → Create** `ewb-rt-a-public` (VPC A). *Subnet associations → Edit* → `ewb-a-public`. *Routes → Edit* → add `0.0.0.0/0` → `ewb-igw-a`.
5. Create `ewb-rt-a-private` (VPC A), explicitly associate `ewb-a-private`. Add **no** internet route. Keep public IPv4 auto-assign **disabled**.

**Checkpoint 01:** screenshot both associations + the public default route; private RT shows only `local`.

## 2. VPC B
Create `ewb-vpc-b` `10.20.0.0/16`, subnet `ewb-b-private` `10.20.1.0/24`, route table `ewb-rt-b-private` explicitly associated. No IGW. Auto-assign public IPv4 disabled.

## 3. Security groups
| SG (VPC) | Inbound |
|---|---|
| `ewb-sg-bastion` (A) | SSH TCP 22 ← your public IPv4 `/32` |
| `ewb-sg-app-a` (A) | SSH TCP 22 ← `10.10.1.10/32`; Custom ICMP – IPv4 *Echo request* ← `10.20.1.10/32` |
| `ewb-sg-app-b` (B) | SSH TCP 22 ← `10.10.1.10/32`; Custom ICMP – IPv4 *Echo request* ← `10.10.2.10/32` |

The IP goes in **Source**, never in **Port range**. Leave outbound default. Never use `0.0.0.0/0` for SSH/ICMP.

## 4. Instances
1. EC2 → **Key pairs → Create** `ewb-lab` (RSA, `.pem`). Store it on your laptop only.
2. Launch three instances: Amazon Linux 2023, `t3.micro` (or instructor-approved), small root disk with **delete on termination**.

| Instance | VPC / subnet | Primary private IP | Auto-assign public IP | SG |
|---|---|---|---|---|
| ewb-bastion | A / ewb-a-public | 10.10.1.10 | **Enable** | ewb-sg-bastion |
| ewb-app-a | A / ewb-a-private | 10.10.2.10 | Disable | ewb-sg-app-a |
| ewb-app-b | B / ewb-b-private | 10.20.1.10 | Disable | ewb-sg-app-b |

Set the private IP under *Network settings → Edit → Advanced network configuration*. Wait for status checks.

**Checkpoint 02:** instance IDs, private IPs, bastion public IP; App-A/B show no public IPv4.

## 5. SSH setup (on your laptop)
```bash
mv ~/Downloads/ewb-lab.pem ~/.ssh/ && chmod 400 ~/.ssh/ewb-lab.pem
```
Copy [`ssh/config.example`](../ssh/config.example) into `~/.ssh/config` and set `BASTION_PUBLIC_IP`. Then `ssh ewb-bastion`, `exit`, `ssh ewb-app-a`. Verify the host fingerprint before accepting a first-time prompt.

## 6. Baseline (before peering)
Inside App-A: `ping -c 4 10.20.1.10` → **no replies**. Save it.

## 7. Peering
VPC → **Peering connections → Create**: name `ewb-a-b-peer`, requester `ewb-vpc-a`, account *My account*, Region *This Region*, accepter `ewb-vpc-b`. Then **Actions → Accept request** (required even in one account). Wait for **Active** and record the `pcx-…` ID.

**Checkpoint 03:** screenshot name, Active status, both VPC IDs.

## 8. Routes (both sides)
| Route table | Add |
|---|---|
| `ewb-rt-a-private` | `10.20.0.0/16` → pcx |
| `ewb-rt-b-private` | `10.10.0.0/16` → pcx |
| `ewb-rt-a-public` | `10.20.0.0/16` → pcx |

**Checkpoint 04:** screenshot routes + associations for all three tables.

## 9. Validate and clean up
Follow [validation.md](validation.md), then [cleanup-and-cost.md](cleanup-and-cost.md).
