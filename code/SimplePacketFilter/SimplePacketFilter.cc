#include "MeddleDaemon.h"
#include <stdlib.h>
#include <signal.h>
#include <iostream>
#include <execinfo.h>
#include "Logging.h"

/* The main file
 * Create the tunnel device
 *
 */
#define TUN_DEVICE "tun0"
#define FWD_PATH_NET "192.168.0.0"
#define REV_PATH_NET "192.168.1.0"
#define DEV_NETMASK "255.255.254.0"
#define ROUTE_NETMASK "255.255.255.0"
#define IP_ADDRESS "192.168.0.1"

void dumpHandler(int sig)
{
	void *array[30];
	size_t size;
	size = backtrace(array, 30);
	std::cerr << "Received Signal " << sig << std::endl;
	backtrace_symbols_fd(array, size, 2);
	exit(1);
}

/*
 * All Initialization stuff comes in this function.
 */
void init()
{
	signal(SIGSEGV, dumpHandler);
}

int main()
{
	init();
	MeddleDaemon m;
	logDebug("Setting UP");
	m.Setup(TUN_DEVICE, IP_ADDRESS, DEV_NETMASK, ROUTE_NETMASK, FWD_PATH_NET, REV_PATH_NET);
	m.ReadWriteLoop();
	return 0;
}
