
#ifndef MEDDLEDAEMON_H_
#define MEDDLEDAEMON_H_

#include "TunnelDevice.h"
#include "TunnelFrame.h"
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string>

class MeddleDaemon
{
private:
	TunnelDevice tunDevice;

	in_addr_t fwdNet;
	in_addr_t revNet;
	in_addr_t routeMask;
	in_addr_t defaultDnsIP;
	in_addr_t filterDnsIP;
	TunnelFrame *tunFrame;
private:
	in_addr_t __natAddr(const in_addr_t &addr, const in_addr_t &currNet, const in_addr_t &newNet);
	void __processIP();
	void __processTCP();
	void __processUDP();
	void __performNAT();
public:
	MeddleDaemon();
	~MeddleDaemon();
	bool setupTunnel(std::string deviceName, std::string ipAddress, std::string netMask, std::string routeMask, std::string fwdNet, std::string revNet);
	bool setupDNS(std::string defaultDnsIP, std::string filterDnsIP);
	bool mainLoop();
	bool meddleFrame();
};

#endif /* MEDDLEDAEMON_H_ */
