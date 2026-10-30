# Cost Planning and Cleanup

## Before launch
Chargeable items (check current pricing and your credits): 3 × EC2 `t3.micro`, 3 × 8 GiB EBS gp3, and the bastion's **public IPv4** address. This lab uses **no NAT gateway** (that would be a significant hourly cost). Same-AZ placement keeps data-transfer charges negligible for ping tests; note traffic between VPCs in different AZs may be billed.

Do the lab in one sitting, then clean up the same day.

## Cleanup (save evidence first!)

Automatic:

```bash
scripts/99-cleanup.sh
```

Manual order (matches the script):

1. **Terminate** `ewb-bastion`, `ewb-app-a`, `ewb-app-b`. Confirm their EBS volumes are gone; delete leftover lab volumes/snapshots. Release any Elastic IP you created.
2. **Delete the peer routes** (3 of them) and `ewb-a-b-peer`.
3. **Delete security groups** (after instance network interfaces disappear).
4. **Disassociate and delete route tables**, then **delete subnets**.
5. **Detach and delete** `ewb-igw-a`.
6. **Delete both VPCs**.
7. **Delete key pair** `ewb-lab` and the local `.pem` if no longer needed.

## Verify the account is clear
Filter by tag `Project=EWB-VPC-Peering` in the lab Region and check: EC2 instances, EBS volumes, public IPv4/Elastic IPs, VPCs, peering connections. Review **Billing** later (usage reporting can lag). Capture screenshots/CLI output as cleanup evidence.

## Common deletion errors
| Error | Fix |
|---|---|
| `DependencyViolation` on security group | Instances / ENIs still exist; wait for termination |
| `DependencyViolation` on subnet | ENIs still attached; terminate instances first |
| IGW won't detach | Public IP still mapped; terminate bastion first |
| VPC won't delete | Subnets, IGW, non-main route tables or SGs remain |
