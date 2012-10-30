#include "PacketFilterData.h"
#include "SimplePacketFilter.h"
#include "Logging.h"
#include <mysql/mysql.h>
#include <string.h>


PacketFilterData::PacketFilterData()
{
	// TODO Auto-generated constructor stub

}

PacketFilterData::~PacketFilterData()
{
	// TODO Auto-generated destructor stub
}
bool PacketFilterData::connectToDB(const std::string &hostname, const std::string &dbUser, const std::string &dbPassword, const std::string &dbName)
{
	if (false == dbManager.connectDB(hostname, dbUser, dbPassword, dbName)) {
		logError("Error in connecting to the database");
		return false;
	}
	return true;
}

bool PacketFilterData::__loadConfigs(std::string query)
{
	MYSQL_RES *results;
	MYSQL_ROW row;
	std::vector<user_config_entry_t> configVector;

	logDebug("Executing query " << query);

	if (false == dbManager.execReadQuery(query, &results)) {
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
	logDebug(userConfigs);
	mysql_free_result(results);
	return true;
}

bool PacketFilterData::loadAllUserConfigs()
{
	// std::string query = "SELECT userID, userName, filterAdsAnalytics FROM UserConfigs;";
	// return __loadConfigs(query);
	logError("IF YOU CAN SEE THIS MESSAGE IT MEANS YOU DID NOT UNCOMMENT THE PREVIOUS LINES");
	return true;
}

bool PacketFilterData::loadUserConfigs(const std::string &userName)
{
	std::stringstream query;
	query.clear();
	query << "SELECT userID, userName, filterAdsAnalytics FROM UserConfigs WHERE userName = \'" << userName << "\';";
	return __loadConfigs(query.str());
}

bool PacketFilterData::loadUserConfigs(const uint32_t &userID)
{
	std::stringstream query;
	query.clear();
	query << "SELECT userID, userName, filterAdsAnalytics FROM UserConfigs WHERE userID = \'" << userID << "\';";
	return __loadConfigs(query.str());
}

bool PacketFilterData::getUserConfigs(const in_addr_t &addr, uint32_t& userID, user_config_entry_t& entry)
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
	logDebug("User configs are userID " << userID << " " << entry.userName << " " << entry.userID);
	return true;
}

bool PacketFilterData::getUserConfigs(const uint32_t& userID, user_config_entry_t& entry)
{
	if (false == userConfigs.getConfigById(userID, entry)) {
			logError("Error getting the configs for the userID" << userID);
			return false;
		}
	logDebug("User configs for userID " << userID << " " << entry.userName << " " << entry.userID);
	return true;
}

bool PacketFilterData::getUserID(const in_addr_t &addr, uint32_t& userID)
{
	TAKE_SCOPED_LOCK(filterLock);
	if (false == ipMap.getUserID(addr, userID)) {
		logError("Error in getting the user ID for the given IP");
		return false;
	}
	logDebug("User ID is " << userID);
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
	logError("IP Map is" << ipMap);
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
	logError("IP Map is " << ipMap);
	return true;
}

UserConfigs& PacketFilterData::getAllUserConfigs()
{
	return userConfigs;
}

IpUserMap& PacketFilterData::getIPMap()
{
	return ipMap;
}

bool PacketFilterData::associateClientToServerIp(const uint32_t &userID, const std::string &clientTunnelIP, const std::string &clientRemoteIP, std::string &serverIP)
{
	std::stringstream query;
	//	query << "UPDATE UserServerInfo SET serverIPAddress = \"" << serverIP << "\" WHERE userID = " << userID << ";";
	//	logInfo("Query " << query);
	//	if (false == dbManager.execWriteQuery(query.str())) {
//		logError("Error in associating the serverIP to user ID" << query);
//		query << "INSERT INTO UserServerInfo VALUES (" << userID << ", \"" << serverIP << "\");";
//		logInfo(" Trying to insert now :: Query "<< query)
//		if (false == dbManager.execWriteQuery(query.str())) {
//			logError("Error in Insert");
//			return false;
//		}
//		logDebug("Insert works!! ");
//	}
// (userID INT NOT NULL PRIMARY KEY, remoteIpAddress VARCHAR(64) NOT NULL, serverIpAddress VARCHAR(64) NOT NULL, timestamp TIMESTAMP NOT NULL  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, startStopFlag BOOLEAN NOT NULL DEFAULT 0)
	query.clear();
	query << "INSERT INTO UserTunnelInfo VALUES (0, " << userID << ", \'" << clientTunnelIP << "\',\'" << clientRemoteIP << "\',\'" << serverIP << "\', CURRENT_TIMESTAMP, " << FLAG_STARTSTOP_START << " );";
	logInfo("Query " << query);
	if (false == dbManager.execWriteQuery(query.str())) {
		logError("Error in Insert" << query);
		return false;
	}
	return true;

}


bool PacketFilterData::disassociateClientFromServerIp(const uint32_t & userID, const std::string & clientTunnelIP, const std::string &clientRemoteIP, std::string & serverIP)
{
	std::stringstream query;
	query.clear();
	query << "INSERT INTO UserTunnelInfo VALUES (0, " << userID << ", \'" << clientTunnelIP << "\',\'" << clientRemoteIP << "\',\'" << serverIP << "\', CURRENT_TIMESTAMP, " << FLAG_STARTSTOP_STOP << ");";
	logInfo("Query " << query);
	if (false == dbManager.execWriteQuery(query.str())) {
		logError("Error in Insert" << query);
		return false;
	}
	return true;
}
