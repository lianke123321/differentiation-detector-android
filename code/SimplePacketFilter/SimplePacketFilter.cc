#include "MeddleDaemon.h"
#include <stdlib.h>
#include <signal.h>
#include <iostream>
#include <execinfo.h>
#include "Logging.h"
#include "SimplePacketFilter.h"
#include <boost/thread.hpp>
#include "CommandHandler.h"
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

/*
 *
 */
int mainInit(MeddleDaemon &meddle, CommandHandler &cmd)
{
	sigInit();
	logDebug("Setting UP");
	if (false == cmd.setupCommandHandler(COMMAND_SOCKET_PATH)) {
		logError("Unable to setup the socket for receiving commands");
		return -1;
	}
	if (false == meddle.setupTunnel(TUN_DEVICE, IP_ADDRESS, DEV_NETMASK, ROUTE_NETMASK, FWD_PATH_NET, REV_PATH_NET)) {
		logError("Unable to setup the tunnel");
		return -1;
	}
	return 0;
}

/* mainPktFilter is the global object that is shared by all the threads */

pktFilter_t mainPktFilter;
int main()
{
	MeddleDaemon meddle;
	CommandHandler cmdHandler;

	if (mainInit(meddle, cmdHandler) < 0) {
		logError("Error in the setup");
		return -1;
	}
	logDebug("Create the worker threads")
	boost::thread meddleThread(&MeddleDaemon::mainLoop, &meddle);

	boost::thread commandThread(&CommandHandler::mainLoop, &cmdHandler);

	logDebug("Polling the health of the threads periodically and checking for signals");
	while (1) {
		sigset_t sigSet;
		siginfo_t sigInfo;
		int sigVal;
//		int n = (int)boost::posix_time::time_duration::ticks_per_second() / 10;
//
//		boost::posix_time::time_duration delay1(0,0,0,n);
//		boost::posix_time::time_duration delay2(0,0,0,n);

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
					break;
				case SIGHUP:
					break;
				case SIGTERM:
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
