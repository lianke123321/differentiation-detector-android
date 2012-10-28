// We don't want to hook eth0 directly to OVS -- we want Linux to do the NAT for us.
// So, we have iptables connect tun1 directly to eth0 with a MASQUERADE option set.
// OVS just sees tap0 as its egress interface, and all traffic going to tap0 is stripped
// of its Ethernet header and sent directly to tun1.
//
// Note that "tap0" and "tun1" aren't the names on the outside necessarily -- but the
// Ethernet address 00:01:01:01:01:01 is going to be the same.


tap0 :: KernelTap(1.0.0.2/24, ETHER 00:01:01:01:01:01)
tun1 :: KernelTun(1.0.0.3/24) //PSUEDO Ethernet address 00:01:01:01:01:02

tap0 -> ipfilter :: CheckIPHeader(13)[0] -> StripToNetworkHeader -> Queue -> Unqueue -> tun1;
tun1 -> EtherEncap(0x0800, 00:01:01:01:01:02, 00:01:01:01:01:01) -> Queue ->Unqueue -> tap0;
ipfilter[1] -> Print -> Discard;

