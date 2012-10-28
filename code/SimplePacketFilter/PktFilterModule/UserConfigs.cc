#include "UserConfigs.h"
#include "Logging.h"
#include <string.h>

UserConfigs::UserConfigs()
{
	// TODO Auto-generated constructor stub

}

UserConfigs::~UserConfigs()
{
	// TODO Auto-generated destructor stub
}

bool UserConfigs::getConfigById(uint32_t userID, user_config_entry_t& entry)
{
	idUserConfigIter=idUserConfigMap.find(userID);
	if (idUserConfigIter != idUserConfigMap.end()) {
		memcpy((void *)(&entry), (void *)(&(idUserConfigIter->second)), sizeof(user_config_entry_t));
		logDebug("Entry in the User Configs for ID " << userID << "  Name:" << entry.userName);
		// entry = idUserConfigIter->second // Should this work!
		return true;
	}
	memset((void *)&entry, 0, sizeof(entry));
	return false;
}

bool UserConfigs::getConfigByName(const std::string& userName, user_config_entry_t& entry)
{
	nameUserConfigIter = nameUserConfigMap.find(userName);
	if (nameUserConfigIter != nameUserConfigMap.end()) {
		entry = nameUserConfigIter->second;
		return true;
	}
	memset((void *)&entry, 0, sizeof(entry));
	return true;
}

// Note this currently duplicates entry for fast access. This can give rise to problems of consistency if delete and add operations fail for one of the two maps.
bool UserConfigs::addEntry(user_config_entry_t& entry)
{
	logError("Attempting to add entry for user " << entry.userName << " with id " << entry.userID);
	insertIDRet = idUserConfigMap.insert(std::make_pair(entry.userID, entry));
	if (insertIDRet.second == false) {
		logInfo("Previous Entry already exists so removing it now");
		idUserConfigMap.erase(entry.userID);
		insertIDRet = idUserConfigMap.insert(std::make_pair(entry.userID, entry));
		if (insertIDRet.second == false) {
			logError("Error inserting an entry to the Map");
			return false;
		}
		logInfo("Succesfully added the entry");
	}

	std::string userName =((char *)(entry.userName)) ;

	insertNameRet = nameUserConfigMap.insert(std::make_pair(userName, entry));
	if (insertIDRet.second == false) {
		logError("Previous Entry already exists so removing it now");
		nameUserConfigMap.erase(userName);
		insertNameRet = nameUserConfigMap.insert(std::make_pair(userName, entry));
		if (insertNameRet.second == false) {
			logError("Error inserting an entry to the Map");
			// TODO:: call for removing
			return false;
		}
		logInfo("Succesfully added the entry");
	}
	return true;
}

// returns true even if entry is not present
bool UserConfigs::removeEntryByID(uint32_t & userID)
{
	user_config_entry_t entry;
	if (false == getConfigById(userID, entry)) {
		logInfo("No point calling this delete because entry does not exist for the user" << userID);
		return true;
	}
	// TODO::error checking to be done;
	std::string userName = ((char *)(entry.userName));
	nameUserConfigMap.erase(userName);
	idUserConfigMap.erase(entry.userID);
	return true;
}

bool UserConfigs::removeEntryByName(std::string &userName)
{
	user_config_entry_t entry;
	if (false == getConfigByName(userName, entry)) {
		logInfo("No point calling this delete because entry does not exist for the user" << userName);
		return true;
	}
	// TODO::error checking to be done;
	nameUserConfigMap.erase(userName);
	idUserConfigMap.erase(entry.userID);
	return true;
}


bool UserConfigs::updateEntry(user_config_entry_t& entry)
{
	return addEntry(entry);
}


bool UserConfigs::getUserIdByName(const std::string& userName, uint32_t &userID)
{
	user_config_entry_t entry;
	if (false == getConfigByName(userName, entry)) {
		logError("Error fetching the entry for userName"<< userName);
		userID = -1;
		return false;
	}
	userID = entry.userID;
	logDebug("User ID for " << userName << " is " << userID);
	return true;
}

std::ostream& operator<<(std::ostream& os, const UserConfigs& userMapTable)
{
	std::map<uint32_t, user_config_entry_t>::const_iterator iter;
	os << "UserConfigMap is as follows:" << std::endl << "-----------" << std::endl;
	for(iter = userMapTable.idUserConfigMap.begin(); iter != userMapTable.idUserConfigMap.end(); iter++)
	{
		user_config_entry_t entry = iter->second;
		os << "| " << entry.userID << " | " << entry.userName << " | " << (uint32_t)(entry.filterAdsAnalytics) << std::endl;
	}
	os << "-----------" << std::endl;
	return os;
}
