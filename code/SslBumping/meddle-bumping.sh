MEDDLE_ROOT=/opt/meddle/
BUMPING_ROOT=/opt/bumping/
set -a
source ${MEDDLE_ROOT}/meddle.config

natDeviceIp="138.96.192.56"

startTrafficRedirect()
{
  iptables -t nat -A PREROUTING -s ${tunRevPathNetSlash} -p tcp --dport 80 -j DNAT --to ${natDeviceIp}:3128
  iptables -t nat -A PREROUTING -s ${tunRevPathNetSlash} -p tcp --dport 443 -j DNAT --to ${natDeviceIp}:3129
}

stopTrafficRedirect()
{
  iptables -t nat -D PREROUTING -s ${tunRevPathNetSlash} -p tcp --dport 80 -j DNAT --to ${natDeviceIp}:3128
  iptables -t nat -D PREROUTING -s ${tunRevPathNetSlash} -p tcp --dport 443 -j DNAT --to ${natDeviceIp}:3129
}

start()
{
  ./squid -d 6 >> ${BUMPING_ROOT}/var/logs/squid-cmd.log 2>&1
  startTrafficRedirect
}

stop()
{
  stopTrafficRedirect
  pkill squid
  
}

if [ "$1" == "start" ];
then
   start
else
   if [ "$1" == "stop" ];
   then
      stop
   else
      echo "Pardon! What??"
   fi
fi 
