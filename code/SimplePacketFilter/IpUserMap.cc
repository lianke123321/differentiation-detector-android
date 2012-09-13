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
	insertRet = ipMap.insert(std::make_pair(ipAddress, userID));
	if (insertRet.second == false) {
		ipMap.erase(ipAddress);
		insertRet = ipMap.insert(std::make_pair(ipAddress, userID));
		if (insertRet.second == false) {
			logError("Error inserting an entry to the Map")
			return false;
		}
	}
	return true;
}

bool IpUserMap::removeEntry(in_addr_t ipAddress)
{
	mapIter=ipMap.find(ipAddress);
	if (mapIter != ipMap.end()) {
		ipMap.erase (mapIter);
	}
	return true;
}
