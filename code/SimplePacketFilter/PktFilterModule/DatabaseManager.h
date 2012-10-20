#ifndef DATABASEMANAGER_H_
#define DATABASEMANAGER_H_

#include <mysql/mysql.h>
#include <string>


class DatabaseManager
{
private:
	MYSQL *mysql;
public:
	DatabaseManager();
	~DatabaseManager();
	bool connectDB(std::string hostname, std::string user, std::string password, std::string dbName);
	bool closeDB();
	bool flushDB();
	bool execReadQuery(std::string Query, MYSQL_RES **results);
	bool execWriteQuery(std::string Query);
};

#endif
