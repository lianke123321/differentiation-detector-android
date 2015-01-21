package com.stonybrook.replay.combined;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.SocketAddress;
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
	private int TIME_OUT = 1000;

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
			ByteBuffer buf = ByteBuffer.allocate(bufSize);
			byte[] buff = new byte[bufSize];

			while (keepRunning) {

				/*
				 * Log.d("Receiver", "size of udpSocketList: " +
				 * udpReplayInfoBean.getUdpSocketList().size());
				 */

				for (DatagramChannel channel : udpReplayInfoBean
						.getUdpSocketList()) {
					channel.register(selector, SelectionKey.OP_READ);
				}

				// Log.d("Receiver", "senderCount: " +
				// udpReplayInfoBean.getSenderCount());
				if (selector.select(TIME_OUT) == 0) {
					// Log.d("Receiver", "no socket has data");
					continue;
				}
				// Log.d("Receiver", "got it!");

				Iterator<SelectionKey> selectedKeys = selector.selectedKeys()
						.iterator();
				while (selectedKeys.hasNext()) {
					SelectionKey key = selectedKeys.next();
					DatagramChannel tmpChannel = (DatagramChannel) key
							.channel();
					
					if (tmpChannel.receive(buf) != null) {
						byte[] data = new byte[buf.position()];
						buf.position(0);
						buf.get(data);
						// Log.d("Receiver", "length of data: " + data.length);

						// for receive jitter
						long currentTime = System.nanoTime();

						synchronized (jitterBean) {
							jitterBean.rcvdJitter
									.add(String
											.valueOf((double) (currentTime - jitterTimeOrigin) / 1000000000));
							jitterBean.rcvdPayload.add(data);
							// Log.d("Receiver",
							// String.valueOf(jitterBean.rcvdJitter.size()));
						}
						this.jitterTimeOrigin = currentTime;
					}
					selectedKeys.remove();
				}

				buf.clear();
			}

			selector.close();
		} catch (IOException e1) {
			Log.d("Receiver", "receiving udp packet error!");
			e1.printStackTrace();
		}

		Log.d("Receiver",
				"finished! Packets received: "
						+ String.valueOf(jitterBean.rcvdJitter.size()));
	}
}
