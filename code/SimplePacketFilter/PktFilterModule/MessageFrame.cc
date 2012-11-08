#include "MessageFrame.h"
#include "Logging.h"
#include <iostream>
#include <string.h>

MessageFrame::MessageFrame()
{
	buffer = NULL; frameLen = 0; cmdHeader = NULL; cmdTunnel = NULL;
	return;
}

MessageFrame::~MessageFrame()
{
	logDebug("Deleting the allocated buffer"<< static_cast<void*>(buffer));
	if (NULL != buffer) {
		delete buffer;
		// logDebug("Done Deleting"<< static_cast<void*>(buffer));
	}
	logDebug("Cleaning up pointers in Frame");
	buffer = NULL;frameLen = 0;	cmdHeader = NULL; cmdTunnel = NULL;
	return;
}

MessageFrame::MessageFrame(uint8_t *payload, uint32_t len)
{
	frameLen = len;
	if (frameLen <  1) {
		frameLen = 1;
	}
	buffer = new uint8_t[frameLen];
	if (NULL == buffer) {
		logError("Error allocation memory for the buffer");
		buffer = NULL;
		frameLen = 0;
		return;
	}
	logDebug("Allocated Memory for the Frame of length"<< frameLen);
	if (NULL == payload) {
		memset(buffer, 0, frameLen);
	} else {
		memcpy(buffer, payload, len);
	}
	__parseCommand();
}

inline void MessageFrame::__parseCommand()
{
	cmdHeader = (msgHeader_t *) (buffer);
	void *ptr = (buffer + sizeof(msgHeader_t));
	switch(cmdHeader->cmdType) {
	case MSG_CREATETUNNEL:
	case MSG_CLOSETUNNEL:
		logDebug("Parsing command to " << (cmdHeader->cmdType == MSG_CREATETUNNEL? "CREATE " : "CLOSE ") <<  "Tunnel");
		cmdTunnel = (msgTunnel_t *)(ptr);
		break;
	case MSG_GETIPUSERINFO:
		logDebug("Parsing command to get IP Info");
		cmdIPUserInfo = (msgGetIPUserInfo_t *)(ptr);
		break;
	case MSG_RESPIPUSERINFO:
		logDebug("Parsing command to respond to IP info");
		respIPUserInfo = (msgRespIPUserInfo_t *)(ptr);
		break;
	case MSG_LOADUSERCONFS:
		logDebug("Parsing command to load user confs");
		loadUserConfs = (msgLoadUserConfs_t *)(ptr);
		break;
	case MSG_RESPUSERCONFS:
		logDebug("Parsing to respond to user confs");
		respUserConfs = (msgRespUserConfs_t *)(ptr);
		break;
	default:
		logError("Command not supported:" << cmdHeader->cmdType);
		break;
	}
	return;
}

inline void MessageFrame::__createFrame(uint32_t cmd)
{
	if (frameLen < 0) {
		frameLen = 1;
	}
	buffer = new uint8_t [frameLen];
	if (NULL == buffer) {
		logError("Error allocating memory");
		buffer = NULL;
		frameLen = 0;
		return;
	}
	memset(buffer, 0, frameLen);
	cmdHeader = (msgHeader_t *) (buffer);
	cmdHeader->cmdLen = frameLen;
	cmdHeader->cmdType = cmd;
	return;
}

MessageFrame::MessageFrame(uint32_t cmd, const msgTunnel_t &tunCmd)
{
	frameLen = sizeof(msgHeader_t) + sizeof(msgTunnel_t);
	__createFrame(cmd);
	if (NULL==buffer) {
		return;
	}
	cmdTunnel = (msgTunnel_t *)(buffer + sizeof(msgHeader_t));
	memcpy(cmdTunnel, &tunCmd, sizeof(msgTunnel_t));
	logDebug("Copied the command to " <<  (cmd == MSG_CREATETUNNEL ? "Create" : (cmd == MSG_CLOSETUNNEL ? "Close" : "Unknown")) << " Tunnel");
	return;
}

