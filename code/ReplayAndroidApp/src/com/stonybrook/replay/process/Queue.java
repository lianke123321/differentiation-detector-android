package com.stonybrook.replay.process;

import java.util.LinkedList;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;

/**
 * This is the class which sends out the packets in the queue one-by-one.
    Before sending each packets, it makes sure:
        1- All previous packets in the queue are sent
        2- All previous responses on the same connection are received
        3- Packet timestamp has passed (it's time to send the packet)
    Once all the above are satisfied, it fires of a SendRecv thread.
 * @author rajesh
 *
 */
public class Queue {
	java.util.Queue<RequestSet> queue;
	
	/**
	 *  sendlist: before sending a payload, we append the corresponding c_s_pair to this list.
                  Once the payload is fully sent, c_s_pair is poped (happens in send_single_request) 
                  and sendlist becomes empty. In other words, if sendlist is NOT empty, that means we 
                  are in the process of sending a payload and next packet needs to wait.
                  So we use this to satisfy condition "1" mentioned above
        waitlist: it contains c_s_pairs which are waiting for a response. So whenever we send a
                  payload, we add the corresponding c_s_pair to this list. Once the response of 
                  that payload is fully received, c_s_pair is removed from the waitlist.
                  So we use this to satisfy condition "2" mentioned above
	 */
	
	java.util.Queue<String> waitList;
	java.util.Queue<String> sendList;
	long timeOrigin;
	Connections connections;
	
	public Queue(java.util.Queue<RequestSet> queue) {
		this.queue = queue;
		waitList = new LinkedList<String>();
		sendList = new LinkedList<String>();
		timeOrigin = 0;
		connections = new Connections();
	}

	/**
	 * 
	 * @param queue
	 * @throws Exception
	 */
	public void run(java.util.Queue<RequestSet> queue) throws Exception {
		int packetCnt;
		try
		{
			timeOrigin = System.nanoTime();
			packetCnt = queue.size();
			//Log.d("packetCnt", String.valueOf(packetCnt));
			
			int i = 0;
			while(!queue.isEmpty())
			{
				next(queue.peek(), i++);
				synchronized (waitList) {
					waitList.wait();
				}
			}
		}
		catch(Exception e)
		{
			e.printStackTrace();
			Log.e("Replay", e.getMessage());
			throw e;
		}
	}
	
	public void next(RequestSet q, int i) throws Exception
	{
		SendRecv sendRecv ;
		try
		{
			if(sendList.size() == 0)
			{
				
				if(!waitList.contains(q.getc_s_pair()))
				{
					Log.d("Waitlist", q.getc_s_pair() + " --- " + q.getTimestamp());
					double expectedTime = timeOrigin + q.getTimestamp()*1000000000;
					if(System.nanoTime() < expectedTime )
					{
						long waitTime =  Math.round(expectedTime - System.nanoTime()) / 1000000;
						waitTime = (waitTime > 0) ? waitTime : 0;
						Thread.sleep(waitTime);
					}
					queue.remove();
					waitList.add(q.getc_s_pair());
					sendList.add(q.getc_s_pair());
					sendRecv = new SendRecv(q, waitList, sendList, connections);
					//MainActivity.logText("Sending packet " + packets + " with CSPair " + q.getc_s_pair());
					sendRecv.start();
					
				}
			}
		}
		catch(Exception e)
		{
			e.printStackTrace();
			Log.e("Replay", e.getMessage());
			throw e;
		}
		
	}
	
}