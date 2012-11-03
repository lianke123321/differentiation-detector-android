eth="eth1"
tun="tun0"
tunIP="10.11.101.101"
fwdNet="10.11.0.0/16"
revNet="10.101.0.0/16"
natNet="10.0.0.0/8"
gateway="128.208.4.100"
ethNet="128.208.4.0/24"

logSuffix=`date  +%h-%d-%Y-%H-%M-%s`
filterLogName="/data/SimplePacketFilter-"${logSuffix}".log"
webServerLogName="/data/webServer-"${logSuffix}".log"
basePath="/data/usr/sbin/"
webServerCommand="/data/webServer/MainServer.py"


enableMySqlIpTables()
{
    iptables -D INPUT -p tcp -s localhost --dport 3306 -j ACCEPT
    iptables -D INPUT -p tcp --dport 3306 -j REJECT

    iptables -I INPUT -p tcp -s localhost --dport 3306 -j ACCEPT
    iptables -I INPUT -p tcp -s sounder.cs.washington.edu --dport 3306 -j ACCEPT
    iptables -I INPUT -p tcp -s snowmane.cs.washington.edu --dport 3306 -j ACCEPT
    iptables -I INPUT -p tcp -s meddle.cs.washington.edu --dport 3306 -j ACCEPT
    iptables -A INPUT -p tcp ! -s ${natNet} --dport 3306 -j REJECT    
}    

disableMySqlIpTables()
{
    iptables -D INPUT -p tcp -s localhost --dport 3306 -j ACCEPT
    iptables -D INPUT -p tcp --dport 3306 -j REJECT
        
    iptables -D INPUT -p tcp ! -s ${natNet} --dport 3306 -j REJECT
    iptables -D INPUT -p tcp -s localhost --dport 3306 -j ACCEPT
    iptables -D INPUT -p tcp -s sounder.cs.washington.edu --dport 3306 -j ACCEPT
    iptables -D INPUT -p tcp -s snowmane.cs.washington.edu --dport 3306 -j ACCEPT
    iptables -D INPUT -p tcp -s meddle.cs.washington.edu --dport 3306 -j ACCEPT

    iptables -A INPUT -p tcp -s localhost --dport 3306 -j ACCEPT
    iptables -A INPUT -p tcp --dport 3306 -j REJECT    
}


startPacketFilter()
{
    ${basePath}/SimplePacketFilter > ${filterLogName} 2>&1 &
    echo "Sleeping for the device to come up"
    sleep 5 

    # Disable the proxy arp
    echo "1" > /proc/sys/net/ipv4/conf/${tun}/proxy_arp

    # Disable reverse path filtering TODO:: Need to find the minimum rules to get this working
    echo "0" > /proc/sys/net/ipv4/conf/${tun}/rp_filter
    echo "0" > /proc/sys/net/ipv4/conf/all/rp_filter
    echo "0" > /proc/sys/net/ipv4/conf/${eth}/rp_filter
    echo "0" > /proc/sys/net/ipv4/conf/default/rp_filter

    # Disable all forms of offloading to ensure packets larger than 1.5K are not received 
    # We do not want to fragment packets in the tun device and compute checksums for received packets 
    # in the tun device
    echo "Disable all forms of offloading"
    ethtool -K ${eth} tx off
    ethtool -K ${tun} tx off
    ethtool -K ${eth} rx off
    ethtool -K ${eth} tso off
    ethtool -K ${eth} ufo off
    ethtool -K ${eth} gso off
    ethtool -K ${eth} gro off
    ethtool -K ${tun} gro off
    ethtool -K ${eth} lro off
    ethtool -K ${tun} lro off

    # The forward path 
    ip rule add from ${fwdNet} to all lookup fwdpath prio 1000
    # Depart 
    ip rule add from ${revNet} to all lookup depart prio 1001
    # Reverse path
    ip rule add from all to ${revNet} lookup revpath prio 1002
    # Special rule for reverse path
    ip rule add from ${ethNet} to ${revNet} lookup revpath prio 1003 # Specific to DN # Specific to DNS
    # When to leave from the network
    ip rule add from all to ${fwdNet} lookup depart prio 1004
    ip rule add from ${ethNet} to all lookup depart prio 1005

    # The routing entries for the fwd path
    ip route add default via ${tunIP} dev ${tun} table fwdpath
    ip route add ${fwdNet} dev ${tun} table fwdpath

    # The routing entries for the departing packets
    ip route add default via ${gateway} dev ${eth} table depart
    ip route add ${ethNet} dev ${eth} table depart

    # The routing entries for the reverse path packets
    ip route add default via ${tunIP} dev ${tun} table revpath
    ip route add ${revNet} dev ${tun} table revpath

    # Enable forwarding between the tun+ devices and the ${eth} device
    iptables -A FORWARD -i tun+ -o ${eth} -j ACCEPT
    iptables -A FORWARD -i ${eth} -o tun+ -j ACCEPT

    # Enable the NAT
    iptables -t nat -A POSTROUTING -s ${revNet} -o ${eth} -j MASQUERADE
    
    # Reduce the MSS to support the IPsec headers in the response.  We do not want to fragment on this machine.
    # iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o ${eth}  -j TCPMSS --set-mss 1250
    # iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o ${tun}  -j TCPMSS --set-mss 1250
    # Disabled MSS for now
}

