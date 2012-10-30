#ifndef DATABASEMANAGER_H_
#define DATABASEMANAGER_H_

#include <mysql/mysql.h>
#include <string>

//#define DB_SERVER "snowmane.cs.washington.edu"
#define DB_SERVER "community.dyn.cs.washington.edu"
#define DB_USER "meddle"
#define DB_PASSWORD "meddle"
#define DB_NAME "MeddleDB"


class DatabaseManager
{
private:
	MYSQL *mysql;
public:
	DatabaseManager();
	~DatabaseManager();
	bool connectDB();
	bool connectDB(std::string hostname, std::string user, std::string password, std::string dbName);
	bool closeDB();
	bool flushDB();
	bool execReadQuery(std::string Query, MYSQL_RES **results);
	bool execWriteQuery(std::string Query);
};

#endif
