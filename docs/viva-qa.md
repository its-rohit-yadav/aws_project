# Viva: Be Ready to Explain

**1. Why is the return route needed?**
Routing is directional. App-A's route sends requests to VPC B via the peering connection, but App-B must also know how to send replies to `10.10.0.0/16`. VPC B has no other path to VPC A, so without `10.10.0.0/16 → pcx` in `ewb-rt-b-private` the replies are dropped and ping/SSH time out. (Security groups are stateful, but they don't create routes.)

**2. Why is the App-B SSH source the bastion's private IP?**
`ProxyJump` makes the bastion open its own TCP connection to App-B. Over the peering connection App-B sees the bastion's private address `10.10.1.10`, not your laptop's public IP. So `ewb-sg-app-b` allows TCP 22 from `10.10.1.10/32`, and nothing broader.

**3. Why does Active peering not guarantee a successful ping?**
Active only means the link exists. Packets still need (a) routes in both subnets' route tables, (b) security group rules on the destination, and (c) NACLs that permit the traffic. Missing any one of them blocks traffic. The controlled failure demonstrates this: peering and routes stay intact, yet removing the ICMP rule stops replies.

**4. Can VPC B use VPC A's internet gateway over peering?**
No. VPC peering doesn't support edge-to-edge routing, so VPC B can't use A's IGW, NAT or VPN through the peering connection. VPC B has no internet access in this design, and routing `0.0.0.0/0` through the peer won't change that.

## Bonus questions

- **Why must CIDRs not overlap?** Route tables couldn't decide between the local range and the peer range; AWS rejects the peering request.
- **Is peering transitive?** No. A–B and A–C does not create B–C; you'd need a third peering or a Transit Gateway.
- **Why does the public subnet also need the peering route?** The bastion originates the connection to App-B, and its subnet needs a route to `10.20.0.0/16`. The more specific route wins over `0.0.0.0/0`.
- **Why `/32` sources?** Least privilege: only named lab hosts may connect.
