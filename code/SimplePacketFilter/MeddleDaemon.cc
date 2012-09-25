#include "SimplePacketFilter.h"
#include "MeddleDaemon.h"
#include "TunnelDevice.h"
#include "TunnelFrame.h"
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <string>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <iostream>
#include "Logging.h"
 #include <sys/select.h>

MeddleDaemon::MeddleDaemon()
{
	tunFrame = NULL;
	return;
}


MeddleDaemon::~MeddleDaemon()
{
	// Assume that the tunFrame has been deleted;
	tunFrame = NULL;
	return;
}

bool MeddleDaemon:: setupTunnel(std::string deviceName, std::string ipAddress, std::string netMask, std::string routeMask, std::string fwdNet, std::string revNet)
{
	logDebug("Creating Tunnel")
	if (false == tunDevice.createTunnel(deviceName)) {
		return false;
	}
	logDebug("Assigning IP address to the Tunnel")
	if (false == tunDevice.assignIP(ipAddress, netMask)) {
		return false;
	}
	logDebug("Assigning masks for forward and reverse paths")
	this->routeMask = inet_addr(routeMask.c_str());
	this->fwdNet = inet_addr(fwdNet.c_str());
	this->revNet = inet_addr(revNet.c_str());

	return true;
}

inline void MeddleDaemon::__processIP()
{
	if (((tunFrame->ip->saddr) & routeMask) == fwdNet) {
		logDebug("Frame in Forward Path");
		tunFrame->framePath = tunFrame->framePath | FRAME_PATH_FWD;

	}
	if (((tunFrame->ip->daddr) & routeMask) == revNet) {
		logDebug("Frame in Reverse Path");
		tunFrame->framePath = tunFrame->framePath | FRAME_PATH_REV;
		// in_addr_t orig_addr = __natAddr(tunFrame->ip->daddr, revNet, fwdNet);
	}
	return;
}

inline void MeddleDaemon::__processTCP()
{
	if (tunFrame->framePath & FRAME_PATH_FWD == FRAME_PATH_FWD) {
		logDebug("Forward path TCP segment");
	}
	if (tunFrame->framePath & FRAME_PATH_REV == FRAME_PATH_REV) {
		logDebug("Reverse Path TCP segment");
	}
	return;
}

inline void MeddleDaemon::__processUDP()
{
	if (tunFrame->framePath & FRAME_PATH_FWD == FRAME_PATH_FWD) {
		logDebug("Forward path UDP packet");
	}
	if (tunFrame->framePath & FRAME_PATH_REV == FRAME_PATH_REV) {
		logDebug("Reverse Path UDP packet");
	}
	return;
}

inline in_addr_t MeddleDaemon::__natAddr(const in_addr_t &addr, const in_addr_t &currNet, const in_addr_t &newNet)
{
	return newNet | (currNet ^ addr);
}

inline void MeddleDaemon::__performNAT()
{
	if (FRAME_PATH_FWD == (tunFrame->framePath & FRAME_PATH_FWD)) {
		tunFrame->ip->saddr = __natAddr(tunFrame->ip->saddr, fwdNet, revNet);
	}
	if (FRAME_PATH_REV == (tunFrame->framePath & FRAME_PATH_REV)) {
		tunFrame->ip->daddr = __natAddr(tunFrame->ip->daddr, revNet, fwdNet);
	}
	tunFrame->validCheckSum = false;
	return;
}

inline bool MeddleDaemon::meddleFrame()
{
	uint8_t *buffer = tunFrame->buffer;
	tunFrame->tunhdr = (struct tun_pi *)(buffer);
	if (ETH_P_IP == (ntohs(tunFrame->tunhdr->proto))) {
		tunFrame->ip = (struct iphdr *) (((uint8_t *)buffer) + sizeof(struct tun_pi));
		__processIP();
		switch(tunFrame->ip->protocol) {
		case IPPROTO_TCP:
			tunFrame->tcp = (struct tcphdr *) (((uint8_t *)(tunFrame->ip)) + ((tunFrame->ip->ihl)*4));
			__processTCP();
			break;
		case IPPROTO_UDP:
			tunFrame->udp = (struct udphdr *) (((uint8_t *)(tunFrame->ip)) + ((tunFrame->ip->ihl)*4));
			__processUDP();
			break;
		default:
			break;
		}
		__performNAT();
		tunFrame->updateChecksum();
	}
	return true;
}



//inline void MeddleDaemon::__natSrc(in_addr_t currNet, in_addr_t newNet)
//{
//	// TODO:: Verify if you really need to do everything with htonl and ntohl
//	in_addr_t srcaddr = tunFrame->ip->saddr;
//	srcaddr = newNet | (currNet ^ srcaddr);
//	tunFrame->ip->saddr = srcaddr;
//	// TODO::
//	// Fast update checksum based on IP change only
//	tunFrame->validCheckSum = false;
//	return;
//}

//inline void MeddleDaemon::__natDst(in_addr_t currNet,  in_addr_t newNet)
//{
//	in_addr_t dstaddr = tunFrame->ip->daddr;
//	dstaddr = newNet | (currNet ^ dstaddr);
//	tunFrame->ip->daddr = dstaddr;
//	// TODO:: Fast update checksum based on IP change only
//	tunFrame->validCheckSum = false;
//	return;
//}

bool MeddleDaemon::mainLoop()
{
	while(1)
	{
		logDebug("Waiting for the new Frame");
		this->tunFrame = NULL;
		if (NULL == (this->tunFrame = tunDevice.readFrame())) {
			logError("Error reading Frame");
			return false;
		}
		logDebug("Now Processing the Frame");
		// Take the lock here
		this->meddleFrame();
		// Release the lock here
		logDebug("Now Writing the Frame")
		if (false == tunDevice.writeFrame(this->tunFrame)) {
			logError("Error writing frame");
			return false;
		}
		logDebug("Deleting the Frame");
		delete tunFrame;
	}
	return true;
}

