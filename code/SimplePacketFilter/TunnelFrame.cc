#include "TunnelFrame.h"
#include <string.h>
#include "Logging.h"

TunnelFrame::TunnelFrame()
{
	buffer = NULL; frameLen = 0; tunhdr = NULL; ip = NULL; tcp = NULL; udp = NULL;
	validCheckSum = false;
	framePath = FRAME_PATH_UNKNOWN;
	return;
}

TunnelFrame::~TunnelFrame()
{
	if (frameLen > 0 && NULL != buffer) {
		delete buffer;
	}
	buffer = NULL;frameLen = 0;tunhdr = NULL;ip = NULL; tcp = NULL;udp = NULL;
	validCheckSum = false;
	framePath = FRAME_PATH_UNKNOWN;
	return;
}

TunnelFrame::TunnelFrame(uint8_t *payload, uint32_t len)
{
	buffer = new uint8_t[len];
	frameLen = len;
	if (NULL == buffer) {
		logError("Error allocation memory for the buffer");
		return;
	}
	memcpy(buffer, payload, len);
	validCheckSum = true;

//	tunhdr = (struct tun_pi *)buffer;
//	if (tunhdr->proto == ETH_P_IP) {
//		ip = (struct iphdr *) ((uint8_t *)buffer + sizeof(struct tun_pi));
//		switch(ip->protocol) {
//		case IPPROTO_TCP:
//			tcp = (struct tcphdr *) ((uint8_t *)ip + (ip->ihl)*4);
//			break;
//		case IPPROTO_UDP:
//			udp = (struct udphdr *) ((uint8_t *)ip + (ip->ihl)*4);
//			break;
//		default:
//			break;
//
//		}
//	}
}


/*
 * Based on page 6 http://tools.ietf.org/rfc/rfc1071.txt
 * Wrap the sum to 16 bits and take its complement
 */
inline __sum16 TunnelFrame::__wrapSum16(uint32_t csum)
{
        __sum16 ret;
        while (csum>>16)
                csum = (csum & 0xffff) + (csum >> 16);
        csum = ~csum;
        ret = csum &0xffff;
        return ret;
}

/*
 * Based on page 6 http://tools.ietf.org/rfc/rfc1071.txt
 * Sum the bytes and account for padding
 */
inline uint32_t TunnelFrame::__computeSum16(uint8_t *data, uint32_t len)
{
	uint32_t sum, cnt;
	uint16_t *ptr;

	union {
	        uint16_t pad16;
	        uint8_t byte[2];
	} padding;

	ptr = (uint16_t*)data;
	cnt = 0;
	sum = 0;
	if (len > 1) {
         while (cnt < len/2) {
                 sum = sum + ptr[cnt];
                 cnt = cnt+1;
         }
	}

	if (len%2 != 0) {
         padding.byte[0] = data[len-1];
         padding.byte[1] = 0;
         sum += padding.pad16;
	}
	return sum;
}

inline void TunnelFrame::__fillProxy(proxy_iphdr_t *proxy_hdr, uint16_t len)
{
	memset(proxy_hdr, 0, sizeof(proxy_iphdr_t));
	proxy_hdr->saddr = ip->saddr;
	proxy_hdr->daddr = ip->daddr;
	proxy_hdr->protocol = ip->protocol;
	proxy_hdr->len = len;
}

/*
 * Update the tcp checksum
 */
inline bool TunnelFrame::__updateTcpChecksum()
{
	proxy_iphdr_t proxy;
	__sum16 final_sum;
	uint32_t new_sum = 0;
	uint16_t tcplen = ntohs(ip->tot_len) - (ip->ihl)*4;

	tcp->check = (__sum16)0;
	new_sum = new_sum + __computeSum16((uint8_t *)tcp, tcplen);
	__fillProxy(&proxy, htons(tcplen));
	new_sum = new_sum + __computeSum16((uint8_t *)&proxy, sizeof(proxy_iphdr_t));
	final_sum = __wrapSum16(new_sum);
	tcp->check = final_sum;
	return true;
}

inline bool TunnelFrame:: __updateUdpChecksum()
{
	proxy_iphdr_t proxy;
	__sum16 final_sum;
	uint32_t new_sum = 0;

	udp->check = (__sum16)0;
	new_sum = __computeSum16((uint8_t *)udp, ntohs(udp->len));
	__fillProxy(&proxy, udp->len);
	new_sum = new_sum + __computeSum16((uint8_t *)&proxy, sizeof(proxy_iphdr_t));
 	final_sum = __wrapSum16(new_sum);
	udp->check = final_sum;
	return true;
}

/*
 * Update the IP checksum
 */
inline bool TunnelFrame::__updateIpChecksum()
{
	__sum16 final_sum;
	uint32_t new_sum;
	ip->check = (__sum16)0;
	new_sum = __computeSum16((uint8_t *)ip, ((ip->ihl)*4));
	final_sum = __wrapSum16(new_sum);
	ip->check = final_sum;
	return true;
}

bool TunnelFrame::updateChecksum()
{
	// TODO:: Check if checksum is valid -- make sure all paths invalidate checksum if they modify some portion of header
	switch (ip->protocol) {
	case IPPROTO_TCP:
		logDebug("TCP Checksum");
		__updateTcpChecksum();
		break;
	case IPPROTO_UDP:
		logDebug("UDP Checksum");
		__updateUdpChecksum();
		break;
	default:
		break;
	}
	logDebug("IP Checksum");
	__updateIpChecksum();
	validCheckSum = true;
	return true;
}

