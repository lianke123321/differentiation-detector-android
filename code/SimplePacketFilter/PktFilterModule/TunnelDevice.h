#ifndef TUNNELDEVICE_H_
#define TUNNELDEVICE_H_

#include <stdint.h>
#include <string>
#include <netinet/in.h>
#include <arpa/inet.h>


#include "TunnelFrame.h"

#define DEFAULT_TUNNEL_FLAGS  IFF_TUN
class TunnelDevice {
public:
	uint32_t tunFD;
private:
	std::string deviceName;
	in_addr_t ipAddress;
	in_addr_t netMask;
public:
	TunnelDevice();
	bool createTunnel(std::string deviceName);
	bool assignIP(std::string ipAddress, std::string netMask);
	TunnelFrame * readFrame();
	bool writeFrame(TunnelFrame *frm);
	~TunnelDevice();
};


#endif /* TUNNELDEVICE_H_ */


