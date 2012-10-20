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
		logDebug("Done Deleting"<< static_cast<void*>(buffer));
	}
	logDebug("Cleaning up pointers in Frame");
	buffer = NULL;frameLen = 0;	cmdHeader = NULL; cmdTunnel = NULL;
	return;
}

MessageFrame::MessageFrame(uint8_t *payload, uint32_t len)
{
	frameLen = len;
	buffer = new uint8_t[frameLen];
	if (NULL == buffer) {
		logError("Error allocation memory for the buffer");
		buffer = NULL;
		frameLen = -1;
		return;
	}
	logDebug("Allocated Memory for the Frame of length"<< frameLen);
	memcpy(buffer, payload, len);
	__parseCommand();
}

inline void MessageFrame::__parseCommand()
{
	cmdHeader = (msgHeader_t *) (buffer);
	switch(cmdHeader->cmdType) {
	case MSG_CREATETUNNEL:
	case MSG_CLOSETUNNEL:
		logDebug("Parsing command to " << (cmdHeader->cmdType == MSG_CREATETUNNEL? "CREATE " : "CLOSE ") <<  "Tunnel");
		cmdTunnel = (msgTunnel_t *)(buffer + sizeof(msgHeader_t));
		break;
	case MSG_GETIPUSERINFO:
		logDebug("Parsing command to get IP Info");
		cmdIPUserInfo = (msgGetIPUserInfo_t *)(buffer + sizeof(msgHeader_t));
		break;
	case MSG_RESPIPUSERINFO:
		logDebug("Parsing command to respond to IP info");
		respIPUserInfo = (msgRespIPUserInfo_t *)(buffer + sizeof(msgHeader_t));
		break;
	default:
		logError("Command not supported:" << cmdHeader->cmdType);
		break;
	}
	return;
}

inline void MessageFrame::__createFrame()
{
	buffer = new uint8_t [frameLen];
	if (NULL == buffer) {
		logError("Error allocating memory");
		buffer = NULL;
		frameLen = -1;
		return;
	}
	memset(buffer, 0, frameLen);
	cmdHeader = (msgHeader_t *) (buffer);
	cmdHeader->cmdLen = frameLen;
	return;
}

MessageFrame::MessageFrame(uint32_t cmd, const msgTunnel_t &tunCmd)
{
	frameLen = sizeof(msgHeader_t) + sizeof(msgTunnel_t);
	__createFrame();
	if (NULL==buffer) {
		return;
	}
	cmdHeader->cmdType = cmd;
	cmdTunnel = (msgTunnel_t *)(buffer + sizeof(msgHeader_t));
	memcpy(cmdTunnel, &tunCmd, sizeof(msgTunnel_t));
	logDebug("Copied the command to " <<  (cmd == MSG_CREATETUNNEL ? "Create" : (cmd == MSG_CLOSETUNNEL ? "Close" : "Unknown")) << " Tunnel");
	return;
}

MessageFrame::MessageFrame(uint32_t cmd, const msgRespIPUserInfo_t &resp)
{
	frameLen = sizeof(msgHeader_t) + sizeof(msgRespIPUserInfo_t);
	__createFrame();
	if (NULL == buffer) {
		return;
	}
	cmdHeader->cmdType = cmd;
	respIPUserInfo = (msgRespIPUserInfo_t *)(buffer + sizeof(msgHeader_t));
	memcpy(respIPUserInfo, &resp, sizeof(msgRespIPUserInfo_t));
	return;
}

MessageFrame::MessageFrame(uint32_t cmd, const msgGetIPUserInfo_t & msgGet)
{
	frameLen = sizeof(msgHeader_t) + sizeof(msgGetIPUserInfo_t);
	__createFrame();
	if (NULL == buffer) {
		return;
	}
	cmdHeader->cmdType = cmd;
	cmdIPUserInfo = (msgGetIPUserInfo_t *)(buffer + sizeof(msgHeader_t));
	memcpy(cmdIPUserInfo, &msgGet, sizeof(msgGetIPUserInfo_t));
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
    	default:
    		os << "Command Not Found";
    		break;
    	}
    }
    return os;
}

