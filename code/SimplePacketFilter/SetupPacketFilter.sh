setup()
{
    ./SimplePacketFilter &
    echo "Sleeping for the device to come up"
    sleep 5 
    # Disable the proxy arp
    echo "1" > /proc/sys/net/ipv4/conf/tun0/proxy_arp

    # Disable reverse path filtering TODO:: Need to find the minimum rules to get this working
    echo "0" > /proc/sys/net/ipv4/conf/tun0/rp_filter
    echo "0" > /proc/sys/net/ipv4/conf/all/rp_filter
    echo "0" > /proc/sys/net/ipv4/conf/eth0/rp_filter
    echo "0" > /proc/sys/net/ipv4/conf/default/rp_filter

    # Disable all forms of offloading to ensure packets larger than 1.5K are not received 
    # We do not want to fragment packets in the tun device and compute checksums for received packets 
    # in the tun device
    echo "Disable all forms of offloading"
    ethtool -K eth0 tx off
    ethtool -K tun0 tx off
    ethtool -K eth0 rx off
    ethtool -K eth0 tso off
    ethtool -K eth0 ufo off
    ethtool -K eth0 gso off
    ethtool -K eth0 gro off
    ethtool -K tun0 gro off
    ethtool -K eth0 lro off
    ethtool -K tun0 lro off

    # The forward path 
    ip rule add from 192.168.0.0/24 to all lookup fwdpath prio 1000
    # Depart 
    ip rule add from 192.168.1.0/24 to all lookup depart prio 1001
    # Reverse path
    ip rule add from all to 192.168.1.0/24 lookup revpath prio 1002
    # Special rule for reverse path
    ip rule add from 128.208.4.0/24 to 192.168.1.0/24 lookup revpath prio 1003 # Specific to DN # Specific to DNS
    # When to leave from the network
    ip rule add from all to 192.168.0.0/24 lookup depart prio 1004
    ip rule add from 128.208.4.0/24 to all lookup depart prio 1005

    # The routing entries for the fwd path
    ip route add default via 192.168.0.1 dev tun0 table fwdpath
    ip route add 192.168.0.0/24 dev tun0 table fwdpath

    # The routing entries for the departing packets
    ip route add default via 128.208.4.100 dev eth0 table depart
    ip route add 128.208.4.0/24 dev eth0 table depart

    # The routing entries for the reverse path packets
    ip route add default via 192.168.0.1 dev tun0 table revpath
    ip route add 192.168.1.0/24 dev tun0 table revpath

    # Enable forwarding between the tun+ devices and the eth0 device
    iptables -A FORWARD -i tun+ -o eth0 -j ACCEPT
    iptables -A FORWARD -i eth0 -o tun+ -j ACCEPT

    # Enable the NAT
    iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth0 -j MASQUERADE
    # Reduce the MSS to support the IPsec headers in the response.  We do not want to fragment on this machine. 
    iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o eth0  -j TCPMSS --set-mss 1250
    iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o tun0  -j TCPMSS --set-mss 1250
}

undo()
{
    
    # All the above steps with s/add/del/g 
    iptables --flush
    iptables --flush -t nat
    iptables --flush -t mangle

    ip rule del from 192.168.0.0/24 to all lookup fwdpath prio 1000
    ip rule del from 192.168.1.0/24 to all lookup depart prio 1001
    ip rule del from all to 192.168.1.0/24 lookup revpath prio 1002
    ip rule del from 128.208.4.0/24 to 192.168.1.0/24 lookup revpath prio 1003 # Specific to DN # Specific to DNSS
    ip rule del from all to 192.168.0.0/24 lookup depart prio 1004
    ip rule del from 128.208.4.0/24 to all lookup depart prio 1005


    ip route del default via 192.168.0.1 dev tun0 table fwdpath
    ip route del 192.168.0.0/24 dev tun0 table fwdpath

    ip route del default via 128.208.4.100 dev eth0 table depart
    ip route del 128.208.4.0/24 dev eth0 table depart

    ip route del default via 192.168.0.1 dev tun0 table revpath
    ip route del 192.168.1.0/24 dev tun0 table revpath

    echo "1" > /proc/sys/net/ipv4/conf/tun0/rp_filter
    echo "1" > /proc/sys/net/ipv4/conf/all/rp_filter
    echo "1" > /proc/sys/net/ipv4/conf/eth0/rp_filter
    echo "1" > /proc/sys/net/ipv4/conf/default/rp_filter
    
    binPID=`pidof "./SimplePacketFilter"`
    if [ $? -ne 1 ] && [ ${binPID} != "" ]
    then    
	kill ${binPID}
    fi		
}

if [ $# -ne "1" ];
then
    echo $0 "<1 for setup> <2 for undo>"
else
    if [ $1 == "1" ];
    then
	setup
    else
	undo
    fi
fi