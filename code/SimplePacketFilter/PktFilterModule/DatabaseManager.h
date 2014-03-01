#ifndef DATABASEMANAGER_H_
#define DATABASEMANAGER_H_

#include <mysql/mysql.h>
#include <string>

//#define DB_SERVER "snowmane.cs.washington.edu"
//#define DB_SERVER "sounder.cs.washington.edu"
//#define DB_USER "meddle"
//#define DB_PASSWORD "q@847#$6&4@RfbvD"
//#define DB_NAME "MeddleDB"


class DatabaseManager
{
private:
	MYSQL *mysql;
	std::string dbManHostname;
	std::string dbManUser;
	std::string dbManPassword;
	std::string dbManName;
	bool execReadQueryInternal(std::string Query, MYSQL_RES **results);
	bool execWriteQueryInternal(std::string Query);
	bool reconnectDB();
public:
	DatabaseManager();
	~DatabaseManager();
//	bool connectDB();
	bool connectDB(std::string hostname, std::string user, std::string password, std::string dbName);
	bool closeDB();
	bool flushDB();
	bool execReadQuery(std::string Query, MYSQL_RES **results);
	bool execWriteQuery(std::string Query);
};

#endif
