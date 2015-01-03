package com.stonybrook.replay.combined;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Semaphore;
import java.util.concurrent.atomic.AtomicBoolean;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;
import com.stonybrook.replay.bean.ServerInstance;
import com.stonybrook.replay.bean.UDPReplayInfoBean;
import com.stonybrook.replay.bean.UpdateUIBean;
//import java.util.concurrent.locks.Lock;
//import java.util.concurrent.locks.ReentrantLock;
//import android.graphics.Paint.Join;

/**
 * This loads and de-serializes all necessary objects.
 * Complicated. I'll have to think what I did here. May be comments in python client can be helpful.
 * TODO: Find a way to get exceptions from child threads. Difficult than it looks. Tried using
 * Callable Thread but it did not work out. Callbacks can be used. When child thread gets Exception,
 * it can callback to parent which can stop executing other threads and return Error to AsyncTask. 
*/
public class CombinedQueue {

	public AtomicBoolean flag = new AtomicBoolean();
	private ArrayList<RequestSet> Q = null;
	long timeOrigin;
	private Map<CTCPClient, Semaphore> mSema = new HashMap<CTCPClient, Semaphore>();
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
	public void run(UpdateUIBean updateUIBean,
			HashMap<String, CTCPClient> CSPairMapping,
			HashMap<String, CUDPClient> udpPortMapping,
			UDPReplayInfoBean udpReplayInfoBean,
			HashMap<String, HashMap<String, ServerInstance>> udpServerMapping,
			Boolean timing) throws Exception {
		this.timeOrigin = System.currentTimeMillis();
		
		try {
			int i = 1;
			int len = this.Q.size();
			// @@@ start all the treads here
			for (RequestSet RS : this.Q) {
				
				if (RS.getResponse_len() == -1) {
					nextUDP(RS, udpPortMapping, udpReplayInfoBean, udpServerMapping, timing);
					Log.d("Replay", "Sending udp packet " + (i++) + "/" + len +
							" at time " + (System.currentTimeMillis() - timeOrigin));
					
					// adrian: for updating progress bar
					updateUIBean.setProgress((int) (i * 100 / len));
					
				} else { 
					Semaphore sema = getSemaLock(CSPairMapping.get(RS.getc_s_pair()));
					sema.acquire();
	
					Log.d("Replay", "Sending tcp packet " + (i++) + "/" + len +
							" at time " + (System.currentTimeMillis() - timeOrigin));
					
					// adrian: for updating progress bar
					updateUIBean.setProgress((int) (i * 100 / len));
					
					// adrian: every time when calling next we create and start a new thread
					// adrian: here we start different thread according to the type of RS
					nextTCP(CSPairMapping.get(RS.getc_s_pair()), RS, timing, sema);
	
					
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

	private Semaphore getSemaLock(CTCPClient client) {
		Semaphore l = mSema.get(client);
		if (l == null) {
			l = new Semaphore(1);
			mSema.put(client, l);
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
	private void nextTCP(CTCPClient client, RequestSet RS, Boolean timing,
			Semaphore sema) throws Exception {

		// @@@ if timing is set to be true, wait until expected Time to send this packet
		if (timing) {
			double expectedTime = timeOrigin + RS.getTimestamp() * 1000;
			if (System.currentTimeMillis() < expectedTime) {
				long waitTime = Math.round(expectedTime - System.currentTimeMillis());
				//Log.d("Time", String.valueOf(waitTime));
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
		Log.d("nextTCP", "number of thread: " + String.valueOf(threads));
		cThreadList.add(cThread);
	}
	
	private void nextUDP(RequestSet RS, HashMap<String, CUDPClient> udpPortMapping,
			UDPReplayInfoBean udpReplayInfoBean,
			HashMap<String, HashMap<String, ServerInstance>> udpServerMapping, 
			Boolean timing) throws Exception {
		String c_s_pair = RS.getc_s_pair();
		String clientPort = c_s_pair.substring(16, 21).replaceFirst("^0+(?!$)", "");
		String dstIP = c_s_pair.substring(22, 37);
		String dstPort = c_s_pair.substring(38, 43).replaceFirst("^0+(?!$)", "");
		/*String destIP = c_s_pair.substring(c_s_pair.lastIndexOf('-') + 1,
				c_s_pair.lastIndexOf("."));
		String destPort = c_s_pair.substring(c_s_pair.lastIndexOf('.') + 1,
				c_s_pair.length());*/
		//Log.d("nextUDP", "dstIP: " + dstIP + " dstPort: " + dstPort);
		ServerInstance destAddr = udpServerMapping.get(dstIP).get(dstPort);
		CUDPClient client = udpPortMapping.get(clientPort);
		
		if (client.socket == null) {
			client.createSocket();
			udpReplayInfoBean.addSocket(client.socket);
			//Log.d("nextUDP", "read senderCount: " + udpReplayInfoBean.getSenderCount());
			
		}
		
		if (timing) {
			double expectedTime = timeOrigin + RS.getTimestamp() * 1000;
			if (System.currentTimeMillis() < expectedTime) {
				long waitTime = Math.round(expectedTime - System.currentTimeMillis());
				//Log.d("Time", String.valueOf(waitTime));
				if (waitTime > 0)
					Thread.sleep(waitTime);
			}
		}
		
		// TODO: send_jitter?
		
		client.sendUDPPacket(RS.getPayload(), destAddr);
		
	}
	
}
