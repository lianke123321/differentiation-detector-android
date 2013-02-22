#include "Logging.h"
#include "MessageSender.h"
#include "MessageFrame.h"
#include "DatabaseManager.h"
#include <string>
#include <stdint.h>
#include "MeddleConfig.h"


bool verifyEntry(const MeddleConfig &meddleConfig, const uint32_t &userID, const user_config_entry_t &meddleEntry)
{
	DatabaseManager db;
	MYSQL_RES *results;
	MYSQL_ROW row;

	if (false == db.connectDB(meddleConfig.dbServer, meddleConfig.dbUserName, meddleConfig.dbPassword, meddleConfig.dbName)) {
		logError("Cannot verify the change! Error connecting to the database");
		return false;
	}

	std::stringstream query;
	query.clear();
	query << "SELECT * FROM UserConfigs WHERE userID = " << userID;
	user_config_entry_t entry;
	if (false == db.execReadQuery(query.str(), &results)) {
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
		entry.userID = atoi(row[0]); // Assumes the entry is encoded in ascii.
		memcpy(entry.userName, row[1], sizeof(entry.userName));
		entry.filterAdsAnalytics = atoi(row[2]);
	}
	logDebug("Checking if the meddleEntry matches with the entry in the database");
	if ((entry.filterAdsAnalytics != meddleEntry.filterAdsAnalytics) || (entry.userID != meddleEntry.userID)) {
		logError("Entry values" << entry.userID << " " << entry.userName << " " << (int32_t)(entry.filterAdsAnalytics));
		logError("Meddle entry " << meddleEntry.userID << " " << meddleEntry.userName << " " << (int32_t) (meddleEntry.filterAdsAnalytics));
		return false;
	}
	return true;
}

bool sendCommand(const std::string & configName, const uint32_t &userID)
{
	MessageSender cmdSender;
	msgLoadUserConfs_t msgLoadConfs;
	msgLoadConfs.userID = userID;
	user_config_entry entry;
	bool ret;
	MeddleConfig config;

	if (false == config.ReadConfigFile(configName)) {
		logError("Error reading the config file");
		return false;
	}
	logInfo(config);
	if (false == cmdSender.connectToServer(config.msgSockIpAddress, config.msgSockPort)) {
		logError("Error in connecting to the server");
		return false;
	}
	if (cmdSender.sockFD < 0) { // redundant now!
		logError("Error in creating the socket");
		return false;
	}

	ret = cmdSender.sendCommand(msgLoadConfs, entry);
	if (ret == false) {
		logError("Error in receiving the entry");
		return false;
	}
	ret = verifyEntry(config, userID, entry);
	if (ret == false) {
		logError("Entry does not match the entries in DB");
		return false;
	}
	return true;
}

bool ParseCommandLine(std::string &configName, uint32_t &userID, int argc, char *argv[])
{
	po::options_description desc("Allowed options");
	try {
		desc.add_options()
			("help,h", "produce help message")
			("configFile,c", po::value<std::string>(&configName)->required(), "the name of the config file")
			("userID,u", po::value<uint32_t>(&userID)->required(), "the user ID whose config has been changed");
		po::variables_map vm;
		po::store(po::parse_command_line(argc, argv, desc), vm);
		if (vm.count("help")) {
			logError(desc);
			return false;
		}
		po::notify(vm);
	} catch(std::exception& e) {
		logError("Error: " << e.what());
		logError(desc);
		return false;
	} catch(...) {
		logError("Unknown error!");
		return false;
	}
	logInfo("You have provided '" << configName);
	return true;
}

int main(int argc, char *argv[])
{
	uint32_t userID;
	bool ret;
	uint32_t cnt;
	const uint32_t maxCnt = 10;
	std::string configName;

	if (false == ParseCommandLine(configName, userID, argc, argv)) {
		logError("Error reading the command line arguments");
		return 1;
	}
	for (cnt = 0; cnt < maxCnt; cnt = cnt + 1) {
		ret = sendCommand(configName, userID);
		if (ret == true) {
			logDebug("Message produced required results");
			break;
		}
		usleep(100);
		logError("Retrying attempt" << cnt+1);
	}
	if (cnt >= maxCnt) {
		return 1;
	}
	return 0;
}
