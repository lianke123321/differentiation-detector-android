#include "CommandHandler.h"
#include "Logging.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <string.h>
#include <arpa/inet.h>
#include "SimplePacketFilter.h"
#include <boost/thread/mutex.hpp>
#include <boost/thread/thread.hpp>

CommandHandler::CommandHandler()
{
	sockFD = 0;
}

CommandHandler::~CommandHandler()
{
	if (0 < sockFD) {
		close(sockFD);
	}
}

bool CommandHandler::setupCommandHandler(std::string socketPath)
{
	uint32_t len;

	logDebug("The socket path is of length " << socketPath.length() << " and the max length is " << sizeof(localAddr.sun_path));
	if (socketPath.length() > sizeof(localAddr.sun_path) - 1) {
		logError("The socket path " << socketPath.length() << " has a length larger than the maximum length " << sizeof(localAddr.sun_path));
		sockFD = -1;
		return false;
	}
	logDebug("Now connecting the socket");
	sockFD = socket(AF_UNIX, SOCK_STREAM, 0);
	if (0 > sockFD ) {
		logError("Error creating socket to read commands");
		sockFD = -1;
		return false;
	}
	memset(&localAddr, 0, sizeof(struct sockaddr_un));
	localAddr.sun_family = AF_UNIX;
	strncpy(localAddr.sun_path, socketPath.c_str(), sizeof(localAddr.sun_path)-1);
	unlink(localAddr.sun_path);
	len = strlen(localAddr.sun_path) + sizeof(localAddr.sun_family);
	if (bind(sockFD, (struct sockaddr *)&localAddr, len) == -1) {
		logError("Error in bind operation");
		close(sockFD);
		sockFD = -1;
		return false;
	}
	if (listen(sockFD, 5) == -1) {
		logError("Error listen");
		close(sockFD);
		sockFD = -1;
		return false;
	}
	logDebug("Successful in creating a socket at " << sockFD);
	return true;
}

CommandFrame* CommandHandler::recvCommand(uint32_t remoteFD)
{
	CommandFrame *ackFrame;
	cmd_ack_t ack_data;
	uint32_t nRead, nwrite;
	memset(lastRead, 0, sizeof(lastRead));

	logDebug("Accepted a new connection: Reading for data on " << remoteFD);
	nRead = read(remoteFD, lastRead, sizeof(lastRead));
	logDebug("Read " << nRead << " bytes on socket" << remoteFD);
	if (nRead < 0) {
		logError("Error during the read operation");
		return cmd;
	}

	logDebug("Now parsing the received bytes");
	cmd = new CommandFrame(lastRead, nRead);
	if (cmd == NULL) {
		logError("Error creating the command");
		cmd = NULL;
		return cmd;
	}
	if (cmd->frameLen < 0) {
		logError("Sending NACK because the command could not be parsed");
		delete cmd;
		ack_data = CMD_ACK_NEGATIVE;
		ackFrame = new CommandFrame(ack_data);
		if (ackFrame == NULL) {
			logError("Error creating the ack Frame")
		} else {
			nwrite = write(remoteFD, ackFrame->buffer, ackFrame->frameLen);
			delete ackFrame;
		}
		logError("Error creating Command Frame");
		cmd = NULL;
		return cmd;
	}
	logDebug("Received a command that can be interpreted therefore sending ACK");
	ack_data = CMD_ACK_POSITIVE;
	ackFrame = new CommandFrame(ack_data);
	if (ackFrame == NULL) {
		logError("Error creating the ACK frame");
		// TODO:: should we continue sending the command as we have not acked it
		// TODO:: This means retransmissions must not break system state.
	} else {
		nwrite = write(remoteFD, ackFrame->buffer, ackFrame->frameLen);
		delete ackFrame;
	}
	logDebug("Received the command " << cmd);
	return cmd;
}

bool CommandHandler::processTunnelCommand()
{
	// ignoring the name len for now
	std::string userName((char *)(cmd->cmdTunnel->userName));
	uint32_t userID;

	// TODO:: assuming IPv4 here and not performing any sanity checks
	in_addr_t ipAddress;

	if (inet_pton(AF_INET, (const char *)(cmd->cmdTunnel->ipAddress), (void *) &ipAddress) < 0) {
		logError("Error parsing the IP address");
		return false;
	}

	logDebug("Prev Table" << mainPktFilter.getIPMap());
	if (CMD_CREATETUNNEL == cmd->cmdHeader->cmdType) {
		if (false == mainPktFilter.associateUserToIp(userName, ipAddress)) {
			logError("Error adding the user" << cmd->cmdTunnel->userName);
			return false;
		}
	} else {
		if (false == mainPktFilter.disassociateIpFromUser(userName, ipAddress)) {
			logError("Error in removing the entry for ipAddress" << cmd->cmdTunnel->ipAddress << " for user "<< cmd->cmdTunnel->userName);
			return false;
		}
	}
	logDebug("New Table" << mainPktFilter.getIPMap());
	// TODO release the lock here
	return true;
}

bool CommandHandler::processReadAllConfs()
{
	return mainPktFilter.loadAllUserConfigs();
}

bool CommandHandler::processCommand()
{
	bool ret;
	if (NULL == cmd) {
		logError("NULL cmd passed");
		return false;
	}
	switch(cmd->cmdHeader->cmdType) {
	case CMD_CREATETUNNEL:
	case CMD_CLOSETUNNEL:
		logDebug("Processing the Tunnel command now");
		ret = processTunnelCommand();
		break;
	case CMD_READALLCONFS:
		logDebug("Processing the command to read configs");
		ret = processReadAllConfs();
		break;
	default:
		break;
	}
	return ret;
}

bool CommandHandler::mainLoop()
{
	uint32_t remoteFD;

	while(1) {
		this->cmd = NULL;
		// TODO:: Add pselect here with 100000 seconds and signal handler to ensure that thread receives signals quits
		logDebug("Waiting for a connection");
		if ((remoteFD = accept(sockFD, NULL, NULL)) < 0) {
			logError("Error during the accept operation");
			return cmd;
		}
		logDebug("Received a new connection request on " << remoteFD);
		this->cmd = recvCommand(remoteFD);
		processCommand();
		logDebug("Accepted a new connection: Reading for data on " << remoteFD);
		close(remoteFD);
		delete this->cmd;
	}
	return true;
}



