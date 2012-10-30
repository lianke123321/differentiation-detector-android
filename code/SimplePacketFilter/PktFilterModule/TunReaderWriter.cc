#include "TunReaderWriter.h"
#include "Logging.h"
#include "TunnelFrame.h"
#include "TunnelFrameQueue.h"

#if 0
TunReaderWriter::~TunReaderWriter()
{

}

void TunReaderWriter::readerLoop()
{
	TunnelFrame *tunFrame;
	while(1) {
		tunFrame = tunDev->readFrame();
		logDebug("Reader thread read a frame, now enqueueing the frame at ptr" << tunFrame);
		frmQueue->enqueue(tunFrame);
		logDebug("Enqueued the frame");
		tunFrame = NULL;
	}
	return;
}

void TunReaderWriter::writerLoop()
{
	TunnelFrame *tunFrame;
	uint32_t cnt = 5; // num retries;
	while(1) {
		logDebug("Writer thread waiting for a frame");
		tunFrame = frmQueue->dequeue();
		logDebug("Writer thread received a frame, now attempting a write");
		if (NULL == tunFrame) {
			logError("Got a NULL frame in queue");
			continue;
		}
		cnt = 5;
		while (cnt) {
			if (true == tunDev->writeFrame(tunFrame)) {
				break;
			}
			logDebug("Attempt to write failed attempt no:" << cnt);
			cnt = cnt -1 ;
		}
		if (cnt == 0) {
			logError("ERROR IN THE WRITE OPERATION");
			// TODO:: ERROR CHECK COMES HERE
		}
		logDebug("Wrote a frame, now deleting it");
		// TODO:: Is this the right place to do the delete... This is the last place this is referenced.
		delete tunFrame;
	}
	return;
}

bool TunReaderWriter::mainLoop()
{
	switch(mode) {
	case TUN_RW_READER:
		readerLoop();
		break;
	case TUN_RW_WRITER:
		writerLoop();
		break;
	default:
		return false;
	}
	return true;
}
#endif
