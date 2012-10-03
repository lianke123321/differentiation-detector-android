#include "TunnelDevice.h"
#include "TunnelFrame.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <string.h>
#include <linux/if.h>
#include <linux/if_tun.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include "Logging.h"
#include "Macros.h"

TunnelDevice::TunnelDevice()
{
	tunFD = 0;
}
TunnelDevice::~TunnelDevice()
{
	close (tunFD);
}

bool TunnelDevice::createTunnel(std::string deviceName)
{
	struct ifreq ifr;
	uint32_t fd, err;
	const uint8_t clonedev[] = "/dev/net/tun";
	const uint32_t flags = IFF_TUN; /* The entire packet processing begins by assuming the device is a TUN device */

	if( (fd = open((char *)clonedev, O_RDWR)) < 0 ) {
		logError("Error opening the clone device");
		return false;
	}
	memset(&ifr, 0, sizeof(ifr));
	ifr.ifr_flags = flags;   /* IFF_TUN or IFF_TAP, plus maybe IFF_NO_PI */
	strncpy(ifr.ifr_name, deviceName.c_str(), IFNAMSIZ);
	/* NOTE::  even if the tunnel device is already created and is set to persistent
	 * we can still use the TUNSETIFF to get write access to this interface
	 * TODO:: What if more than one program are reading from this interface
	 * Who will be the master??
	 */
	err = ioctl(fd, TUNSETIFF, (void *) &ifr);
	if( err < 0 ) {
		logError("Error using TUNSETIFF");
		close(fd);
		return false;
	}
	this->deviceName = ifr.ifr_name;
	this->tunFD = fd;
	this->wFD = dup(fd); // Writing on this file descriptor
	logDebug("Created the device");
	return true;
}

bool TunnelDevice::assignIP(std::string ip_address, std::string netmask)
{
	struct ifreq ifr;
	struct sockaddr_in sai;
	uint32_t sockfd;
	char *p;

	/* Create a channel to the NET kernel. */
	sockfd = socket(AF_INET, SOCK_DGRAM, 0);
	if (sockfd < 0 ) {
		logError("Error opening the socket for assigning the IP address");
		return false;
	}
	logDebug ("Opened socket for assigning IP");
	/* use the given interface/device name */
	strncpy(ifr.ifr_name, this->deviceName.c_str(), IFNAMSIZ);

	memset(&sai, 0, sizeof(struct sockaddr));
	sai.sin_family = AF_INET;
	sai.sin_port = 0;
	sai.sin_addr.s_addr = inet_addr(ip_address.c_str());
	this->ipAddress = sai.sin_addr.s_addr;
	p = (char *) &sai;
	memcpy(&ifr.ifr_addr, p, sizeof(struct sockaddr));
	logDebug ("Perform IOCTL");
	/* assign the ip address */
	if (ioctl(sockfd, SIOCSIFADDR, &ifr) < 0) {
		logError("Error assigning the IP address using ioctl");
		close(sockfd);
		return false;
	}

	/*
	 * TODO:: This typically requires ROOT access. May not require ROOT access if the device is assigned for the user
	 * I have not tested for devices created by root for users other than root
	 */

	logDebug ("Set the IP address using IOCTL");
	/* Mark the device as up and running */
	if (ioctl(sockfd, SIOCGIFFLAGS, &ifr) < 0) {
		close(sockfd);
		return false;
	}

	strncpy(ifr.ifr_name, this->deviceName.c_str(), IFNAMSIZ);
	ifr.ifr_flags |= IFF_UP | IFF_RUNNING;
	/* ifr.ifr_flags &= ~selector;  How to unset some flag */
	if (ioctl(sockfd, SIOCSIFFLAGS, &ifr) <0 ) {
		logError("Error setting the tun device as UP and RUNNING");
		close(sockfd);
		return false;
	}

	/* Assign a netmask */
	sai.sin_family = AF_INET;
	sai.sin_port = 0;
	sai.sin_addr.s_addr = inet_addr(netmask.c_str());
	p = (char *) &sai;
	memcpy(&ifr.ifr_netmask, p, sizeof(struct sockaddr));
	if (ioctl(sockfd, SIOCSIFNETMASK, &ifr) <0) {
		logError("Error performing ioctl to assign the netmask");
		close(sockfd);
		return false;
	}
	this->netMask = sai.sin_addr.s_addr;

	close(sockfd);
	return true;
}

// Assumes tunFrame is NULL
TunnelFrame * TunnelDevice::readFrame()
{
	TunnelFrame *tunFrame = NULL;
	 // FOR TSO MAX FRAME SIZE OF 16k thanks to tcp over ipv4
	logDebug("Performing the read operation");
	uint32_t nread = read(tunFD,readBuffer,sizeof(readBuffer));
	if (nread == 0) {
		logError("Error reading the frame");
		return NULL;
	}
	logDebug("Read a frame, now creating the tun Frame")
	tunFrame = new TunnelFrame(readBuffer, nread);
	logDebug("Created the tunFrame");
	return tunFrame;
}

// ASsu
bool TunnelDevice::writeFrame(TunnelFrame *tunFrame)
{
	logDebug("Writing a frame now");
	uint32_t nwrite = write(wFD, tunFrame->buffer, tunFrame->frameLen);
	if (nwrite != tunFrame->frameLen) {
		logError("Unable to the writeLen")
		return false;
	}
	logDebug("Wrote a frame");
	return true;
}




