#ifndef COMMANDFRAME_H_
#define COMMANDFRAME_H_

#include <stdint.h>
#include <iostream>
#include <arpa/inet.h>

#define CMD_ACK_POSITIVE 1
#define CMD_ACK_NEGATIVE 2
#define CMD_CREATETUNNEL 3
#define CMD_CLOSETUNNEL 4
#define CMD_READALLCONFS 5

#define USERNAMELEN_MAX 512

struct cmdHeader {
	uint32_t cmdType;
	uint32_t cmdLen; //placeholder ignored
}__attribute__((packed));
typedef struct cmdHeader cmdHeader_t;

typedef uint32_t cmd_ack_t;

struct cmdTunnel {
	int8_t ipAddress[INET_ADDRSTRLEN]; // TODO:: this will break for IPv6
	uint32_t userNameLen; //placeholder ignored
	int8_t userName[USERNAMELEN_MAX];
}__attribute__((packed));

typedef cmdTunnel cmdTunnel_t;

class CommandFrame {
public:
	uint32_t frameLen;
	uint8_t * buffer;
	cmdHeader_t *cmdHeader;
	cmdTunnel_t *cmdTunnel;
private:
	void __parseCommand();
public:
	CommandFrame();
	~CommandFrame();
	CommandFrame(uint8_t* payload, uint32_t len);
	CommandFrame(uint32_t cmd, cmdTunnel_t cmdCreate);
	CommandFrame(cmd_ack_t cmd);
	friend std::ostream& operator<<(std::ostream& os, const CommandFrame& cmd);
};


#endif /* COMMANDFRAME_H_ */
