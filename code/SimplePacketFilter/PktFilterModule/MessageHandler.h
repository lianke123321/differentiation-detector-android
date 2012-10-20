#ifndef COMMANDHANDLER_H_
#define COMMANDHANDLER_H_

#include <stdint.h>
#include "MessageFrame.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

class MessageHandler {
public:
	int32_t sockFD;
private:
	MessageFrame *cmd;
	uint8_t lastRead[4096];
	struct sockaddr_in localAddr;
	uint32_t remoteFD;
private:
	MessageFrame * recvCommand();
	bool processCommand();
	bool processTunnelCommand();
	bool processCreateTunnelCommand();
	bool processCloseTunnelCommand();
	bool processReadAllConfs();
	bool respondGetUserIpInfo();
public:
	MessageHandler();
	~MessageHandler();
	bool setupMessageHandler(uint16_t socketPort);
	bool mainLoop();
};
#endif /* COMMANDHANDLER_H_ */
