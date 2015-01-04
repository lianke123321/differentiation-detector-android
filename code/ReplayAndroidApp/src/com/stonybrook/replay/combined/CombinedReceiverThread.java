package com.stonybrook.replay.combined;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;

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
		while (udpReplayInfoBean.getSenderCount() > 0) {
			
			//Log.d("Receiver", "senderCount: " + udpReplayInfoBean.getSenderCount());
			
			for (DatagramSocket socket : udpReplayInfoBean.getUdpSocketList()) {
				byte[] data = new byte[bufSize];
				DatagramPacket packet = new DatagramPacket(data, data.length);
				try {
					//Log.d("Receiver", "try to receive a udp packet");
					socket.receive(packet);
				} catch (IOException e) {
					Log.d("Receiver", "receiving udp packet error!");
					e.printStackTrace();
				}
				data = null;
			}
			
			while (true) {
				udpReplayInfoBean.pollCloseQ();
				if (!udpReplayInfoBean.getCloseQ().isEmpty()) {
					//udpReplayInfoBean.decrement();
					Log.d("Receiver", "decremented one from senderCount: " +
							udpReplayInfoBean.getSenderCount());
				} else 
					break;
			}
			
			/**
			 * adrian: force data to clean and sleep 2 seconds every iteration.
			 * in order to solve the memory free problem
			 */
			try {
				Thread.sleep(2000);
			} catch (InterruptedException e) {
				Log.d("Receiver", "sleep went wrong!");
				e.printStackTrace();
			}
			
		}
		Log.d("Receiver", "finished!");
	}

}
