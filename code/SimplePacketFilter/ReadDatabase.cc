#include "SimplePacketFilter.h"
#include "DatabaseManager.h"
#include "UserConfigs.h"
#include "Logging.h"
#include <string.h>
#include <mysql/mysql.h>


bool loadUserConfigs()
{
	std::string query = "SELECT userID, userName, filterAdsAnalytics FROM UserConfigs;";
	MYSQL_RES *results;
	MYSQL_ROW row;

	logDebug("Executing query " << query);
	if (false == mainPktFilter.dbManager.execFetchQuery(query, &results)) {
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
		mainPktFilter.userConfigs.addEntry(entry);
	}
	mysql_free_result(results);
	return true;
}


