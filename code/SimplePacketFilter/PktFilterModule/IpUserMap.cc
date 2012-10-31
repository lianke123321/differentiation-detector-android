#include <stdint.h>
#include <stdio.h>
#include "Logging.h"
#include "IpUserMap.h"
#include <string.h>


IpUserMap::IpUserMap()
{
	ipMap.clear();
}

IpUserMap::~IpUserMap()
{
	ipMap.clear();
}

bool IpUserMap::getUserID(in_addr_t ipAddress, uint32_t &userID)
{
	mapIter=ipMap.find(ipAddress);
	if (mapIter != ipMap.end()) {
		userID = mapIter->second;
		return true;
	}
	userID = 0;
	return false;
}

bool IpUserMap::addEntry(in_addr_t ipAddress, uint32_t userID)
{
	logDebug("Attempting to associate " << userID << " to IP address " << ipAddress);
	insertRet = ipMap.insert(std::make_pair(ipAddress, userID));
	if (insertRet.second == false) {
		logDebug("Previous Entry already exists so removing it now");
		ipMap.erase(ipAddress);
		insertRet = ipMap.insert(std::make_pair(ipAddress, userID));
		if (insertRet.second == false) {
			logError("Error inserting an entry to the Map");
			return false;
		}
	}
	logDebug("Successful in adding the association");
	return true;
}

bool IpUserMap::removeEntry(in_addr_t ipAddress)
{
	// Note: No check is being performed to check if it is the mapping we want to remove
	logDebug("Removing the association for the ipAddress " << ipAddress << " First seeing if it exists");
	mapIter=ipMap.find(ipAddress);
	if (mapIter != ipMap.end()) {
		logDebug("Entry for " << ipAddress << " exists so removing it ");
		ipMap.erase (mapIter);
		mapIter=ipMap.find(ipAddress);
		if (mapIter != ipMap.end()) {
			logError("Error removing the association for IP" << ipAddress);
			return false;
		}
	}
	return true;
}

std::ostream& operator<<(std::ostream& os, const IpUserMap& ipMapTable)
{
	std::map<in_addr_t, uint32_t>::const_iterator iter;
	os << "IpUserTableMap is as follows:" << std::endl << "-----------" << std::endl;
	for(iter = ipMapTable.ipMap.begin(); iter != ipMapTable.ipMap.end(); iter++)
	{
		os << "| " << iter->first << " | " << iter->second << " | " << std::endl;
	}
	os << "-----------" << std::endl;
	return os;
}
