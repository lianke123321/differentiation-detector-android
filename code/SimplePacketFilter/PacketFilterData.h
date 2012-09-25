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

class PacketFilterData
{
private:
	boost::mutex filterLock;
	UserConfigs userConfigs;
	IpUserMap ipMap;
	DatabaseManager dbManager;
public:
	PacketFilterData();
	~PacketFilterData();
	bool loadAllUserConfigs();
	bool connectToDB(std::string hostname, std::string dbUser, std::string dbPassword, std::string dbName);
	bool getUserConfigs(in_addr_t addr, uint32_t &userID, user_config_entry_t &entry);
	bool associateUserToIp(const std::string &userName, const in_addr_t &addr);
	bool disassociateIpFromUser(const std::string &userName, const in_addr_t &addr);
};

#define TAKE_SCOPED_LOCK(lock) boost::mutex::scoped_lock scoped_lock(lock);


#endif /* PACKETFILTERDATA_H_ */
