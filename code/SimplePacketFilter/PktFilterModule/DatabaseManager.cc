#include "DatabaseManager.h"
#include "Logging.h"
#include <string>
#include <mysql/mysql.h>

DatabaseManager::DatabaseManager()
{
	// TODO Auto-generated constructor stub
	mysql = mysql_init(NULL);
}

DatabaseManager::~DatabaseManager()
{
	// TODO Auto-generated destructor stub
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

bool DatabaseManager::execFetchQuery(std::string query, MYSQL_RES **results)
{
	if (mysql_real_query(mysql, query.c_str(), query.length()) > 0) {
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





