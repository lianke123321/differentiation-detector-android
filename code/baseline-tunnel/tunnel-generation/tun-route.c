#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <linux/if.h>
#include <linux/ip.h>
#include <linux/if_tun.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <netpacket/packet.h>
#include <net/ethernet.h>
#include <net/route.h>
#include <linux/sockios.h>
#include <linux/if_ether.h>
#include <linux/if_tun.h>
#include <arpa/inet.h>
#include <time.h>
#include <linux/tcp.h>
#include <linux/udp.h>


#define max(a,b) (a > b ? a : b)


/**
 * Create the tunnel device
 * dev_name : The name of the device
 * flags : flags to be used during creation
 */
int tun_alloc(char *dev_name, int flags)
{
	struct ifreq ifr;
	int fd, err;
	char *clonedev = "/dev/net/tun";

	if( (fd = open(clonedev, O_RDWR)) < 0 ) {
		perror("Error opening clone device to create taps");
		return fd;
	}

	memset(&ifr, 0, sizeof(ifr));

	ifr.ifr_flags = flags;   /* IFF_TUN or IFF_TAP, plus maybe IFF_NO_PI */

	strncpy(ifr.ifr_name, dev_name, IFNAMSIZ);

	err = ioctl(fd, TUNSETIFF, (void *) &ifr);
	if( err < 0 ) {
		perror("TUNSETIFF");
		close(fd);
		return err;
	}
	/* use TUNSETPERSIST to create a persistent device that will exist even if the program exits */
	/* err = ioctl(fd, TUNSETPERSIST, 1); */
        /* if( err < 0 ) { */
        /*      perror("TUNSETPERSIST"); */
        /*      close(fd); */
        /*      return err; */
        /* } */
	
	strcpy(dev_name, ifr.ifr_name);
	return fd;
}

/**
 * Assign an ip address and netmask to a given device
 * dev_name : The name of the device
 * ip_address : flags to be used during creation
 * netmask : 
 */
int ip_alloc(char *dev_name, char *ip_address, char *netmask)
{
        struct ifreq ifr;
        struct sockaddr_in sai;
        int sockfd;                     /* socket fd we use to manipulate stuff with */

        char *p;

        /* Create a channel to the NET kernel. */
        sockfd = socket(AF_INET, SOCK_DGRAM, 0);

        /* use the given interface/device name */
        strncpy(ifr.ifr_name, dev_name, IFNAMSIZ);

        memset(&sai, 0, sizeof(struct sockaddr));
        sai.sin_family = AF_INET;
        sai.sin_port = 0;
        sai.sin_addr.s_addr = inet_addr(ip_address);
        p = (char *) &sai;
	memcpy(&ifr.ifr_addr, p, sizeof(struct sockaddr));	

	 /* assign the ip address */
        if (ioctl(sockfd, SIOCSIFADDR, &ifr) < 0) {
		perror("SIOCSIFADDR");
		return -1;
	}
	/* Mark the device as up and running */
	if (ioctl(sockfd, SIOCGIFFLAGS, &ifr) < 0) {
		perror("SIOCSIFFLAGS");
		return -1;				
	}

	strncpy(ifr.ifr_name, dev_name, IFNAMSIZ);
        ifr.ifr_flags |= IFF_UP | IFF_RUNNING;
        /* ifr.ifr_flags &= ~selector;  How to unset some flag */
	if (ioctl(sockfd, SIOCSIFFLAGS, &ifr) <0 ) {
		perror("SIOCSIFFLAGS");
		return -1;		
	}
	
	/* Assign a netmask */
        sai.sin_family = AF_INET;
        sai.sin_port = 0;
        sai.sin_addr.s_addr = inet_addr(netmask);
	p = (char *) &sai;
	memcpy(&ifr.ifr_netmask, p, sizeof(struct sockaddr));	
	if (ioctl(sockfd, SIOCSIFNETMASK, &ifr) <0) {
		perror("SIOCSIFNETMASK");
		return -1;
	}
        close(sockfd);	
	return 0;
	
}


