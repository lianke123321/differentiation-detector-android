#include "DatabaseManager.h"
#include "Logging.h"
#include <string>
#include <stdint.h>
#include <mysql/mysql.h>

DatabaseManager::DatabaseManager()
{
	mysql = mysql_init(NULL);
}

DatabaseManager::~DatabaseManager()
{
	delete mysql;
}

bool DatabaseManager::connectDB(std::string hostname, std::string user, std::string password, std::string dbName)
{
	if (!mysql_real_connect(mysql, hostname.c_str(), user.c_str(), password.c_str(), dbName.c_str(), 0, NULL, 0))
	{
		logError("Failed to connect to database: Error:"<< mysql_error(mysql));
		return false;
	}
	// mysql_real_connect(connect,SERVER,USER,PASSWORD,DATABASE,0,NULL,0);
	return true;
}

//bool DatabaseManager::connectDB()
//{
//	return connectDB(DB_SERVER, DB_USER, DB_PASSWORD, DB_NAME);
//}
bool DatabaseManager::closeDB()
{
	// TODO:: code to close the DB comes here
	return true;
}

bool DatabaseManager::flushDB()
{
	// mysql_commit(mysql);
	return true;
}

bool DatabaseManager::execReadQuery(std::string query, MYSQL_RES **results)
{
	logDebug("Executing the query"<<query);
	if (0 != mysql_real_query(mysql, query.c_str(), query.length())) {
		logError("Error executing the query");
		return false;
	}
	logDebug("Now Fetching the results");
	// mysql_use_result if you want to do per row fetch. This one is a bit slower;
	*results = mysql_store_result(mysql);
	if (*results == NULL) {
		logDebug("No results");
		return false;
	}
	logDebug("Fetched results with " << (*results)->row_count << " counts");
	return true;
}

bool DatabaseManager::execWriteQuery(std::string query)
{
	uint32_t cnt=0;
	logDebug("Executing the query" << query);
	while (cnt<5) { // At most 5 retries
		if (0 == mysql_real_query(mysql, query.c_str(), query.length())) {
			return true;
		}
		logError("Error executing the query; Retyring again" << query);
		cnt = cnt + 1;
	}
	return false;
}




