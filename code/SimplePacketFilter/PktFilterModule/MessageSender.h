#ifndef COMMANDSENDER_H_
#define COMMANDSENDER_H_
#include <sys/un.h>

#include "MessageFrame.h"
#include "SimplePacketFilter.h"

class MessageSender
{
public:
	int32_t sockFD;
private:
	struct sockaddr_in addr;
	void connectToServer(std::string serverIP);
public:
	MessageSender();
	MessageSender(std::string serverIP);
	~MessageSender();
	bool sendCommand(const uint32_t &cmd, const msgTunnel_t &cmdCreate);
	bool sendCommand(const msgLoadUserConfs_t &msgReadConfs, user_config_entry &entry);
	bool recvIPInfo(const msgGetIPUserInfo_t &getInfo, msgRespIPUserInfo_t &respIP);
};

#endif /* COMMANDSENDER_H_ */