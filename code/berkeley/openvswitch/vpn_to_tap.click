// OpenVPN exposes a TUN interface, OVS only accepts TAP interfaces, this click instance will convert
// between the two.


tap0 :: KernelTap(1.0.0.4/24, ETHER 00:01:01:01:01:04)
vpn :: FromDevice(tun0)
vpnout :: ToDevice(tun0)

tap0 -> ipfilter :: CheckIPHeader(13)[0] -> StripToNetworkHeader -> Queue -> vpnout;
vpn -> EtherEncap(0x0800, 00:01:01:01:01:03, 00:01:01:01:01:04) -> Queue ->Unqueue -> tap0;
ipfilter[1] -> Print -> Discard;

