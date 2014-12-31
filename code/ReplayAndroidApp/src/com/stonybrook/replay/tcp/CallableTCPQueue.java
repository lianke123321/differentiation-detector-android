package com.stonybrook.replay.tcp;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.Semaphore;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.locks.Lock;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;

/**
 * Tried this to get exceptions from child thread so that parent thread can stop executing other child.
 * But this did not work out as I expected. 
 * @author rajesh
 *
 */

public class CallableTCPQueue {

	public AtomicBoolean flag = new AtomicBoolean();
	private ArrayList<RequestSet> Q = null;
	long timeOrigin;
	private Map<TCPClient, Lock> mLocks = new HashMap<TCPClient, Lock>();
	private Map<TCPClient, Semaphore> mSema = new HashMap<TCPClient, Semaphore>();
	private ArrayList<Thread> cThreadList = new ArrayList<Thread>();
	public volatile boolean done = false;
	public int threads = 0;
	List<Future> futures = new ArrayList<Future> ();
	ExecutorService executor = null;
	public CallableTCPQueue(ArrayList<RequestSet> q) {
		super();
		Q = q;
		this.flag.set(false);
		executor = Executors.newFixedThreadPool(q.size());
		
	}

	public boolean run(HashMap<String, TCPClient> cSPairMapping, Boolean timing) throws Exception {
		this.timeOrigin = System.currentTimeMillis();
		boolean success = true;
		try {
			int i = 1;
			int len = this.Q.size();
			for (RequestSet RS : this.Q) {

				// TODO : Check accuracy of this code

				// Lock lock = getLock(cSPairMapping.get(RS.getc_s_pair()));
				// while (!lock.tryLock());

				Semaphore sema = getSemaLock(cSPairMapping.get(RS.getc_s_pair()));
				sema.acquire();

				Log.d("TCPReplay", "Sending " + (i++) + "/" + len + " at time " + (System.currentTimeMillis() - timeOrigin) + " expected " + RS.getTimestamp() + " with response " + RS.getResponse_len());
				/*
				 * while
				 * (cSPairMapping.get(RS.getc_s_pair()).flag.compareAndSet(
				 * false, true)) ;
				 */

				next(cSPairMapping.get(RS.getc_s_pair()), RS, timing, sema);

				/*
				 * while (this.flag.compareAndSet(false, true)) ;
				 */
				//sync
				/*done = false;
				while(done);
				Log.d("Test1", "Before");*/
				
				synchronized (this) {
					this.wait();
				}
				
				
				/*synchronized (cSPairMapping.get(RS.getc_s_pair())) {
					cSPairMapping.get(RS.getc_s_pair()).wait();
				}*/
			}
			
			for(Future f : futures)
			{
				try {
			        f.get();
			    } catch (ExecutionException e) {
			    	executor.shutdownNow();
			        success = false;
			    }
			}
			
			Log.d("Sema", String.valueOf(mSema.size()) + " / " +  String.valueOf(cSPairMapping.size()));
			Log.d("Done", "Finished executing all Threads " + (System.currentTimeMillis() - timeOrigin));
			Log.d("count", String.valueOf(threads));
		} catch (Exception ex) {
			ex.printStackTrace();
			throw ex;
		}
		return success;
	}

	private Semaphore getSemaLock(TCPClient tcpClient) {
		Semaphore l = mSema.get(tcpClient);
		if (l == null) {
			l = new Semaphore(1);
			mSema.put(tcpClient, l);
		}
		return l;
	}

	private void next(TCPClient client, RequestSet RS, Boolean timing, Semaphore sema) throws Exception {

		if (timing) {
			double expectedTime = timeOrigin + RS.getTimestamp() * 1000;
			if (System.currentTimeMillis() < expectedTime) {
				long waitTime = Math.round(expectedTime - System.currentTimeMillis());
				Log.d("Time", String.valueOf(waitTime));
				if (waitTime > 0)
					Thread.sleep(waitTime);
			}
		}

		/*
		 * client.queue = this; client.RS = RS;
		 */
		CallableTCPClientThread clientThread = new CallableTCPClientThread(client, RS, this, sema, timeOrigin);
		//Thread cThread = new Thread(clientThread);
		futures.add(executor.submit(clientThread));
		//cThread.start();
		//threadList.add(cThread);
		++threads;
		Log.d("count", String.valueOf(threads));
		//cThreadList.add(cThread);
	}

}
