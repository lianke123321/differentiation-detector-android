package com.stonybrook.replay.combined;

import java.io.IOException;
import java.net.DatagramPacket;
import java.nio.channels.DatagramChannel;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.util.Iterator;

import android.util.Log;

import com.stonybrook.replay.bean.UDPReplayInfoBean;

public final class CombinedReceiverThread implements Runnable{
	
	private UDPReplayInfoBean udpReplayInfoBean = null;
	private int bufSize = 4096;
	
	public CombinedReceiverThread(UDPReplayInfoBean udpReplayInfoBean) {
		super();
		this.udpReplayInfoBean = udpReplayInfoBean;
	}

	@Override
	public void run() {
		
		try {
			Selector selector = Selector.open();
			
			for (DatagramChannel channel : udpReplayInfoBean.getUdpSocketList())
				channel.register(selector, SelectionKey.OP_READ);
			
			while (udpReplayInfoBean.getSenderCount() > 0) {
				
				//Log.d("Receiver", "senderCount: " + udpReplayInfoBean.getSenderCount());
				
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
