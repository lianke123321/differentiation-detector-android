#ifndef MESSAGEFRAME_H_
#define MESSAGEFRAME_H_

#include <stdint.h>
#include <iostream>
#include <arpa/inet.h>
#include "UserConfigs.h"

#define MSG_CREATETUNNEL 1
#define MSG_CLOSETUNNEL 2
#define MSG_LOADALLCONFS 3
#define MSG_GETIPUSERINFO 4
#define MSG_RESPIPUSERINFO 5
#define MSG_LOADUSERCONFS 6
#define MSG_RESPUSERCONFS 7

#define USERNAMELEN_MAX 512

struct msgHeader {
	uint32_t cmdType;
	uint32_t cmdLen; //placeholder ignored
}__attribute__((packed));
typedef struct msgHeader msgHeader_t;

struct msgTunnel {
	int8_t clientTunnelIpAddress[INET_ADDRSTRLEN]; // TODO:: this will break for IPv6
	int8_t meddleServerIpAddress[INET_ADDRSTRLEN];
	int8_t clientRemoteIpAddress[INET_ADDRSTRLEN];
	uint32_t userNameLen; //placeholder ignored
	int8_t userName[USERNAMELEN_MAX];
}__attribute__((packed));
typedef struct msgTunnel msgTunnel_t;

struct msgIPUserInfo {
	uint8_t ipAddress[INET_ADDRSTRLEN];
}__attribute__((packed));

typedef struct msgIPUserInfo msgGetIPUserInfo_t;

struct respIPUserInfo {
	uint8_t ipAddress[INET_ADDRSTRLEN];
	uint32_t userID;
	uint32_t userNameLen;
	uint8_t userName[USERNAMELEN_MAX];
}__attribute__((packed));
typedef struct respIPUserInfo msgRespIPUserInfo_t;

struct msgLoadUserConfs{
	uint32_t userID;
}__attribute__((packed));
typedef struct msgLoadUserConfs msgLoadUserConfs_t;

struct msgRespUserConfs {
	user_config_entry_t entry;
}__attribute__((packed));
typedef struct msgRespUserConfs msgRespUserConfs_t;

class MessageFrame {
public:
	uint32_t frameLen;
	uint8_t * buffer;
	msgHeader_t *cmdHeader;
	msgTunnel_t *cmdTunnel;
	msgGetIPUserInfo_t *cmdIPUserInfo;
	msgRespIPUserInfo_t *respIPUserInfo;
	msgLoadUserConfs_t *loadUserConfs;
	msgRespUserConfs_t *respUserConfs;
private:
	void __parseCommand();
	void __createFrame(uint32_t cmd);
public:
	MessageFrame();
	~MessageFrame();
	MessageFrame(uint8_t* payload, uint32_t len);
	MessageFrame(uint32_t cmd, const msgTunnel_t &cmdCreate);
	MessageFrame(const msgGetIPUserInfo_t &msgGet);
	MessageFrame(const msgRespIPUserInfo_t &resp);
	MessageFrame(const msgLoadUserConfs_t &readUserConfs);
	MessageFrame(const msgRespUserConfs_t &respUserConfs);
	friend std::ostream& operator<<(std::ostream& os, const MessageFrame& cmd);
};


#endif /* MESSAGEFRAME_H_ */
