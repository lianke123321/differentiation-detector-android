#ifndef COMMANDSENDER_H_
#define COMMANDSENDER_H_
#include <sys/un.h>

#include "CommandFrame.h"
#include "CommandHandler.h"
#include "SimplePacketFilter.h"

class CommandSender
{
public:
	int32_t sockFD;
private:
	struct sockaddr_un addr;
public:
	CommandSender();
	~CommandSender();
	bool sendCommand(uint32_t cmd, cmdTunnel_t cmdCreate);
};

#endif /* COMMANDSENDER_H_ */
