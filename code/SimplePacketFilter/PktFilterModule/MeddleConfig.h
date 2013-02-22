#ifndef PKT_FILTER_CONFIG_H_
#define PKT_FILTER_CONFIG_H_

#include <string>
#include <stdint.h>
#include <boost/program_options.hpp>

namespace po = boost::program_options;
#if 0
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

#define DB_SERVER "sounder.cs.washington.edu"
#define DB_USER "meddle"
#define DB_PASSWORD "q@847#$6&4@RfbvD"
#define DB_NAME "MeddleDB"

#endif

class MeddleConfig{
public:
	bool validConfig;
	std::string tunDeviceName;
	std::string tunFwdPathNet;
	std::string tunRevPathNet;
	std::string tunIpNetmask;
	std::string tunRouteNetmask;
	std::string tunIpAddress;
	std::string msgSockPort;
	std::string msgSockIpAddress;
	std::string fltrDefaultDNS;
	std::string fltrAdBlockDNS;
	std::string dbServer;
	std::string dbUserName;
	std::string dbPassword;
	std::string dbName;
private:
	po::options_description desc;
	bool BindVariables();
public:
	bool ReadConfigFile(std::string configName);
	MeddleConfig();
	MeddleConfig(std::string configName);
	~MeddleConfig();
	friend std::ostream& operator<<(std::ostream& os, const MeddleConfig& mc);
};

#endif
