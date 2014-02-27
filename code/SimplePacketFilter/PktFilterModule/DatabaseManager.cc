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
	dbManHostname = hostname;
	dbManUser = user;
	dbManPassword = password;
	dbManName = dbName;
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
	mysql_close(mysql);
	return true;
}


bool DatabaseManager::reconnectDB()
{
	// TODO:: code to close the DB comes here
	uint32_t cnt = 0;
	mysql_close(mysql);
	mysql = mysql_init(NULL);
	while (cnt < 3) {	
		if (true == connectDB(dbManHostname, dbManUser, dbManPassword, dbManName)) {
			return true;
		}
		cnt = cnt + 1;
		logError("Retrying to reconnect " << cnt);		
	}
	logError("Reconnect Failed");
	return false;
}

bool DatabaseManager::flushDB()
{
	mysql_commit(mysql);
	return true;
}

bool DatabaseManager::execReadQuery(std::string query, MYSQL_RES **results)
{
	uint32_t cnt = 0;
	while (cnt < 3) {
		if (true== execReadQueryInternal(query, results)) {
			return true;
		}
		cnt = cnt + 1;
		logError("Error in executing query, so trying to reconnect");
		reconnectDB();
	}
	return false;
}

bool DatabaseManager::execWriteQuery(std::string query)
{
	uint32_t cnt = 0;
	while (cnt < 3) {
		if (true== execWriteQueryInternal(query)) {
			return true;
		}
		cnt = cnt + 1;
		logError("Error in executing query, so trying to reconnect");
		reconnectDB();
	}
	return false;
}


bool DatabaseManager::execReadQueryInternal(std::string query, MYSQL_RES **results)
{
	uint32_t cnt = 0;
	logDebug("Executing the query"<<query);
	while(cnt < 3) {
		cnt = cnt + 1;
		if (0 != mysql_real_query(mysql, query.c_str(), query.length())) {
			logError("Error : " <<  mysql_error(mysql) << " :when executing the query: " << query << " Retrying again" << cnt);
		} else {
			cnt = 0;
			break;
		}
	}
	if (0 != cnt ) {
		logError("Error executing the query hence returning false");
		return false;
	}
	logDebug("Now Fetching the results");
	// mysql_use_result if you want to do per row fetch. This one is a bit slower;
	*results = mysql_store_result(mysql);
	if (*results == NULL) {
		logDebug("No results for query" << query);
		return false;
	}
	logDebug("Fetched results with " << (*results)->row_count << " counts");
	return true;
}

bool DatabaseManager::execWriteQueryInternal(std::string query)
{
	uint32_t cnt=0;
	logDebug("Executing the query" << query);
	while (cnt<3) { // At most 3 retries
		if (0 ==  mysql_real_query(mysql, query.c_str(), query.length())) {
			return true;
		}
		logError("Error " <<  mysql_error(mysql) << " executing the query: " << query << " Retrying again" << cnt);
		cnt = cnt + 1;
	}
	return false;
}




