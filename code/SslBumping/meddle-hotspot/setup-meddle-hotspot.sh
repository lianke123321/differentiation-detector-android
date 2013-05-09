# Script to enable natting and bumping
set -a
MEDDLE_ROOT=/opt/meddle/

source ${MEDDLE_ROOT}/meddle.config


# Meddle assumes one external interface. However for this setup I needed a device with two interfaces. One regular interface such as eth0 or wlan0 through which the device is connected to the Internet and another interface wlan1 which makes the device act like an access pint. 
# The packets from the mobile clients enter from wlan1 and exit through wlan0 or eth0 (natDeviceName)
# The code is to setup
natDeviceName="wlan0"
natIpNetSlash="138.96.0.0/16"
natIpGateway="138.96.192.250"

# Taken from stopPacketFilter
undoMeddleRoutingTables()
{
    iptables -t nat -D POSTROUTING -s ${tunRevPathNetSlash} -o ${ethDeviceName} -j MASQUERADE

    iptables -D FORWARD -i tun+ -o ${ethDeviceName} -j ACCEPT
    iptables -D FORWARD -i ${ethDeviceName} -o tun+ -j ACCEPT

    ip rule del from ${tunFwdPathNetSlash} to all lookup fwdpath prio 1000
    ip rule del from ${tunRevPathNetSlash} to all lookup depart prio 1001
    ip rule del from all to ${tunRevPathNetSlash} lookup revpath prio 1002
    ip rule del from ${ethIpNetSlash} to ${tunRevPathNetSlash} lookup revpath prio 1003 # Specific to DN # Specific to DNSS
    ip rule del from all to ${tunFwdPathNetSlash} lookup depart prio 1004
    ip rule del from ${ethIpNetSlash} to all lookup depart prio 1005

    ip route del default via ${tunIpAddress} dev ${tunDeviceName} table fwdpath
    ip route del ${tunFwdPathNetSlash} dev ${tunDeviceName} table fwdpath

    ip route del default via ${ethIpGateway} dev ${ethDeviceName} table depart
    ip route del ${ethIpNetSlash} dev ${ethDeviceName} table depart

    ip route del default via ${tunIpAddress} dev ${tunDeviceName} table revpath
    ip route del ${tunRevPathNetSlash} dev ${tunDeviceName} table revpath
}

createRulesForNat()
{
    ip rule add from ${tunFwdPathNetSlash} to all lookup fwdpath prio 1000
    # Depart 
    ip rule add from ${tunRevPathNetSlash} to all lookup depart_nat prio 1001
    # Reverse path
    ip rule add from all to ${tunRevPathNetSlash} lookup revpath prio 1002
    # Special rule for reverse path
    ip rule add from ${ethIpNetSlash} to ${tunRevPathNetSlash} lookup revpath prio 1003 # Specific to DN # Specific to DNS
    # When to leave from the network
    ip rule add from all to ${tunFwdPathNetSlash} lookup depart prio 1004
    ip rule add from ${ethIpNetSlash} to all lookup depart prio 1005

    # The routing entries for the fwd path
    ip route add default via ${tunIpAddress} dev ${tunDeviceName} table fwdpath
    ip route add ${tunFwdPathNetSlash} dev ${tunDeviceName} table fwdpath

    # The routing entries for the departing packets
    ip route add default via ${ethIpGateway} dev ${ethDeviceName} table depart
    ip route add ${ethIpNetSlash} dev ${ethDeviceName} table depart


    ip route add default via ${natIpGateway} dev ${natDeviceName} table depart_nat
    ip route add ${natIpNetSlash} dev ${natDeviceName} table depart_nat

    # The routing entries for the reverse path packets
    ip route add default via ${tunIpAddress} dev ${tunDeviceName} table revpath
    ip route add ${tunRevPathNetSlash} dev ${tunDeviceName} table revpath

    # Enable forwarding between the tun+ devices and the ${eth} device
    iptables -A FORWARD -i tun+ -o ${ethDeviceName} -j ACCEPT
    iptables -A FORWARD -i ${ethDeviceName} -o tun+ -j ACCEPT

    iptables -A FORWARD -i tun+ -o ${natDeviceName} -j ACCEPT
    iptables -A FORWARD -i ${natDeviceName} -o tun+ -j ACCEPT

    # Enable the NAT
    iptables -t nat -A POSTROUTING -s ${tunRevPathNetSlash} -o ${natDeviceName} -j MASQUERADE
}

