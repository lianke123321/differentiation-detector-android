#include "SimplePacketFilter.h"
#include "MeddleDaemon.h"
#include "TunnelDevice.h"
#include "TunnelFrame.h"
#include "TunReaderWriter.h"
#include "TunnelFrameQueue.h"
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
	}
	return;
}

inline void MeddleDaemon::__processTCP()
{
	if (FRAME_PATH_FWD == ((tunFrame->framePath) & FRAME_PATH_FWD)) {
		logDebug("Forward path TCP segment");
	}
	if (FRAME_PATH_REV == ((tunFrame->framePath) & FRAME_PATH_REV)) {
		logDebug("Reverse Path TCP segment");
	}
	return;
}

inline void MeddleDaemon::__processUDP()
{
	in_addr_t pktHost;
	static const uint16_t udp_port_dns = htons(53);

	if (FRAME_PATH_FWD == ((tunFrame->framePath) & FRAME_PATH_FWD)) {
		logDebug("Forward path UDP packet with dest port" << ntohs(tunFrame->udp->dest) << " IP " << tunFrame->ip->daddr << " " << this->defaultDnsIP);
		if (((tunFrame->udp->dest) == udp_port_dns) && ((tunFrame->ip->daddr) == (this->defaultDnsIP))) {
			pktHost = tunFrame->ip->saddr;
			mainPktFilter.getUserConfigs(pktHost, tunFrame->userID, tunFrame->configEntry);
			if (tunFrame->configEntry.filterAdsAnalytics) {
				logDebug("The port is of a DNS port and the destination address is of our DNS server. The user has also enabled ad filtering. So redirect it to our filterDNS");
				tunFrame->ip->daddr = this->filterDnsIP;
			}
		}
	}
	if (FRAME_PATH_REV == ((tunFrame->framePath) & FRAME_PATH_REV)) {
		logDebug("Reverse Path UDP packet with source port " << ntohs(tunFrame->udp->source) << " " << tunFrame->ip->saddr << " " << this->filterDnsIP);
		if (((tunFrame->udp->source) == udp_port_dns) && ((tunFrame->ip->saddr) == this->filterDnsIP)) {
			// pktHost =  __natAddr(tunFrame->ip->daddr, revNet, fwdNet);
			// mainPktFilter.getUserConfigs(pktHost, tunFrame->userID, tunFrame->configEntry);
			// if (tunFrame->configEntry.filterAdsAnalytics) {
				logDebug("The packet is coming from a DNS port and from our DNS server when filtering is enabled. Change the IP to the default DNS server");
				tunFrame->ip->saddr = this->defaultDnsIP;
			// }
		}
	}
	return;
}

inline in_addr_t MeddleDaemon::__natAddr(const in_addr_t &addr, const in_addr_t &currNet, const in_addr_t &newNet)
{
	return newNet | (currNet ^ addr);
}

inline void MeddleDaemon::__performNAT()
{
	if (FRAME_PATH_FWD == ((tunFrame->framePath) & FRAME_PATH_FWD)) {
		tunFrame->ip->saddr = __natAddr(tunFrame->ip->saddr, fwdNet, revNet);
	}
	if (FRAME_PATH_REV == ((tunFrame->framePath) & FRAME_PATH_REV)) {
		tunFrame->ip->daddr = __natAddr(tunFrame->ip->daddr, revNet, fwdNet);
	}
	tunFrame->validCheckSum = false;
	return;
}

bool MeddleDaemon::setupDNS(std::string defaultDnsIP, std::string filterDnsIP)
{
	// TODO:: Perform the checks if required.
	this->defaultDnsIP = inet_addr(defaultDnsIP.c_str());
	this->filterDnsIP = inet_addr(filterDnsIP.c_str());
	return true;
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

bool MeddleDaemon::mainLoop()
{
	// Create the reader and writer threads
	// Wait from frames in the reader queue and write to writer queue
	TunnelFrameQueue readerQueue;
	TunnelFrameQueue writerQueue;
	TunReaderWriter tunReader(TUN_RW_READER, &tunDevice, &readerQueue);
	TunReaderWriter tunWriter(TUN_RW_WRITER, &tunDevice, &writerQueue);

	boost::thread readerThread(&TunReaderWriter::mainLoop, &tunReader);

	boost::thread writerThread(&TunReaderWriter::mainLoop, &tunWriter);

	while(1)
	{

		tunFrame = readerQueue.dequeue();
		logDebug("Received a Frame from the reader queue at pointer" <<tunFrame);
		meddleFrame();
		logDebug("Writing a Frame to the writer queue");
		writerQueue.enqueue(tunFrame);
//		logDebug("Waiting for the new Frame");
//		this->tunFrame = NULL;
//		if (NULL == (this->tunFrame = tunDevice.readFrame())) {
//			logError("Error reading Frame");
//			return false;
//		}
//		logDebug("Now Processing the Frame");
//		// Take the lock here
//		this->meddleFrame();
//		// Release the lock here
//		logDebug("Now Writing the Frame")
//		if (false == tunDevice.writeFrame(this->tunFrame)) {
//			logError("Error writing frame");
//			return false;
//		}
//		logDebug("Deleting the Frame");
//		delete tunFrame;
	}
	return true;
}

