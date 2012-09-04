
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
	TunnelFrame *tunFrame;
private:
	void __natSrc(in_addr_t currNet, in_addr_t newNet);
	void __natDst(in_addr_t currNet, in_addr_t newNet);
	void __processIP();
	void __processTCP();
	void __processUDP();
public:
	MeddleDaemon();
	~MeddleDaemon();
	bool Setup(std::string deviceName, std::string ipAddress, std::string netMask, std::string routeMask, std::string fwdNet, std::string revNet);
	bool ReadWriteLoop();
	bool ProcessFrame();

};

#endif /* MEDDLEDAEMON_H_ */
