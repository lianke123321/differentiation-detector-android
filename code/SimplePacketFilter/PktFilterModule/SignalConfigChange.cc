#include "Logging.h"
#include "MessageSender.h"
#include "MessageFrame.h"
#include "DatabaseManager.h"
#include "string.h"

bool checkArgs(const std::string &userID, uint32_t &uID)
{
	uID = 0;
	try {
		logDebug("Converting the input " << userID << " to integer to check validity");
		std::stringstream buff(userID);
		buff >> uID;
	} catch (...) { // Catch any exception
		logError("Exception in conversion of input " << userID << " to integer");
		return false;
	}
	return true;
}

bool verifyEntry(const uint32_t &userID, const user_config_entry_t &meddleEntry)
{
	DatabaseManager db;
	MYSQL_RES *results;
	MYSQL_ROW row;
	db.connectDB();
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

bool sendCommand(const uint32_t &userID)
{
	MessageSender cmdSender;
	msgLoadUserConfs_t msgLoadConfs;
	msgLoadConfs.userID = userID;
	user_config_entry entry;
	bool ret;

	if (cmdSender.sockFD < 0) {
		logError("Error in creating the socket");
		return false;
	}
	ret = cmdSender.sendCommand(msgLoadConfs, entry);
	if (ret == false) {
		logError("Error in receiving the entry");
		return false;
	}
	ret = verifyEntry(userID, entry);
	if (ret == false) {
		logError("Entry does not match the entries in DB");
		return false;
	}
	return true;
}

int main(int argc, char *argv[])
{

	std::string userID;
	uint32_t uID;
	bool ret;
	uint32_t cnt;
	const uint32_t maxCnt = 10;

	// read the arguments <user-name> <ip-address> <up-client or down-client>
	if (argc != 2) {
		logError(argv[0] << " <userID> ");
		return 1;
	}
	userID = argv[1];

	// TODO:: code to check the arguments
	if (false == checkArgs(userID, uID)) {
		logError("Error in the input arguments");
		return 1;
	}
	for (cnt = 0; cnt < maxCnt; cnt = cnt + 1) {
		ret = sendCommand(uID);
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
