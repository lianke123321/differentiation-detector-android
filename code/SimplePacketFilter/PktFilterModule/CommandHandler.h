#ifndef COMMANDHANDLER_H_
#define COMMANDHANDLER_H_

#include <stdint.h>
#include "CommandFrame.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

class CommandHandler {
public:
	int32_t sockFD;
private:
	CommandFrame *cmd;
	uint8_t lastRead[4096];
	struct sockaddr_un localAddr;
	uint32_t remoteFD;
private:
	CommandFrame * recvCommand();
	bool processCommand();
	bool processTunnelCommand();
	bool processReadAllConfs();
	bool respondGetUserIpInfo();
public:
	CommandHandler();
	~CommandHandler();
	bool setupCommandHandler(std::string socketPath);
	bool mainLoop();
};
#endif /* COMMANDHANDLER_H_ */