stopPacketFilter()
{
    iptables -t nat -D POSTROUTING -s ${revNet} -o ${eth} -j MASQUERADE

    iptables -D FORWARD -i tun+ -o ${eth} -j ACCEPT
    iptables -D FORWARD -i ${eth} -o tun+ -j ACCEPT
    
    ip rule del from ${fwdNet} to all lookup fwdpath prio 1000
    ip rule del from ${revNet} to all lookup depart prio 1001
    ip rule del from all to ${revNet} lookup revpath prio 1002
    ip rule del from ${ethNet} to ${revNet} lookup revpath prio 1003 # Specific to DN # Specific to DNSS
    ip rule del from all to ${fwdNet} lookup depart prio 1004
    ip rule del from ${ethNet} to all lookup depart prio 1005

    ip route del default via ${tunIP} dev ${tun} table fwdpath
    ip route del ${fwdNet} dev ${tun} table fwdpath

    ip route del default via ${gateway} dev ${eth} table depart
    ip route del ${ethNet} dev ${eth} table depart

    ip route del default via ${tunIP} dev ${tun} table revpath
    ip route del ${revNet} dev ${tun} table revpath

    echo "1" > /proc/sys/net/ipv4/conf/${tun}/rp_filter
    echo "1" > /proc/sys/net/ipv4/conf/all/rp_filter
    echo "1" > /proc/sys/net/ipv4/conf/${eth}/rp_filter
    echo "1" > /proc/sys/net/ipv4/conf/default/rp_filter
    
    binPID=`pidof "${basePath}/SimplePacketFilter"`
    if [ $? -ne 1 ] && [ ${binPID} != "" ]
    then    
	kill ${binPID}
    fi
}

startIPSec()
{
    ${basePath}/ipsec start
}

stopIPSec()
{
    ${basePath}/ipsec stop
}

startWebServer()
{
    echo "Manually Start the webserver if not running with the command ${webServerCommand} > ${webServerLogName} 2>&1" 
}

stopWebServer()
{
    echo "Manually Stop the Webserver"
}

startMeddle()
{
    enableMySqlIpTables
    startPacketFilter
    startIPSec
    startWebServer
}

stopMeddle()
{  
    stopIPSec
    stopPacketFilter
    disableMySqlIpTables
    stopWebServer
}

if [ $# -ne "1" ];
then
    echo $0 "<1 for setup> <2 for undo>"
else
    if [ $1 == "1" ];
    then
	startMeddle
    else
	stopMeddle
    fi
fi
