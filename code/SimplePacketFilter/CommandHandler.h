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
private:
	CommandFrame * recvCommand(uint32_t remoteFD);
	bool processCommand();
	bool processTunnelCommand();
public:
	CommandHandler();
	~CommandHandler();
	bool setupCommandHandler(std::string socketPath);
	bool mainLoop();
};
#endif /* COMMANDHANDLER_H_ */
