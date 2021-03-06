package mobi.meddle.diffdetector.combined;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Semaphore;

import mobi.meddle.diffdetector.bean.JitterBean;
import mobi.meddle.diffdetector.bean.RequestSet;
import mobi.meddle.diffdetector.bean.ServerInstance;
import mobi.meddle.diffdetector.bean.UDPReplayInfoBean;
import mobi.meddle.diffdetector.bean.UpdateUIBean;
import android.util.Log;


/**
 * This loads and de-serializes all necessary objects. Complicated. I'll have to
 * think what I did here. May be comments in python client can be helpful.
 * 
 */
public class CombinedQueue {

	// public AtomicBoolean flag = new AtomicBoolean();
	private ArrayList<RequestSet> Q = null;
	long timeOrigin;
	long jitterTimeOrigin;
	private Semaphore sendSema = null;
	private Map<CTCPClient, Semaphore> recvSemaMap = new HashMap<CTCPClient, Semaphore>();
	private ArrayList<Thread> cThreadList = new ArrayList<Thread>();
	// public volatile boolean done = false;
	public int threads = 0;
	// ArrayList<Thread> threadList = new ArrayList<Thread>();

	// for jitter
	JitterBean jitterBean = null;

	// for indicating abortion!
	public volatile boolean ABORT = false;
	public volatile String abort_reason = null;

	public CombinedQueue(ArrayList<RequestSet> q, JitterBean jitterBean) {
		super();
		this.Q = q;
		this.jitterBean = jitterBean;
		this.sendSema = new Semaphore(1);
		// this.flag.set(false);
	}

	/**
	 * Python Client comments For every TCP packet: 1- Wait until client.event
	 * is set --> client is not receiving a response 2- Send tcp payload [and
	 * receive response] by calling next 3- Wait until send_event is set -->
	 * sending is done
	 * 
	 * @param cSPairMapping
	 * @param timing
	 * @throws Exception
	 */
	public void run(UpdateUIBean updateUIBean,
			HashMap<String, CTCPClient> CSPairMapping,
			HashMap<String, CUDPClient> udpPortMapping,
			UDPReplayInfoBean udpReplayInfoBean,
			HashMap<String, HashMap<String, ServerInstance>> udpServerMapping,
			Boolean timing, String server) throws Exception {
		this.timeOrigin = System.nanoTime();
		this.jitterTimeOrigin = System.nanoTime();

		try {
			// for calculating packets
			int i = 1;
			// for jitter
			int m = 0;
			double len = this.Q.size();
			// @@@ start all the treads here
			for (RequestSet RS : this.Q) {

				if (RS.getResponse_len() == -1) {
					// adrian: sending udp is done in queue thread, no need to
					// start
					// new threads for udp since there is only one port
					Log.d("Replay", "Sending udp packet " + (i++) + "/" + len
							+ " at time " + (System.nanoTime() - timeOrigin)
							/ 1000000);
					nextUDP(RS, udpPortMapping, udpReplayInfoBean,
							udpServerMapping, timing, server, m);
					m++;

					// adrian: for updating progress bar
					updateUIBean.setProgress((int) ((i * 100) / len));

				} else {
					Semaphore recvSema = getRecvSemaLock(CSPairMapping.get(RS
							.getc_s_pair()));
					// Log.d("Replay", "waiting to get receive semaphore!");
					recvSema.acquire();
					// Log.d("Replay", "got the receive semaphore!");

					Log.d("Replay", "Sending tcp packet " + (i++) + "/" + len
							+ " at time " + (System.nanoTime() - timeOrigin)
							/ 1000000);

					// adrian: for updating progress bar
					updateUIBean.setProgress((int) ((i * 100) / len));

					// adrian: every time when calling next we create and start
					// a new thread
					// adrian: here we start different thread according to the
					// type of RS
					nextTCP(CSPairMapping.get(RS.getc_s_pair()), RS, timing,
							sendSema, recvSema);

					sendSema.acquire();

				}

				if (ABORT == true) {
					Log.d("Queue", "replay aborted!");
					break;
				}
			}

			Log.d("Queue", "waiting for all threads to die!");
			for (Thread t : cThreadList)
				t.join();

			Log.d("Queue",
					"Finished executing all Threads "
							+ (System.nanoTime() - timeOrigin) / 1000000);
		} catch (Exception ex) {
			ex.printStackTrace();
			throw ex;
		}
	}

