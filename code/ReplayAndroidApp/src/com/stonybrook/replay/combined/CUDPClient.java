package com.stonybrook.replay.combined;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetSocketAddress;

import com.stonybrook.replay.util.UtilsManager;

public class CUDPClient /* implements Runnable */{
	public DatagramSocket socket = null;
	public int port = 0;
	public String publicIP = null;
	public CUDPClient(String publicIP) {
		super();
		this.socket = null;
		this.publicIP = publicIP;
	}

	/**
	 * Steps: 1- Create and connect TCP socket 2- Identifies itself --> tells
	 * server what's replaying (replay_name and c_s_pair)
	 */
	public void createSocket() {
		try {
			byte[] buffer = "".getBytes();
			InetSocketAddress endPoint = new InetSocketAddress(publicIP, 100);
			DatagramPacket packet = new DatagramPacket(buffer, buffer.length, endPoint);
			socket = new DatagramSocket();
			socket.send(packet);
			this.port = socket.getLocalPort();
		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}
	
	public void sendUDPPacket(Object payload, String destIP, int port) throws Exception {
		byte[] buf = UtilsManager.serialize(payload);
		DatagramPacket packet = new DatagramPacket(buf, buf.length, new InetSocketAddress(destIP, port));
		this.socket.send(packet);
	}

}
