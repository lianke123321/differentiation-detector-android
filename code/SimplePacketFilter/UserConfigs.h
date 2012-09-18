#ifndef USERCONFIGS_H_
#define USERCONFIGS_H_

#include <stdint.h>
#include <map>
#include <utility>
#include <string>
#include <iostream>

#define USERNAMELEN 512
//TODO:: use the same as in the commands between the external process

struct user_config_entry {
	int8_t userName[USERNAMELEN];
	uint32_t userID;
	int8_t filterAdsAnalytics;
};

typedef struct user_config_entry user_config_entry_t;

class UserConfigs
{
protected:
	std::map<uint32_t, user_config_entry_t> idUserConfigMap;
	std::map<uint32_t, user_config_entry_t>::iterator idUserConfigIter;
	std::pair<std::map<uint32_t, user_config_entry_t>::iterator, bool> insertIDRet;

	std::map<std::string, user_config_entry_t> nameUserConfigMap;
	std::map<std::string, user_config_entry_t>::iterator nameUserConfigIter;
	std::pair<std::map<std::string, user_config_entry_t>::iterator, bool> insertNameRet;

	// More columns based on the user configs
public:
	UserConfigs();
	~UserConfigs();
	bool getConfigById(uint32_t userID, user_config_entry_t &entry);
	bool getConfigByName(std::string &userName, user_config_entry_t &entry);\
	bool addEntry(user_config_entry_t &entry);
	bool deleteEntryByID(uint32_t userID);
	bool getUserIdByName(std::string &userName, uint32_t &userID);
	bool updateEntry(user_config_entry_t &entry); // userID and userName is not modified, other entries are modified.
	friend std::ostream& operator<<(std::ostream& os, const UserConfigs& userConfig);
};

#endif /* USERCONFIGS_H_ */
