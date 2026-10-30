# AWS VPC Peering: Project Report

| | |
|---|---|
| **Name** | |
| **Batch** | |
| **Project** | VPC Peering: Connect two VPCs, prove private connectivity |
| **Region** | ap-south-1 (Mumbai) |
| **Completion date** | |

## 1. Architecture and inventory
_Insert the diagram from the README (export from GitHub or draw your own), then the output of `scripts/inventory.sh`._

## 2. CIDR plan and reasoning
_Explain why 10.10.0.0/16 and 10.20.0.0/16 don't overlap and why each /24 sits inside its own VPC range._

## 3. Subnets and route tables (Checkpoints 01 and 04)
_Screenshots of subnet CIDRs and all three route tables with their subnet associations._

## 4. Peering connection (Checkpoint 03)
_Screenshot: name, Active status, both VPC IDs. pcx ID: ________

## 5. Security groups
_Screenshot / table of inbound rules for ewb-sg-bastion, ewb-sg-app-a, ewb-sg-app-b._

## 6. Instances (Checkpoint 02)
_IDs, private IPs, bastion public IP; confirm App-A / App-B have no public IPv4._

## 7. Test evidence (label host, test and result)
| Test | Host | Result | Evidence |
|---|---|---|---|
| 01 Baseline (before peering) | App-A | | |
| 02 Forward ping | App-A | | |
| 03 Reverse ping | App-B | | |
| 04 Private SSH to App-B via bastion | Laptop | | |
| 05 Isolation (no public IPv4) | Console | | |

## 8. Forward path and return path
_In your own words: how a packet gets from App-A to App-B and how the reply returns. Mention both route tables._

## 9. Controlled failure and recovery
_Rule removed → ping result → rule restored → ping result. Explain why routing was not the cause._

## 10. Cleanup evidence
_Output/screenshots proving instances, volumes, public IPs, peering and VPCs are gone._

## 11. What I learned
_Short note (5–8 lines)._

---
*Do not include private keys, passwords or access tokens.*
Export as **YourName_EWB_VPC_Peering.pdf**.
