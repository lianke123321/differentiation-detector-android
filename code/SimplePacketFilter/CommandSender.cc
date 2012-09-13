#include "CommandSender.h"
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "Logging.h"
#include <exception>

CommandSender::CommandSender()
{
	 if ((sockFD = socket(AF_UNIX, SOCK_STREAM, 0)) < 0) {
		 sockFD = -1;
		 logError("socket error");
		 return;
	 }
	 logDebug("Created the Unix domain socket FD = " << sockFD);
	 memset(&addr, 0, sizeof(addr));
	 addr.sun_family = AF_UNIX;
	 strncpy(addr.sun_path, COMMAND_SOCKET_PATH, sizeof(addr.sun_path)-1);
	 logDebug("Connecting to the Socket at path " << COMMAND_SOCKET_PATH );
	 if (connect(sockFD, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
		 logError("connect error");
		 sockFD = -1;
		 return;
	 }
	 logDebug("Successfully connected to Unix socket");
}

CommandSender::~CommandSender()
{
	logDebug("Closing the socket FD " << sockFD);
	if (sockFD > 0) {
		close(sockFD);
		sockFD = -1;
	}
}

bool CommandSender::sendCommand(uint32_t cmd, cmdTunnel_t cmdCreate)
{
	CommandFrame cmdFrame = CommandFrame(cmd, cmdCreate), *response;
	uint32_t nwrite, nread;
	uint8_t buffer [4096];

	if (NULL == cmdFrame.buffer || cmdFrame.frameLen < 0) {
		logError("Error creating Frame");
		return false;
	}
	logDebug("Created a Frame to send Command " << cmdFrame << " Now attempting a write");
	nwrite = write(sockFD, cmdFrame.buffer, cmdFrame.frameLen);
	if (nwrite != cmdFrame.frameLen || nwrite < 0) {
		logError("Error creating Frame");
		return false;
	}
	nread = read(sockFD, buffer, sizeof(buffer));
	if (nread < 0) {
		logError("Not received ACK");
		return false;
	}
	response = new CommandFrame(buffer, nread);
	if (response == NULL) {
		logError("Error receiving response");
		return false;
	}
	if (response->cmdHeader->cmdType != CMD_ACK_POSITIVE) {
		delete response;
		logError("Error sending data");
		return false;
	}
	logDebug("Received ack " << (*response))
	delete response;
	logDebug("Yippie sent the frame now returning" << cmdFrame);
	return true;
}

