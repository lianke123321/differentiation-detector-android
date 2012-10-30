#include "MeddleDaemon.h"
#include <stdlib.h>
#include <signal.h>
#include <iostream>
#include <execinfo.h>
#include "Logging.h"
#include "SimplePacketFilter.h"
#include <boost/thread.hpp>
#include "MessageHandler.h"
#include "boost/date_time/local_time/local_time.hpp"

/* The main file
 * Create the tunnel device
 *
 */
// TODO:: Move all of this to a config file
#define PERIODIC_POLL_TIME 60 // seconds

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
 * All signal Initialisation stuff comes in this function.
 */
void sigInit()
{
	struct sigaction action;
	action.sa_handler = dumpHandler;
	action.sa_flags = 0;
	sigemptyset(&action.sa_mask);
	sigaddset(&action.sa_mask, SIGINT);
	sigaddset(&action.sa_mask, SIGTERM);
	sigaddset(&action.sa_mask, SIGHUP);
	sigaction(SIGSEGV, &action, NULL);
	sigaction(SIGILL, &action, NULL);
	sigaction(SIGBUS, &action, NULL);
}


int mainInit(MeddleDaemon &meddle, MessageHandler &cmd)
{
	sigInit();
	logDebug("Creating a tunnel device" << TUN_DEVICE  <<
			 " assigning it an IP " << IP_ADDRESS << " with mask " << ROUTE_NETMASK
			 " to NAT packets from " << FWD_PATH_NET <<
			 " to network " << REV_PATH_NET);
	if (false == meddle.setupTunnel(TUN_DEVICE, IP_ADDRESS, DEV_NETMASK, ROUTE_NETMASK, FWD_PATH_NET, REV_PATH_NET)) {
		logError("Unable to setup the tunnel");
		return -1;
	}
	logDebug("Setting up the DNS server to filter traffic");

	if (false == meddle.setupDNS(DEFAULT_DNS_SERVER, FILTER_DNS_SERVER)) {
		logError("Error in setting up the DNS");
		return -1;
	}
	logDebug("Connecting to the Database");

	if (false == mainPktFilter.connectToDB(DB_SERVER, DB_USER, DB_PASSWORD, DB_NAME)) {
		logError("Error in connecting to the database");
		return -1;
	}
	if (false == mainPktFilter.loadAllUserConfigs()) {
		logError("Error in loading the configs to memory");
		return -1;
	}
	logDebug("Config Table is " << mainPktFilter.getAllUserConfigs());
	logDebug("We have done the initialization now time to meddle");

	logDebug("Listening on "<< MEDDLE_MESSAGE_SOCKET_PORT << " for commands from other processes");
	if (false == cmd.setupMessageHandler(MEDDLE_MESSAGE_SOCKET_PORT)) {
		logError("Unable to setup the socket for receiving commands");
		return -1;
	}
	return 0;
}

/* mainPktFilter is the global object that is shared by all the threads */
PacketFilterData mainPktFilter;

int main()
{
	MeddleDaemon meddle;
	MessageHandler cmdHandler;

	if (mainInit(meddle, cmdHandler) < 0) {
		logError("Error in the setup");
		return -1;
	}
	logDebug("Create the worker threads")
	boost::thread meddleThread(&MeddleDaemon::mainLoop, &meddle);

	boost::thread commandThread(&MessageHandler::mainLoop, &cmdHandler);

	logDebug("Polling the health of the threads periodically and checking for signals");
	while (1) {
		sigset_t sigSet;
		siginfo_t sigInfo;
		int sigVal;

		struct timespec tSpec;

		/* handle SIGINT, SIGHUP ans SIGTERM in this handler */
		sigemptyset(&sigSet);
		sigaddset(&sigSet, SIGINT);
		sigaddset(&sigSet, SIGHUP);
		sigaddset(&sigSet, SIGTERM);
		sigprocmask(SIG_BLOCK, &sigSet, NULL);

		// check if the threads are alive ...
		tSpec.tv_sec = 10;
		tSpec.tv_nsec = 0;

		logDebug("In Loop Waiting for " << tSpec.tv_sec << " seconds");
		sigVal = sigtimedwait(&sigSet, &sigInfo, &tSpec);

		if ((sigVal < 0) && ((false == meddleThread.timed_join(boost::posix_time::seconds(0))) && (false == commandThread.timed_join(boost::posix_time::seconds(0))))) {
			// No signal received in the last cycle
		}
		else {
			logDebug("Received some thing that tells us to stop");
			break;
			if (sigVal) {
				switch(sigVal) {
				// A Signal is set
				case SIGINT:
				case SIGHUP:
				case SIGTERM:
					// TODO :: Add code to cancel the threads
					logDebug("Now stop the threads in a clean manner");
					break;
				default:
					logError("Error in the received signal"<<sigVal);
					break;
				}
			} else {
				// TODO:: check if a thread quit here
				break;
			}
		}
	}
	return 0;
}
