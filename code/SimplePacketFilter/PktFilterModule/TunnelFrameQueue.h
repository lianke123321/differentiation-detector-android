#ifndef TUNNELFRAMEQUEUE_H_
#define TUNNELFRAMEQUEUE_H_

#include <queue>
#include <boost/thread.hpp>
#include "TunnelFrame.h"

// TODO:: This can be made to a template
// Taken from http://www.justsoftwaresolutions.co.uk/threading/implementing-a-thread-safe-queue-using-condition-variables.html to handle boost::mutex and cond variables rather than counting semaphores
// http://stackoverflow.com/questions/2350544/in-what-situation-do-you-use-a-semaphore-over-a-mutex-in-c why counting semaphores are not present in boost libraries

class TunnelFrameQueue
{
	std::queue<TunnelFrame *> tfQueue;
	boost::mutex tfqMutex;
	boost::condition_variable tfqCond;
public:
	TunnelFrameQueue();
	void enqueue(TunnelFrame * frame);
	TunnelFrame * dequeue();
	uint32_t length();
	virtual ~TunnelFrameQueue();
};

#endif /* TUNFRAMEQUEUE_H_ */
