package com.stonybrook.replay.combined;

import java.io.IOException;
import java.net.DatagramPacket;
import java.nio.channels.DatagramChannel;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.util.Iterator;

import android.util.Log;

import com.stonybrook.replay.bean.JitterBean;
import com.stonybrook.replay.bean.UDPReplayInfoBean;

public final class CombinedReceiverThread implements Runnable{
	
	private UDPReplayInfoBean udpReplayInfoBean = null;
	private int bufSize = 4096;
	private long jitterTimeOrigin = 0;
	// changes of Arash
	public boolean keepRunning;
	
	// adrian: for jitter
	private JitterBean jitterBean = null;
	
	public CombinedReceiverThread(UDPReplayInfoBean udpReplayInfoBean,
			JitterBean jitterBean) {
		super();
		this.udpReplayInfoBean = udpReplayInfoBean;
		this.jitterBean = jitterBean;
		this.keepRunning = true;
	}

	@Override
	public void run() {
		
		this.jitterTimeOrigin = System.nanoTime();
		
		try {
			Selector selector = Selector.open();
			
			for (DatagramChannel channel : udpReplayInfoBean.getUdpSocketList())
				channel.register(selector, SelectionKey.OP_READ);
			
			while (keepRunning) {
				//Log.d("Receiver", "senderCount: " + udpReplayInfoBean.getSenderCount());
				Log.d("Receiver", String.valueOf(selector.selectNow()));
				if (selector.selectNow() > 0) {
					byte[] data = new byte[bufSize];
					DatagramPacket packet = new DatagramPacket(data, data.length);
					//Log.d("Receiver", "try to receive a udp packet");
					selector.select();
					Iterator<SelectionKey> selectedKeys = selector.selectedKeys().iterator();
					while (selectedKeys.hasNext()) {
						SelectionKey key = (SelectionKey) selectedKeys.next();
						selectedKeys.remove();
						DatagramChannel tempChannel = (DatagramChannel) key.channel();
						tempChannel.socket().receive(packet);
						
						// for receive jitter
						long currentTime = System.nanoTime();
						Log.d("rcvdJitter", String.valueOf(currentTime-jitterTimeOrigin));
						Log.d("rcvdJitter", String.valueOf((double)(currentTime-jitterTimeOrigin) / 1000000000));
						synchronized (jitterBean) {
							jitterBean.rcvdJitter += (String.valueOf((double)(currentTime-jitterTimeOrigin)
									/ 1000000000) + "\t" + data + "\n");
						}
						this.jitterTimeOrigin = currentTime;
					}
					data = null;
				}
				
				/*while (true) {
					udpReplayInfoBean.pollCloseQ();
					if (!udpReplayInfoBean.getCloseQ().isEmpty()) {
						//udpReplayInfoBean.decrement();
						Log.d("Receiver", "decremented one from senderCount: " +
								udpReplayInfoBean.getSenderCount());
					} else 
						break;
				}*/
				
				/**
				 * adrian: force data to clean and sleep 2 seconds every iteration.
				 * in order to solve the memory free problem
				 */
				Thread.sleep(500);
				
			}
		} catch (IOException e1) {
			Log.d("Receiver", "receiving udp packet error!");
			e1.printStackTrace();
		} catch (InterruptedException e) {
			Log.d("Receiver", "sleep went wrong!");
			e.printStackTrace();
		}
		
		Log.d("Receiver", "finished!");
	}

}
