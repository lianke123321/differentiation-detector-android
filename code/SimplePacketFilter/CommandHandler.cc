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

	if (socketPath.length() > sizeof(localAddr.sun_path) - 1) {
		sockFD = -1;
		return false;
	}
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
	return true;
}

CommandFrame* CommandHandler::recvCommand(uint32_t remoteFD)
{
	CommandFrame *ackFrame;
	cmd_ack_t ack_data;
	uint32_t nRead, nwrite;
	memset(lastRead, 0, sizeof(lastRead));

	if ((remoteFD = accept(sockFD, NULL, NULL)) < 0) {
	      logError("Error during the read operation");
	      return cmd;
	}
	logDebug("Accepted a new connection: Reading for data on " << remoteFD);
	nRead = read(remoteFD, lastRead, sizeof(lastRead));

	if (nRead < 0) {
		logError("Error during the read operation");
		return cmd;
	}

	cmd = new CommandFrame(lastRead, nRead);
	if (cmd == NULL) {
		logError("Error creating the command");
		cmd = NULL;
		return cmd;
	}
	if (cmd->frameLen < 0) {
		logError("Sending NACK");
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
	ack_data = CMD_ACK_POSITIVE;
	ackFrame = new CommandFrame(ack_data);
	if (ackFrame == NULL) {
		logError("Error creating the ACK frame")
		// TODO:: should we continue sending the command as we have not acked it
		// TODO:: This means retransmissions must not break system state.
	} else {
		nwrite = write(remoteFD, ackFrame->buffer, ackFrame->frameLen);
		delete ackFrame;
	}
	return cmd;
}

bool CommandHandler::processTunnelCommand()
{
	bool ret;
	// ignoring the name len for now
	std::string userName((char *)(cmd->cmdTunnel->userName));

	// TODO:: assuming IPv4 here and not performing any sanity checks
	in_addr_t ipAddress;

	if (inet_pton(AF_INET, (const char *)(cmd->cmdTunnel->ipAddress), (void *) &ipAddress) < 0) {
		logError("Error parsing the IP address");
		return false;
	}
	// TODO Code to lookup the UserID for the user Name;
	static uint32_t userID = ipAddress%10;

	if (CMD_CREATETUNNEL == cmd->cmdHeader->cmdType) {
		boost::mutex::scoped_lock scoped_lock(mainPktFilter.filterLock); // lock is released automatically outside this scope
		ret = mainPktFilter.ipMap.addEntry(ipAddress, userID);
		if (false == ret) {
			logError("Error adding the user" << cmd->cmdTunnel->userName);
			return ret;
		}
	} else {
		boost::mutex::scoped_lock scoped_lock(mainPktFilter.filterLock);
		ret = mainPktFilter.ipMap.removeEntry(ipAddress);
		if (false == ret) {
			logError("Error in removing the entry for ipAddress" << cmd->cmdTunnel->ipAddress << " for user "<< cmd->cmdTunnel->userName);
			return ret;
		}
	}
	// TODO release the lock here
	return ret;
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
		ret = processTunnelCommand();
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
		if ((remoteFD = accept(sockFD, NULL, NULL)) < 0) {
			logError("Error during the accept operation");
			return cmd;
		}
		this->cmd = recvCommand(remoteFD);
		processCommand();
		logDebug("Accepted a new connection: Reading for data on " << remoteFD);
		delete this->cmd;
	}
	return true;
}



