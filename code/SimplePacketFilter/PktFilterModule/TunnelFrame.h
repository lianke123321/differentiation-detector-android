#ifndef TUNNELFRAME_H_
#define TUNNELFRAME_H_

#include <stdint.h> // int8_t uint8_t etc
#include <linux/types.h> // __sum16 etc
#include <linux/if_tun.h>
#include <netinet/if_ether.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include "UserConfigs.h"

struct proxy_iphdr {
	uint32_t saddr;
	uint32_t daddr;
	uint8_t zeros;
	uint8_t protocol;
	uint16_t len;
} __attribute__((packed));

typedef struct proxy_iphdr proxy_iphdr_t;

#define FRAME_PATH_UNKNOWN 0
#define FRAME_PATH_FWD 1
#define FRAME_PATH_REV 2
#define FRAME_PATH_P2P 3 // FWD | REV SET


class TunnelFrame {
public:
	uint32_t frameLen;
	uint8_t* buffer;
	struct tun_pi* tunhdr;
	struct iphdr* ip;
	struct tcphdr* tcp;
	struct udphdr* udp;
	bool validCheckSum;
	uint8_t framePath;
	uint32_t userID; // The user ID for this frame;
	user_config_entry_t configEntry;
private:
	void __fillProxy(proxy_iphdr_t &proxy_hdr, const uint16_t len);
	bool __updateIpChecksum();
	bool __updateTcpChecksum();
	bool __updateUdpChecksum();
	uint32_t __computeSum16(uint8_t *data, const uint32_t len);
	__sum16 __wrapSum16(uint32_t csum);
public:
	TunnelFrame();
	TunnelFrame(uint8_t* payload, const uint32_t len);
	~TunnelFrame();
	uint8_t *getBuffer();
	uint32_t getFrameLen();
	// bool natSource(uint32_t currNet, uint32_t newNet);
	// bool natDestination(uint32_t currNet, uint32_t newNet);
	bool updateChecksum();
};




/* struct tun_pi { */
/*         __u16  flags; */
/*         __be16 proto; */
/* }; */

/* struct iphdr { */
/* #if defined(__LITTLE_ENDIAN_BITFIELD) */
/*         __u8    ihl:4, */
/*                 version:4; */
/* #elif defined (__BIG_ENDIAN_BITFIELD) */
/*         __u8    version:4, */
/*                 ihl:4; */
/* #else */
/* #error  "Please fix <asm/byteorder.h>" */
/* #endif */
/*         __u8    tos; */
/*         __be16  tot_len; */
/*         __be16  id; */
/*         __be16  frag_off; */
/*         __u8    ttl; */
/*         __u8    protocol; */
/*         __sum16 check; */
/*         __be32  saddr; */
/*         __be32  daddr; */
/*         /\*The options start here. *\/ */
/* }; */

/* struct tcphdr { */
/*         __be16  source; */
/*         __be16  dest; */
/*         __be32  seq; */
/*         __be32  ack_seq; */
/* #if defined(__LITTLE_ENDIAN_BITFIELD) */
/*         __u16   res1:4, */
/*                 doff:4, */
/*                 fin:1, */
/*                 syn:1, */
/*                 rst:1, */
/*                 psh:1, */
/*                 ack:1, */
/*                 urg:1, */
/*                 ece:1, */
/*                 cwr:1; */
/* #elif defined(__BIG_ENDIAN_BITFIELD) */
/*         __u16   doff:4, */
/*                 res1:4, */
/*                 cwr:1, */
/*                 ece:1, */
/*                 urg:1, */
/*                 ack:1, */
/*                 psh:1, */
/*                 rst:1, */
/*                 syn:1, */
/*                 fin:1; */
/* #else */
/* #error  "Adjust your <asm/byteorder.h> defines" */
/* #endif */
/*         __be16  window; */
/*         __sum16 check; */
/*         __be16  urg_ptr; */
/* }; */
/* struct udphdr { */
/*         __be16  source; */
/*         __be16  dest; */
/*         __be16  len; */
/*         __sum16 check; */
/* }; */


#endif /* TUNNELFRAME_H_ */
