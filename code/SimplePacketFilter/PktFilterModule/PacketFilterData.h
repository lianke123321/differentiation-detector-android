/*
 * PacketFilterData.h
 *
 *  Created on: 2012-09-19
 *      Author: arao
 */

#ifndef PACKETFILTERDATA_H_
#define PACKETFILTERDATA_H_

#include <boost/thread/mutex.hpp>
#include "DatabaseManager.h"
#include "UserConfigs.h"
#include "IpUserMap.h"
#include <vector>
#include <vector>
#include <string>
#include "Macros.h"

class PacketFilterData
{
private:
	boost::mutex filterLock;
	UserConfigs userConfigs;
	IpUserMap ipMap;
	DatabaseManager dbManager;
	bool __loadConfigs(std::string query);
public:
	PacketFilterData();
	~PacketFilterData();
	bool loadAllUserConfigs();
	bool loadUserConfigs(const std::string &userName);
	UserConfigs& getUserConfigs();
	IpUserMap& getIPMap();
	bool connectToDB(const std::string &hostname, const std::string &dbUser, const std::string &dbPassword, const std::string &dbName);
	bool getUserConfigs(in_addr_t addr, uint32_t &userID, user_config_entry_t &entry);
	bool getUserID(in_addr_t addr, uint32_t &userID);
	bool associateUserToIp(const std::string &userName, const in_addr_t &addr);
	bool disassociateIpFromUser(const std::string &userName, const in_addr_t &addr);
	bool associateClientToServerIp(const uint32_t &userID, const std::string &clientTunnelIP, const std::string &clientRemoteIP, std::string &serverIP);
	bool disassociateClientFromServerIp(const uint32_t & userID, const std::string &clientTunnelIP, const std::string &clientRemoteIP, std::string &serverIP);
};




#endif /* PACKETFILTERDATA_H_ */
