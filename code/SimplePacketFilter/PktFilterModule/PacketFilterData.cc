#include "PacketFilterData.h"
#include "Logging.h"
#include <mysql/mysql.h>


PacketFilterData::PacketFilterData()
{
	// TODO Auto-generated constructor stub

}

PacketFilterData::~PacketFilterData()
{
	// TODO Auto-generated destructor stub
}
bool PacketFilterData::connectToDB(std::string hostname, std::string dbUser, std::string dbPassword, std::string dbName)
{
	if (false == dbManager.connectDB(hostname, dbUser, dbPassword, dbName)) {
		logError("Error in connecting to the database");
		return false;
	}
	return true;
}


bool PacketFilterData::loadAllUserConfigs()
{
	std::string query = "SELECT userID, userName, filterAdsAnalytics FROM UserConfigs;";
	MYSQL_RES *results;
	MYSQL_ROW row;
	std::vector<user_config_entry_t> configVector;

	logDebug("Executing query " << query);

	if (false == dbManager.execFetchQuery(query, &results)) {
		logError("Error reading confs");
		return false;
	}

	if (results == NULL) {
		logDebug("No entries in the user table");
		return false;
	}
	logDebug("Fetching the " << results->row_count);
	while ((row = mysql_fetch_row(results)))
	{
		user_config_entry_t entry;
		entry.userID = atoi(row[0]); // Assumes the entry is encoded in ascii.
		memcpy(entry.userName, row[1], sizeof(entry.userName));
		entry.filterAdsAnalytics = atoi(row[2]);
		logDebug("Fetching Entry for id:" << entry.userID << " name:"<< entry.userName << " with filterAds set to " << entry.filterAdsAnalytics);
		configVector.push_back(entry);
	}

	for(int i=0; i<configVector.size(); i=i+1) {
		TAKE_SCOPED_LOCK(filterLock);
		userConfigs.addEntry(configVector[i]);
	}
	mysql_free_result(results);
	return true;
}

bool PacketFilterData::getUserConfigs(in_addr_t addr, uint32_t& userID, user_config_entry_t& entry)
{
	TAKE_SCOPED_LOCK(filterLock);
	if (false == ipMap.getUserID(addr, userID)) {
		logError("Error in getting the user ID for the given IP");
		return false;
	}

	if (false == userConfigs.getConfigById(userID, entry)) {
		logError("Error getting the configs for the userID" << userID);
		return false;
	}
	return true;
}

bool PacketFilterData::associateUserToIp(const std::string &userName, const in_addr_t &addr)
{
	uint32_t userID;

	if (false == userConfigs.getUserIdByName(userName, userID)) {
		logError("Unable to get the DB entry for the user" << userName);
		return false;
	}

	boost::mutex::scoped_lock scoped_lock(filterLock); // lock is released automatically outside this scope
	if (false == ipMap.addEntry(addr, userID)) {
			logError("Error adding the user" << userName);
			return false;
	}
	return true;
}

bool PacketFilterData::disassociateIpFromUser(const std::string &userName, const in_addr_t &addr)
{
	uint32_t userID;
	if (false == userConfigs.getUserIdByName(userName, userID)) {
		logError("Unable to get the DB entry for the user" << userName);
		return false;
	}

	boost::mutex::scoped_lock scoped_lock(filterLock); // lock is released automatically outside this scope
	if (false == ipMap.removeEntry(addr)) {
		logError("Error in removing the entry for ipAddress" << addr << " for user "<< userName);
		return false;
	}
	return true;
}

UserConfigs& PacketFilterData::getUserConfigs()
{
	return userConfigs;
}

IpUserMap& PacketFilterData::getIPMap()
{
	return ipMap;
}
