#include "CommandFrame.h"
#include "Logging.h"
#include <iostream>
#include <string.h>

CommandFrame::CommandFrame()
{
	buffer = NULL; frameLen = 0; cmdHeader = NULL; cmdTunnel = NULL;
	return;
}

CommandFrame::~CommandFrame()
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

CommandFrame::CommandFrame(uint8_t *payload, uint32_t len)
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

inline void CommandFrame::__parseCommand()
{
	cmdHeader = (cmdHeader_t *) (buffer);
	switch(cmdHeader->cmdType) {
	case CMD_ACK_NEGATIVE:
	case CMD_ACK_POSITIVE:
		break;
	case CMD_CREATETUNNEL:
	case CMD_CLOSETUNNEL:
		logDebug("Parsing command to " << (cmdHeader->cmdType == CMD_CREATETUNNEL? "CREATE " : "CLOSE ") <<  "Tunnel");
		cmdTunnel = (cmdTunnel_t *)(buffer + sizeof(cmdHeader_t));
		break;
	default:
		logError("Command not supported");
		break;
	}
	return;
}

CommandFrame::CommandFrame(uint32_t cmd, cmdTunnel_t tunCmd)
{
	frameLen = sizeof(cmdHeader_t) + sizeof(cmdTunnel_t);
	buffer = new uint8_t [frameLen];
	if (NULL == buffer) {
		logError("Error allocating memory");
		buffer = NULL;
		frameLen = -1;
		return;
	}
	logDebug("Allocated memory of FramLength " <<  frameLen);
	memset(buffer, 0, frameLen);
	cmdHeader = (cmdHeader_t *) (buffer);
	cmdHeader->cmdLen = frameLen;
	cmdHeader->cmdType = cmd;
	cmdTunnel = (cmdTunnel_t *)(buffer + sizeof(cmdHeader_t));
	memcpy(cmdTunnel, &tunCmd, sizeof(cmdTunnel_t));
	logDebug("Copied the command to " <<  (cmd == CMD_CREATETUNNEL ? "Create" : (cmd == CMD_CLOSETUNNEL ? "Close" : "Unknown")) << " Tunnel");
	return;
}

CommandFrame::CommandFrame(cmd_ack_t cmd)
{
	frameLen = sizeof(cmdHeader_t);
	buffer = new uint8_t [frameLen];
	if (NULL == buffer) {
			logError("Error allocating memory");
			buffer = NULL;
			frameLen = -1;
			return;
	}
	memset(buffer, 0, frameLen);
	cmdHeader = (cmdHeader_t *) (buffer);
	cmdHeader->cmdLen = frameLen;
	cmdHeader->cmdType = (uint32_t)cmd;
	return;
}

std::ostream& operator<<(std::ostream& os, const CommandFrame& cmd)
{
    os << "Length " << cmd.frameLen << " Address " << static_cast<void*>(cmd.buffer) << " ";
    if (cmd.frameLen > 0)  {
    	switch (cmd.cmdHeader->cmdType) {
    	case CMD_ACK_NEGATIVE:
    		os << " Received Negative ack";
    		break;
    	case CMD_ACK_POSITIVE:
    		os << "Receive Positive ack";
    		break;
    	case CMD_CREATETUNNEL:
    	case CMD_CLOSETUNNEL:
    		os << (cmd.cmdHeader->cmdType == CMD_CREATETUNNEL? "CREATE " : "CLOSE ")
    		   << cmd.cmdTunnel->ipAddress << " " << cmd.cmdTunnel->userName << " " << cmd.cmdTunnel->userNameLen;
    		break;
    	default:
    		os << "Command Not Found";
    		break;
    	}
    }
    return os;
}

