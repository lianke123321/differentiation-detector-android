MEDDLE_ROOT=${PWD}
MEDDLE_CONFIG=${MEDDLE_ROOT}/meddle.config
set -a
source ${MEDDLE_CONFIG}

logSuffix=`date  +%h-%d-%Y-%H-%M-%s`
logPath="${MEDDLE_ROOT}/logs/"
mkdir -p ${logPath}
filterLogName="${logPath}/SimplePacketFilter-${logSuffix}.log"
webServerLogName="${logPath}/webServer-${logSuffix}.log"
basePath="${MEDDLE_ROOT}/usr/sbin/"
webServerCommand="${MEDDLE_ROOT}/webServer/MainServer.py"

enableMySqlIpTables()
{
    iptables -D INPUT -p tcp -s localhost --dport 3306 -j ACCEPT
    iptables -D INPUT -p tcp --dport 3306 -j REJECT

    iptables -I INPUT -p tcp -s localhost --dport 3306 -j ACCEPT
    iptables -A INPUT -p tcp ! -s ${tunIpNetSlash} --dport 3306 -j REJECT    
}    

disableMySqlIpTables()
{
    iptables -D INPUT -p tcp -s localhost --dport 3306 -j ACCEPT
    iptables -D INPUT -p tcp --dport 3306 -j REJECT
        
    iptables -D INPUT -p tcp ! -s ${tunIpNetSlash} --dport 3306 -j REJECT
    iptables -D INPUT -p tcp -s localhost --dport 3306 -j ACCEPT

    iptables -A INPUT -p tcp -s localhost --dport 3306 -j ACCEPT
    iptables -A INPUT -p tcp --dport 3306 -j REJECT    
}


startPacketFilter()
{
    ${basePath}/SimplePacketFilter -c ${MEDDLE_CONFIG} > ${filterLogName} 2>&1 &
    echo "Sleeping for the device to come up"
    sleep 5 

    # Disable the proxy arp
    echo "1" > /proc/sys/net/ipv4/conf/${tunDeviceName}/proxy_arp

    # Disable reverse path filtering TODO:: Need to find the minimum rules to get this working
    echo "0" > /proc/sys/net/ipv4/conf/${tunDeviceName}/rp_filter
    echo "0" > /proc/sys/net/ipv4/conf/all/rp_filter
    echo "0" > /proc/sys/net/ipv4/conf/${ethDeviceName}/rp_filter
    echo "0" > /proc/sys/net/ipv4/conf/default/rp_filter

    # Disable all forms of offloading to ensure packets larger than 1.5K are not received 
    # We do not want to fragment packets in the tun device and compute checksums for received packets 
    # in the tun device
    echo "Disable all forms of offloading"
    ethtool -K ${ethDeviceName} tx off
    ethtool -K ${tunDeviceName} tx off
    ethtool -K ${ethDeviceName} rx off
    ethtool -K ${ethDeviceName} tso off
    ethtool -K ${ethDeviceName} ufo off
    ethtool -K ${ethDeviceName} gso off
    ethtool -K ${ethDeviceName} gro off
    ethtool -K ${tunDeviceName} gro off
    ethtool -K ${ethDeviceName} lro off
    ethtool -K ${tunDeviceName} lro off

    # NOTE: The numbers 1000, 1001, and 1002 do not mean anything for now!
    # The forward path 
    ip rule add from ${tunFwdPathNetSlash} to all lookup fwdpath prio 1000
    # Depart 
    ip rule add from ${tunRevPathNet} to all lookup depart prio 1001
    # Reverse path
    ip rule add from all to ${tunRevPathNet} lookup revpath prio 1002
    # Special rule for reverse path
    ip rule add from ${ethIpNetSlash} to ${tunRevPathNet} lookup revpath prio 1003 # Specific to DN # Specific to DNS
    # When to leave from the network
    ip rule add from all to ${tunFwdPathNetSlash} lookup depart prio 1004
    ip rule add from ${ethIpNetSlash} to all lookup depart prio 1005

    # The routing entries for the fwd path
    ip route add default via ${tunIpAddress} dev ${tunDeviceName} table fwdpath
    ip route add ${tunFwdPathNetSlash} dev ${tunDeviceName} table fwdpath

    # The routing entries for the departing packets
    ip route add default via ${ethIpGateway} dev ${ethDeviceName} table depart
    ip route add ${ethIpNetSlash} dev ${ethDeviceName} table depart

    # The routing entries for the reverse path packets
    ip route add default via ${tunIpAddress} dev ${tunDeviceName} table revpath
    ip route add ${tunRevPathNet} dev ${tunDeviceName} table revpath

    # Enable forwarding between the tun+ devices and the ${eth} device
    iptables -A FORWARD -i tun+ -o ${ethDeviceName} -j ACCEPT
    iptables -A FORWARD -i ${ethDeviceName} -o tun+ -j ACCEPT

    # Enable the NAT
    iptables -t nat -A POSTROUTING -s ${tunRevPathNet} -o ${ethDeviceName} -j MASQUERADE
}

stopPacketFilter()
{
    iptables -t nat -D POSTROUTING -s ${tunRevPathNet} -o ${ethDeviceName} -j MASQUERADE

    iptables -D FORWARD -i tun+ -o ${ethDeviceName} -j ACCEPT
    iptables -D FORWARD -i ${ethDeviceName} -o tun+ -j ACCEPT
    
    ip rule del from ${tunFwdPathNetSlash} to all lookup fwdpath prio 1000
    ip rule del from ${tunRevPathNet} to all lookup depart prio 1001
    ip rule del from all to ${tunRevPathNet} lookup revpath prio 1002
    ip rule del from ${ethIpNetSlash} to ${tunRevPathNet} lookup revpath prio 1003 # Specific to DN # Specific to DNSS
    ip rule del from all to ${tunFwdPathNetSlash} lookup depart prio 1004
    ip rule del from ${ethIpNetSlash} to all lookup depart prio 1005

    ip route del default via ${tunIpAddress} dev ${tunDeviceName} table fwdpath
    ip route del ${tunFwdPathNetSlash} dev ${tunDeviceName} table fwdpath

    ip route del default via ${ethIpGateway} dev ${ethDeviceName} table depart
    ip route del ${ethIpNetSlash} dev ${ethDeviceName} table depart

    ip route del default via ${tunIpAddress} dev ${tunDeviceName} table revpath
    ip route del ${tunRevPathNet} dev ${tunDeviceName} table revpath

    echo "1" > /proc/sys/net/ipv4/conf/${tunDeviceName}/rp_filter
    echo "1" > /proc/sys/net/ipv4/conf/all/rp_filter
    echo "1" > /proc/sys/net/ipv4/conf/${ethDeviceName}/rp_filter
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
