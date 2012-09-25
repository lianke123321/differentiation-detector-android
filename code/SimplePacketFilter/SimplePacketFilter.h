#ifndef SIMPLEPACKETFILTER_H_
#define SIMPLEPACKETFILTER_H_


#include "IpUserMap.h"
#include <boost/thread/mutex.hpp>
#include "DatabaseManager.h"
#include "UserConfigs.h"
#include "PacketFilterData.h"

// Structure that has all objects to be kept global
struct pktFilter {
	UserConfigs userConfigs;
	IpUserMap ipMap;
	DatabaseManager dbManager;
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

#define DB_SERVER "localhost"
#define DB_USER "meddle"
#define DB_PASSWORD "meddle"
#define DB_NAME "MeddleDB"


extern PacketFilterData mainPktFilter;

#endif /* SIMPLEPACKETFILTER_H_ */
