package com.stonybrook.replay.combined;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.DatagramChannel;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.util.Iterator;

import android.util.Log;

import com.stonybrook.replay.bean.JitterBean;
import com.stonybrook.replay.bean.UDPReplayInfoBean;

public final class CombinedReceiverThread implements Runnable {

	private UDPReplayInfoBean udpReplayInfoBean = null;
	private int bufSize = 4096;
	private long jitterTimeOrigin = 0;
	// changes of Arash
	public volatile boolean keepRunning;
	private int timeout = 1000;

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

			while (keepRunning) {
				/*Log.d("Receiver", "size of udpSocketList: " +
						udpReplayInfoBean.getUdpSocketList().size());*/
				
				for (DatagramChannel channel : udpReplayInfoBean.getUdpSocketList()) {
					channel.register(selector, SelectionKey.OP_READ);
					/*if (!channel.isConnected())
						Log.d("Receiver", "channel not connected!");*/
				}
				
				// Log.d("Receiver", "senderCount: " +
				// udpReplayInfoBean.getSenderCount());
				// Log.d("Receiver", String.valueOf(selector.selectNow()));
				if (selector.select(timeout) == 0) {
					//Log.d("Receiver", "no socket has data");
					continue;
				}
				// byte[] data = new byte[bufSize];
				// DatagramPacket packet = new DatagramPacket(data,
				// data.length);
				//Log.d("Receiver", "ready to receive packet!");
				ByteBuffer buf = ByteBuffer.allocate(bufSize);
				buf.clear();
				Iterator<SelectionKey> selectedKeys = selector.selectedKeys().iterator();
				while (selectedKeys.hasNext()) {
					SelectionKey key = selectedKeys.next();
					DatagramChannel tmpChannel = (DatagramChannel) key.channel();
					tmpChannel.receive(buf);

					// for receive jitter
					long currentTime = System.nanoTime();
					/*Log.d("rcvdJitter",
							String.valueOf(currentTime - jitterTimeOrigin));
					Log.d("rcvdJitter",
							String.valueOf((double) (currentTime - jitterTimeOrigin) / 1000000000));*/
					synchronized (jitterBean) {
						jitterBean.rcvdJitter += (String
								.valueOf((double) (currentTime - jitterTimeOrigin) / 1000000000)
								+ "\t" + buf.hashCode() + "\n");
					}
					this.jitterTimeOrigin = currentTime;
					selectedKeys.remove();
				}
				buf = null;

				/*
				 * while (true) { udpReplayInfoBean.pollCloseQ(); if
				 * (!udpReplayInfoBean.getCloseQ().isEmpty()) {
				 * //udpReplayInfoBean.decrement(); Log.d("Receiver",
				 * "decremented one from senderCount: " +
				 * udpReplayInfoBean.getSenderCount()); } else break; }
				 */
				
			}

			selector.close();
		} catch (IOException e1) {
			Log.d("Receiver", "receiving udp packet error!");
			e1.printStackTrace();
		}

		Log.d("Receiver", "finished!");
	}

}
