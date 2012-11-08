#ifndef SIMPLEPACKETFILTER_H_
#define SIMPLEPACKETFILTER_H_


#include "IpUserMap.h"
#include <boost/thread/mutex.hpp>
#include "DatabaseManager.h"
#include "UserConfigs.h"
#include "PacketFilterData.h"

//// Structure that has all objects to be kept global
//struct pktFilter {
//	UserConfigs userConfigs;
//	IpUserMap ipMap;
//	DatabaseManager dbManager;
//	boost::mutex filterLock;
//};
//typedef struct pktFilter pktFilter_t;

//TODO:: Move these to config file
#define TUN_DEVICE "tun0"
#define FWD_PATH_NET "10.11.0.0" // The IP network of the mobile device just after/before coming from the VPN tunnel
#define REV_PATH_NET "10.101.0.0" // The IP network for the mobile device after NAT in fwd path
#define DEV_NETMASK "255.0.0.0" // The netmask used for the tun0 device
#define ROUTE_NETMASK "255.255.0.0" // The Netmask used for the forward and reverse paths
#define IP_ADDRESS "10.11.101.101"
#define MEDDLE_MESSAGE_SOCKET_PORT 12321
#define MEDDLE_MESSAGE_SOCKET_ADDR "127.0.0.1"

//#define COMMAND_SOCKET_PATH "/data/.meddleCmdSocket"

#define DEFAULT_DNS_SERVER "128.208.4.1"
#define FILTER_DNS_SERVER "128.208.4.189"

#define FLAG_STARTSTOP_START 1
#define FLAG_STARTSTOP_STOP  0


extern PacketFilterData mainPktFilter;

#endif /* SIMPLEPACKETFILTER_H_ */
