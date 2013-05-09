#ifndef TUNNELDEVICE_H_
#define TUNNELDEVICE_H_

#include <stdint.h>
#include <string>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "TunnelFrame.h"
#include <sys/select.h>

#define DEFAULT_TUNNEL_FLAGS  IFF_TUN
// Separate class to act like a wrapper for read writes.
class TunnelDevice {
public:
	uint32_t tunFD;
	uint32_t wFD;
	// wFD duplicate of the tunFD used for writing; we change this when we decide to write on another descriptor
	uint8_t readBuffer[1<<16];
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


