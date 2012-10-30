#include "MessageHandler.h"
#include "MessageFrame.h"
#include "MessageSender.h"
#include "Logging.h"
#include <string.h>

void testRecvCommand()
{
	MessageHandler c;
	fd_set fds;
	struct timeval tv;
	MessageFrame *cmdFrame;
	int32_t retval;

	while(1)
	{
		FD_ZERO(&fds);
		FD_SET(c.sockFD, &fds);

		tv.tv_sec = 1;
		tv.tv_usec = 0;
		retval = select((c.sockFD+1), &fds, NULL, NULL, &tv);
		if (retval == -1) {
			logDebug("select()");
		} else if (retval) {
			logDebug("Data is available now.\n");
			if (FD_ISSET(c.sockFD, &fds) ) {
				/* FD_ISSET(0, &rfds) will be true. */
				cmdFrame = c.recvCommand;
				if (NULL == cmdFrame) {
					logError("Error receiving Command");
					return;
				}
				logError("Received Command " << (*cmdFrame));
			}
		} else {
			logDebug("Timeout:: No data. ");
		}
	}
}

#define IPADDRESS "192.168.10.10"
#define USERNAME "HELLO"
void testCreateCommand()
{
	msgTunnel_t cmdCreate;
	MessageSender c;
	logDebug("Connected");

	memset(&cmdCreate, 0, sizeof(msgTunnel_t));
	strncpy((char *)(cmdCreate.clientTunnelIpAddress), IPADDRESS, sizeof(cmdCreate.clientTunnelIpAddress)-1);
	strncpy((char *)(cmdCreate.userName), USERNAME, sizeof(cmdCreate.userName)-1);
	cmdCreate.userNameLen = strlen(USERNAME);
	logDebug("Created Frame");
	if (c.sockFD != -1) {
		logDebug("Sending");
		c.sendCommand(MSG_CREATETUNNEL,cmdCreate);
	}
	logDebug("Sent the message: test Successful");
}
void testCloseCommand()
{
	msgTunnel_t cmdClose;
	MessageSender c;
	logDebug("Connected");

	memset(&cmdClose, 0, sizeof(msgTunnel_t));
	strncpy((char *)(cmdClose.clientTunnelIpAddress), IPADDRESS, sizeof(cmdClose.clientTunnelIpAddress)-1);
	strncpy((char *)(cmdClose.userName), USERNAME, sizeof(cmdClose.userName)-1);
	cmdClose.userNameLen = strlen(USERNAME);
	logDebug("Created Frame");
	if (c.sockFD != -1) {
		logDebug("Sending");
		c.sendCommand(MSG_CLOSETUNNEL,cmdClose);
	}
	logDebug("Sent the message: test Successful");
}

void testWriteCommand()
{
	testCreateCommand();
	testCloseCommand();
}