/**
 * See kernel/Documentation/networking/tuntap.txt
 * Each frame passed on can optionally have this header.
 * This header is useful to determine the layer 3 protocol (IPv4/IPv6/ARP/etc)
 */
struct tap_hdr {
	__be16          flags;
	__be16          proto;	
}__attribute__((packed));
typedef struct tap_hdr tap_hdr_t;



/**
 * Based on page 6 http://tools.ietf.org/rfc/rfc1071.txt
 * Wrap the sum to 16 bits and take its complement
 */
inline __sum16 wrap_sum16(__u32 csum)
{
	__sum16 ret; 
	while (csum>>16) 
		csum = (csum & 0xffff) + (csum >> 16);
 	csum = ~csum;
 	ret = csum &0xffff;
	return ret;
}

/**
 * Based on page 6 http://tools.ietf.org/rfc/rfc1071.txt
 * Sum the bytes and account for padding
 */
inline __u32 compute_sum16(__u8 *data, __u32 len)
{
	__u32 sum;
	__u16 *ptr, cnt;
	
	union {
	        __u16 pad16;
	        __u8 byte[2];
	} padding;
	
	ptr = (__u16*)data;
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

/****/
/** Based on page 6 http://tools.ietf.org/rfc/rfc1071.txt */
/* int ip_checksum(struct iphdr *ip) */
/* { */
/* 	__u16 hlen, *ptr, cnt; */
/* 	__u32 csum; */
/*         __u16 old_sum;     */
/* 	hlen = (ip->ihl)<<1; // num of 32 bit to num of 16 bit */
/* 	old_sum = ip->check;	 */
/* 	ip->check = (__sum16)0; */
/* 	csum = 0; */
/* 	ptr = (__u16 *)ip; */
/* 	cnt = 0; */
/* 	while (cnt < hlen) { */
/* 		csum = csum+ptr[cnt]; */
/* 		cnt = cnt + 1;			 */
/* 	} */
/* 	while (csum>>16) */
/*            csum = (csum & 0xffff) + (csum >> 16); */
/* 	csum = ~csum; */
/* 	csum = csum &0xffff; */
/* 	ip->check = (__sum16)csum; */
/* 	printf("Old csum:%x new:%x\n", old_sum, ip->check); */
/* 	return 0; */
/* } */

struct proxy_iphdr {
	__u32 saddr;
	__u32 daddr;
	__u8 zeros;
	__u8 protocol;
	__u16 len;
} __attribute__((packed));

typedef struct proxy_iphdr proxy_iphdr_t;

/**
 * Fill the proxy header with the ip details and length (given in host byte order)
 */
inline void fill_proxy (proxy_iphdr_t *proxy_hdr, struct iphdr *ip, __u16 len)
{
	
	memset(proxy_hdr, 0, sizeof(proxy_iphdr_t));
	proxy_hdr->saddr = ip->saddr;
	proxy_hdr->daddr = ip->daddr;
	proxy_hdr->protocol = ip->protocol;
	proxy_hdr->len = htons(len);	
}

/**
 * Compute the checksum for the header field
 * Return the checksum 
 */
inline __sum16 ip_checksum(struct iphdr *ip)
{
	__sum16 final_sum;
	__u32 new_sum;
	ip->check = (__u16)0;
	new_sum = compute_sum16((__u8 *)ip, ((ip->ihl)*4));
	final_sum = wrap_sum16(new_sum);
	return final_sum;
}

/**
 * Compute the tcp checksum
 * Return the checksum
 */
inline __sum16 tcp_checksum(struct iphdr *ip, struct tcphdr *tcp)
{
	proxy_iphdr_t proxy;
	__sum16 final_sum;
	__u32 new_sum = 0;
	__u16 tcplen = ntohs(ip->tot_len) - (ip->ihl)*4; 
	tcp->check = (__sum16)0;	
	new_sum = new_sum + compute_sum16((__u8 *)tcp, tcplen);
	fill_proxy(&proxy, ip, tcplen);
	new_sum = new_sum + compute_sum16((__u8 *)&proxy, sizeof(proxy_iphdr_t));
	final_sum = wrap_sum16(new_sum);
	return final_sum;
}

/**
 * Compute the udp checksum
 * Return the checksum
 */
inline __sum16 udp_checksum(struct iphdr *ip, struct udphdr *udp)
{
	proxy_iphdr_t proxy;
	__sum16 final_sum;
	__u32 new_sum = 0;
	udp->check = (__sum16)0;	
	new_sum = compute_sum16((__u8 *)udp, ntohs(udp->len));
	fill_proxy(&proxy, ip, ntohs(udp->len));
	new_sum = new_sum + compute_sum16((__u8 *)&proxy, sizeof(proxy_iphdr_t));	
 	final_sum = wrap_sum16(new_sum);
	return final_sum;
}

/**
 * If IP packet change the network from private network to modified network
 */
inline int nat_packet(unsigned char packet[], int nbytes, __u32 privnet, __u32 modnet, __u32 netmask)
{
	const tap_hdr_t *frame_hdr;
	struct iphdr *ip;
	struct tcphdr *tcp;
	struct udphdr *udp;
	__u32 srcaddr, dstaddr;
	__u8 mod = 0;
	frame_hdr = (tap_hdr_t *) packet;

	/* For IP packets */
 	if (ntohs(frame_hdr->proto) == ETH_P_IP) {		
		ip = (struct iphdr *)(packet + sizeof(tap_hdr_t));
		srcaddr = ntohl(ip->saddr);
		dstaddr = ntohl(ip->daddr);
		mod = 0;
		/* If packets come from the private network change the source address */
		/* to one in the modified network */
		if ((srcaddr & netmask) == privnet) {
			if ((dstaddr & privnet) != privnet) {
 				srcaddr = htonl(modnet | (privnet ^ srcaddr));
				ip->saddr = srcaddr;
				mod = 1;
			} 
		}
		/* If packets are destined to the modified network change the destination address */
		/* to one in the modified network */		
		if ((dstaddr & netmask) == modnet) {
			dstaddr = htonl(privnet | (modnet ^ dstaddr));
			ip->daddr = dstaddr;
			mod = 1;
		}
		/* If modified then update the checksums of the L3 and L4 protocols  */
		if (mod == 1) {						
			switch (ip->protocol) {
			case IPPROTO_TCP:
				tcp = (struct tcphdr *) ((__u8*)ip + (ip->ihl)*4);
				tcp->check = tcp_checksum(ip, tcp);
				break;
			case IPPROTO_UDP:
				udp = (struct udphdr *) ((__u8*)ip + (ip->ihl)*4);
				udp->check = udp_checksum(ip, udp);
				break;
			default:
				break;
			}
			ip->check = ip_checksum(ip);
		}
	}
	return 0;
}

/**
 * Read and forward loop
 */
int read_and_fwd_loop(int tap0_fd, __u32 privnet, __u32 modnet, __u32 netmask)
{
	int nread, nwrite;
	unsigned char buffer[10240];	
	while(1)
	{
		nread = read(tap0_fd,buffer,sizeof(buffer));
		nat_packet(buffer, nread, privnet, modnet, netmask);
		nwrite = write(tap0_fd, buffer, nread);
		if (nwrite != nread) {
			perror("Error in write");
		}
	}
}

int main(int argc, char *argv[])
{  
	char tun_name[IFNAMSIZ];
	int tap0_fd;
	__u32 privnet, modnet, netmask;
		
	strcpy(tun_name, "tun0");
        tap0_fd = tun_alloc(tun_name, IFF_TUN);  /* tap interface TODO:: try with tun interface */
	if (tap0_fd < 0) {
		exit(-1);
	}		
	ip_alloc("tun0", "192.168.0.1", "255.255.254.0");
	   
	inet_pton(AF_INET, "192.168.0.0", &privnet);
	inet_pton(AF_INET, "192.168.1.0", &modnet);
	inet_pton(AF_INET, "255.255.255.0", &netmask); // netmask of each network
	netmask = htonl(netmask);
	privnet = htonl(privnet);
	modnet = htonl(modnet);
	printf("File descriptors are %d\n", tap0_fd);
	read_and_fwd_loop(tap0_fd, privnet, modnet, netmask);
	return 0;
}
