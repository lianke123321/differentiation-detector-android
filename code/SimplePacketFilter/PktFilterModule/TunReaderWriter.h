#ifndef TUNNELREADER_H_
#define TUNNELREADER_H_

#include "TunnelDevice.h"
#include "TunnelFrameQueue.h"

#define TUN_RW_READER 1
#define TUN_RW_WRITER 2

class TunReaderWriter
{
private:
	TunnelDevice *tunDev;
	const uint8_t mode;
	TunnelFrameQueue *frmQueue;
public:
	TunReaderWriter(uint8_t md, TunnelDevice *tDev, TunnelFrameQueue *fQ):mode(md), tunDev(tDev), frmQueue(fQ) {}
	virtual ~TunReaderWriter();
	bool mainLoop();
	void writerLoop();
	void readerLoop();
};

#endif /* TUNNELREADER_H_ */