removeRulesForNat()
{
    # Disable e NAT
    iptables -t nat -D POSTROUTING -s ${tunRevPathNetSlash} -o ${natDeviceName} -j MASQUERADE

    # Disable forwarding between the tun+ devices and the ${eth} device
    iptables -D FORWARD -i tun+ -o ${ethDeviceName} -j ACCEPT
    iptables -D FORWARD -i ${ethDeviceName} -o tun+ -j ACCEPT

    iptables -D FORWARD -i tun+ -o ${natDeviceName} -j ACCEPT
    iptables -D FORWARD -i ${natDeviceName} -o tun+ -j ACCEPT

    # The routing entries for the fwd path

    ip route del ${tunFwdPathNetSlash} dev ${tunDeviceName} table fwdpath
    ip route del default via ${tunIpAddress} dev ${tunDeviceName} table fwdpath

    # The routing entries for the departing packets
    ip route del ${ethIpNetSlash} dev ${ethDeviceName} table depart
    ip route del default via ${ethIpGateway} dev ${ethDeviceName} table depart


    ip route del ${natIpNetSlash} dev ${natDeviceName} table depart_nat
    ip route del default via ${natIpGateway} dev ${natDeviceName} table depart_nat

    # The routing entries for the reverse path packets
    ip route del ${tunRevPathNetSlash} dev ${tunDeviceName} table revpath
    ip route del default via ${tunIpAddress} dev ${tunDeviceName} table revpath


    ip rule del from ${tunFwdPathNetSlash} to all lookup fwdpath prio 1000
    # Depart 
    ip rule del from ${tunRevPathNetSlash} to all lookup depart_nat prio 1001
    # Reverse path
    ip rule del from all to ${tunRevPathNetSlash} lookup revpath prio 1002
    # Special rule for reverse path
    ip rule del from ${ethIpNetSlash} to ${tunRevPathNetSlash} lookup revpath prio 1003 # Specific to DN # Specific to DNS
    # When to leave from the network
    ip rule del from all to ${tunFwdPathNetSlash} lookup depart prio 1004
    ip rule del from ${ethIpNetSlash} to all lookup depart prio 1005
}

createHotSpotRoutingEntries()
{
   undoMeddleRoutingTables
   createRulesForNat
}

removeHotSpotRoutingEntries()
{
   removeRulesForNat
   echo "Meddle will not work! Please Start Meddle again"   	
}

start()
{
   hostapd /etc/hostapd/hostapd.conf >> /opt/bumping/var/logs/hostapd.log 2>&1 & 
   echo "Sleeping 3 seconds for hostapd to come up"
   sleep 5
   service dnsmasq stop
   ifconfig wlan1 192.168.1.1 up
   service dnsmasq start
   ifconfig wlan1
   service mysqld restart
   ${MEDDLE_ROOT}/usr/sbin/SetupMeddle.sh start
   createHotSpotRoutingEntries   
}


stop()
{
   removeHotSpotRoutingEntries
   ${MEDDLE_ROOT}/usr/sbin/SetupMeddle.sh stop  
   service dnsmasq stop
   ifconfig wlan1 dow
   sudo pkill hostapd   
}

echo "argument is $1"
if [ "$1" == "start" ];
then
   start
else
   if [ "$1" == "stop" ];
   then
      stop
   else 
      echo "what?"
   fi
fi
