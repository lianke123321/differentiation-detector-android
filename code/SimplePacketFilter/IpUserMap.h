#ifndef USERIPMAP_H_
#define USERIPMAP_H_

#include <netinet/in.h>
#include <arpa/inet.h>
#include <map>
#include <utility>

class IpUserMap {
private:
	// Map between the IP address and the UserID
	std::map<in_addr_t, uint32_t> ipMap;
	std::map<in_addr_t, uint32_t>::iterator mapIter;
	std::pair<std::map<in_addr_t, uint32_t>::iterator, bool> insertRet;
public:
	IpUserMap();
	~IpUserMap();
	bool getUserID(in_addr_t ipAddress, uint32_t &userID);
	bool addEntry(in_addr_t ipAddress, uint32_t userID);
	bool removeEntry(in_addr_t ipAddress);
};

#endif /* USERIPMAP_H_ */