MessageFrame::MessageFrame(const msgRespIPUserInfo_t &resp)
{
	frameLen = sizeof(msgHeader_t) + sizeof(msgRespIPUserInfo_t);
	__createFrame(MSG_RESPIPUSERINFO);
	if (NULL == buffer) {
		return;
	}
	respIPUserInfo = (msgRespIPUserInfo_t *)(buffer + sizeof(msgHeader_t));
	memcpy(respIPUserInfo, &resp, sizeof(msgRespIPUserInfo_t));
	return;
}

MessageFrame::MessageFrame(const msgGetIPUserInfo_t & msgGet)
{
	frameLen = sizeof(msgHeader_t) + sizeof(msgGetIPUserInfo_t);
	__createFrame(MSG_GETIPUSERINFO);
	if (NULL == buffer) {
		return;
	}
	cmdIPUserInfo = (msgGetIPUserInfo_t *)(buffer + sizeof(msgHeader_t));
	memcpy(cmdIPUserInfo, &msgGet, sizeof(msgGetIPUserInfo_t));
	return;
}

MessageFrame::MessageFrame(const msgLoadUserConfs_t & readUConfs)
{
	frameLen = sizeof(msgHeader_t) + sizeof(msgLoadUserConfs_t);
	__createFrame(MSG_LOADUSERCONFS);
	if (NULL == buffer) {
		return;
	}
	loadUserConfs = (msgLoadUserConfs_t *)(buffer+sizeof(msgHeader_t));
	memcpy(loadUserConfs, &readUConfs, sizeof(msgLoadUserConfs_t));
	return;
}

MessageFrame::MessageFrame(const msgRespUserConfs_t & respUConfs)
{
	frameLen = sizeof(msgHeader_t) + sizeof(msgRespUserConfs_t);
	__createFrame(MSG_RESPUSERCONFS);
	if (NULL == buffer) {
		return;
	}
	respUserConfs = (msgRespUserConfs_t *)(buffer+sizeof(msgHeader_t));
	memcpy(respUserConfs, &respUConfs, sizeof(msgRespUserConfs_t));
	return;
}

std::ostream& operator<<(std::ostream& os, const MessageFrame& cmd)
{
    os << "Length " << cmd.frameLen << " Address " << static_cast<void*>(cmd.buffer) << " ";
    if (cmd.frameLen > 0)  {
    	switch (cmd.cmdHeader->cmdType) {
    	case MSG_CREATETUNNEL:
    	case MSG_CLOSETUNNEL:
    		os << (cmd.cmdHeader->cmdType == MSG_CREATETUNNEL? "CREATE " : "CLOSE ")
    		   << cmd.cmdTunnel->clientTunnelIpAddress << " " << cmd.cmdTunnel->clientRemoteIpAddress << " "
    		   << cmd.cmdTunnel->meddleServerIpAddress << " "
    		   << cmd.cmdTunnel->userName << " " << cmd.cmdTunnel->userNameLen;
    		break;
    	case MSG_GETIPUSERINFO:
    		os << "Get IP Info for IP :" << (cmd.cmdIPUserInfo->ipAddress);
    		break;
    	case MSG_RESPIPUSERINFO:
    		os << "Providing response of User ID:" << cmd.respIPUserInfo->userID << " for  IP" << cmd.respIPUserInfo->ipAddress;
    		break;
    	case MSG_LOADUSERCONFS:
    		os << "Command to read confs for user ID:" << cmd.loadUserConfs->userID;
    		break;
    	case MSG_RESPUSERCONFS:
    		os << "User Confs for userID:" << cmd.respUserConfs->entry.userID << " " << (uint32_t)(cmd.respUserConfs->entry.filterAdsAnalytics);
    		break;
    	default:
    		os << "Command Not Found";
    		break;
    	}
    } else {
    	os << "EMPTY FRAME";
    }
    return os;
}

