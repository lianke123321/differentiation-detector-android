#include "MessageSender.h"
#include "MessageFrame.h"
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "Logging.h"
#include <exception>

MessageSender::MessageSender()
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
		 logError("Connect error");
		 sockFD = -1;
		 return;
	 }
	 logDebug("Successfully connected to Unix socket");
}

MessageSender::~MessageSender()
{
	logDebug("Closing the socket FD " << sockFD);
	if (sockFD > 0) {
		close(sockFD);
		sockFD = -1;
	}
}

bool MessageSender::sendCommand(const uint32_t &cmd, const msgTunnel_t &cmdCreate)
{
	MessageFrame cmdFrame = MessageFrame(cmd, cmdCreate), *response;
	uint32_t nwrite;
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
	logDebug("Yippie sent the frame now returning" << cmdFrame);
	return true;
}

bool MessageSender::recvIPInfo(const msgGetIPUserInfo_t &getInfo, msgRespIPUserInfo_t &respIP)
{
	uint32_t nread, nwrite;
	uint8_t buffer [4096];
	uint32_t reqRead = sizeof(msgHeader_t) + sizeof(msgRespIPUserInfo_t);
	uint32_t offset=0;
	MessageFrame cmdFrame = MessageFrame(MSG_GETIPUSERINFO, getInfo);

	memset(&respIP, 0, sizeof(msgRespIPUserInfo_t));
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

	offset = 0;
	nread = 0;
	while (nread < reqRead) {
		int32_t tmpRead;
		tmpRead = read(sockFD, buffer+offset, reqRead - offset);
		if (tmpRead < 0) {
			logError("Error in the read operation");
			break;
		}
		nread = nread + tmpRead;
		offset = offset + tmpRead;
	}
	if (nread != reqRead) {
		// TODO:: do a while read
		logError("Error in receiving the response on user IP");
		return false;
	}
	MessageFrame respFrame = MessageFrame(buffer, nread);
	if( respFrame.cmdHeader->cmdType != MSG_RESPIPUSERINFO) {
		logError("The response is not the IP Info");
		return false;
	}
	memcpy((void *)&respIP, (void *)(respFrame.respIPUserInfo), sizeof(msgRespIPUserInfo_t));
	return true;
}

