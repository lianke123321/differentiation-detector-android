#ifndef SIMPLEPACKETFILTER_H_
#define SIMPLEPACKETFILTER_H_

#include "IpUserMap.h"
#include <boost/thread/mutex.hpp>

// Structure that has all objects to be kept global
struct pktFilter {
	IpUserMap ipMap;
	boost::mutex filterLock;
};
typedef struct pktFilter pktFilter_t;

//TODO:: Move these to config file
#define TUN_DEVICE "tun0"
#define FWD_PATH_NET "192.168.0.0"
#define REV_PATH_NET "192.168.1.0"
#define DEV_NETMASK "255.255.254.0"
#define ROUTE_NETMASK "255.255.255.0"
#define IP_ADDRESS "192.168.0.1"
#define COMMAND_SOCKET_PATH "/data/.meddleCmdSocket"

extern pktFilter_t mainPktFilter;

#endif /* SIMPLEPACKETFILTER_H_ */
