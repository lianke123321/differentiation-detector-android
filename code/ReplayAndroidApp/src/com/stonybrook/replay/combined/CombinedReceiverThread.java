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
			}
			
			while (true) {
				if (udpReplayInfoBean.pollCloseQ() == "False") {
					udpReplayInfoBean.decrement();
					Log.d("Receiver", "decremented one from senderCount: " +
							udpReplayInfoBean.getSenderCount());
				}
				if (udpReplayInfoBean.getCloseQ().isEmpty()) {
					//Log.d("Receiver", "closeQ is empty!");
					break;
				}
			}
		}
		Log.d("Receiver", "finished!");
	}

}
