package com.stonybrook.replay.combined;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Semaphore;
import java.util.concurrent.atomic.AtomicBoolean;
//import java.util.concurrent.locks.Lock;
//import java.util.concurrent.locks.ReentrantLock;

//import android.graphics.Paint.Join;
import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;

/**
 * This loads and de-serializes all necessary objects.
 * Complicated. I'll have to think what I did here. May be comments in python client can be helpful.
 * TODO: Find a way to get exceptions from child threads. Difficult than it looks. Tried using Callable Thread but it did not work out.
 * Callbacks can be used. When child thread gets Exception, it can callback to parent which can stop executing other threads and return Error to AsyncTask. 
*/
public class CombinedQueue {

	public AtomicBoolean flag = new AtomicBoolean();
	private ArrayList<RequestSet> Q = null;
	long timeOrigin;
	// @@@ comment this out, not used
	//private Map<TCPClient, Lock> mLocks = new HashMap<TCPClient, Lock>();
	private Map<TCPClient, Semaphore> mSema = new HashMap<TCPClient, Semaphore>();
	private ArrayList<Thread> cThreadList = new ArrayList<Thread>();
	public volatile boolean done = false;
	public int threads = 0;
	ArrayList<Thread> threadList = new ArrayList<Thread>(); 
	public CombinedQueue(ArrayList<RequestSet> q) {
		super();
		Q = q;
		this.flag.set(false);
	}

	/**
	 * Python Client comments
	 * For every TCP packet:
                1- Wait until client.event is set --> client is not receiving a response
                2- Send tcp payload [and receive response] by calling next
                3- Wait until send_event is set --> sending is done
	 * @param cSPairMapping
	 * @param timing
	 * @throws Exception
	 */
	public void run(HashMap<String, TCPClient> cSPairMapping, HashMap<String, UDPClient> udpPortMapping, Boolean timing) throws Exception {
		this.timeOrigin = System.currentTimeMillis();
		try {
			int i = 1;
			int len = this.Q.size();
			// @@@ start all the treads here
			for (RequestSet RS : this.Q) {
				
				if (RS.getResponse_len() == -1)
					nextUDP(RS, udpSocketList);
				else { 
					Semaphore sema = getSemaLock(cSPairMapping.get(RS.getc_s_pair()));
					sema.acquire();
	
					//Log.d("Replay", "Sending " + (i++) + "/" + len + " at time " + (System.currentTimeMillis() - timeOrigin) + " expected " + RS.getTimestamp() + " with response " + RS.getResponse_len());
	
					// adrian: every time when calling next we create and start a new thread
					// adrian: here we start different thread according to the type of RS
					nextTCP(cSPairMapping.get(RS.getc_s_pair()), RS, timing, sema);
	
					
					synchronized (this) {
						this.wait();
					}
				}
				
			}
			
			//Wait for all threads to finish processing
			// @@@ in other words, wait for every thread to die
			for(Thread t : cThreadList)
				t.join();
			
			Log.d("Replay", "Finished executing all Threads " + (System.currentTimeMillis() - timeOrigin));
		} catch (Exception ex) {
			ex.printStackTrace();
			throw ex;
		}
	}

	private Semaphore getSemaLock(TCPClient tcpClient) {
		Semaphore l = mSema.get(tcpClient);
		if (l == null) {
			l = new Semaphore(1);
			mSema.put(tcpClient, l);
		}
		return l;
	}

	/**
	 * Call the client thread which will send the payload and receive the response for RequestSet
	 * @param client
	 * @param RS
	 * @param timing
	 * @param sema
	 * @throws Exception
	 */
	private void nextTCP(TCPClient client, RequestSet RS, Boolean timing, Semaphore sema) throws Exception {

		// @@@ if timing is set to be true, wait until expected Time to send this packet
		if (timing) {
			double expectedTime = timeOrigin + RS.getTimestamp() * 1000;
			if (System.currentTimeMillis() < expectedTime) {
				long waitTime = Math.round(expectedTime - System.currentTimeMillis());
				Log.d("Time", String.valueOf(waitTime));
				if (waitTime > 0)
					Thread.sleep(waitTime);
			}
		}

		// @@@ package this TCPClient into a TCPClientThread, then put it into a thread
		CTCPClientThread clientThread = new CTCPClientThread(client, RS, this, sema, timeOrigin);
		Thread cThread = new Thread(clientThread);
		cThread.start();
		threadList.add(cThread);
		++threads;
		Log.d("count", String.valueOf(threads));
		cThreadList.add(cThread);
	}
	
	private void nextUDP(RequestSet RS, udpSocketList, Boolean timing) throws Exception {
		String c_s_pair = RS.getc_s_pair();
		String clientPort = c_s_pair.substring(16, 21);
		String destIP = c_s_pair.substring(c_s_pair.lastIndexOf('-') + 1,
				c_s_pair.lastIndexOf("."));
		String destPort = c_s_pair.substring(c_s_pair.lastIndexOf('.') + 1,
				c_s_pair.length());
		
		String destAddr = serverPortsMap.get("udp").get("destIP").get("destPort");
		CUDPClient client = udpPortMapping.get(clientPort);
		
		if (client.socket == null)
			client.createSocket();
		
		if (timing) {
			double expectedTime = timeOrigin + RS.getTimestamp() * 1000;
			if (System.currentTimeMillis() < expectedTime) {
				long waitTime = Math.round(expectedTime - System.currentTimeMillis());
				Log.d("Time", String.valueOf(waitTime));
				if (waitTime > 0)
					Thread.sleep(waitTime);
			}
		}
		
		client.sendUDPPacket(RS.payload, destIP, destPort);
		
		
		
	}

}
