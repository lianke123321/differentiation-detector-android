#include "TunnelFrameQueue.h"
#include "Macros.h"
#include "Logging.h"

TunnelFrameQueue::TunnelFrameQueue()
{
	// TODO Auto-generated constructor stub
	return;
}

TunnelFrameQueue::~TunnelFrameQueue()
{
	// TODO Flush queue here
	return;
}

void TunnelFrameQueue::enqueue(TunnelFrame *frame)
{
	boost::mutex::scoped_lock scopedLock(tfqMutex);
	tfQueue.push(frame);
	scopedLock.unlock();
	tfqCond.notify_one();
}

TunnelFrame * TunnelFrameQueue::dequeue()
{
	boost::mutex::scoped_lock scopedLock(tfqMutex);
	TunnelFrame *popVal;
	while(tfQueue.empty()) {
		tfqCond.wait(scopedLock);
	}
	popVal = tfQueue.front();
	logDebug("Pointer of the frame is "<<popVal);
	tfQueue.pop();
	logDebug("Pointer of the frame after pop is "<<popVal);
	return popVal;
}
uint32_t TunnelFrameQueue::length()
{
	boost::mutex::scoped_lock scopedLock(tfqMutex);
	uint32_t len = tfQueue.size();
	return len;
}