	// adrian: this is the semaphore for receiving packet
	private Semaphore getRecvSemaLock(CTCPClient client) {
		Semaphore l = recvSemaMap.get(client);
		if (l == null) {
			l = new Semaphore(1);
			recvSemaMap.put(client, l);
		}
		return l;
	}

	/**
	 * Call the client thread which will send the payload and receive the
	 * response for RequestSet
	 * 
	 * @param client
	 * @param RS
	 * @param timing
	 * @param sema
	 * @throws Exception
	 */
	private void nextTCP(CTCPClient client, RequestSet RS, Boolean timing,
			Semaphore sendSema, Semaphore recvSema) throws Exception {

		// package this TCPClient into a TCPClientThread, then put it into a
		// thread
		CTCPClientThread clientThread = new CTCPClientThread(client, RS, this,
				sendSema, recvSema, timeOrigin, 100);
		Thread cThread = new Thread(clientThread);

		// if timing is set to be true, wait until expected Time to send
		// this packet
		if (timing) {
			double expectedTime = timeOrigin + RS.getTimestamp() * 1000000000;
			if (System.nanoTime() < expectedTime) {
				long waitTime = Math.round(expectedTime - System.nanoTime()) / 1000000;
				// Log.d("Time", String.valueOf(waitTime));
				if (waitTime > 0)
					Thread.sleep(waitTime);
			}
		}

		cThread.start();
		// threadList.add(cThread);
		++threads;
		// Log.d("nextTCP", "number of thread: " + String.valueOf(threads));
		cThreadList.add(cThread);
	}

	private void nextUDP(RequestSet RS,
			HashMap<String, CUDPClient> udpPortMapping,
			UDPReplayInfoBean udpReplayInfoBean,
			HashMap<String, HashMap<String, ServerInstance>> udpServerMapping,
			Boolean timing, String server, int m) throws Exception {
		String c_s_pair = RS.getc_s_pair();
		String clientPort = c_s_pair.substring(16, 21);
		String dstIP = c_s_pair.substring(22, 37);
		String dstPort = c_s_pair.substring(38, 43);
		/*
		 * String destIP = c_s_pair.substring(c_s_pair.lastIndexOf('-') + 1,
		 * c_s_pair.lastIndexOf(".")); String destPort =
		 * c_s_pair.substring(c_s_pair.lastIndexOf('.') + 1, c_s_pair.length());
		 */
		// Log.d("nextUDP", "dstIP: " + dstIP + " dstPort: " + dstPort);
		ServerInstance destAddr = udpServerMapping.get(dstIP).get(dstPort);

		if (destAddr.server.trim().equals(""))
			destAddr.server = server;

		CUDPClient client = udpPortMapping.get(clientPort);

		if (client.channel == null) {
			client.createSocket();
			udpReplayInfoBean.addSocket(client.channel);
			// Log.d("nextUDP", "read senderCount: " +
			// udpReplayInfoBean.getSenderCount());

		}

		if (timing) {
			double expectedTime = timeOrigin + RS.getTimestamp() * 1000000000;
			if (System.nanoTime() < expectedTime) {
				long waitTime = Math
						.round((expectedTime - System.nanoTime()) / 1000000);
				// Log.d("Time", String.valueOf(waitTime));
				if (waitTime > 0)
					Thread.sleep(waitTime);
			}
		}

		// update sentJitter
		long currentTime = System.nanoTime();
		synchronized (jitterBean) {
			jitterBean.sentJitter
					.add(String
							.valueOf((double) (currentTime - jitterTimeOrigin) / 1000000000));
			jitterBean.sentPayload.add(RS.getPayload());
		}
		jitterTimeOrigin = currentTime;

		// adrian: send packet
		try {
			client.sendUDPPacket(RS.getPayload(), destAddr);
		} catch (Exception e) {
			Log.d("sendUDP", "something bad happened!");
			e.printStackTrace();
			ABORT = true;
			abort_reason = "Replay Aborted: " + e.getMessage();
		}

	}

}
