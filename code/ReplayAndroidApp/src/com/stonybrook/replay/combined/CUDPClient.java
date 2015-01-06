package com.stonybrook.replay.combined;

import java.net.DatagramPacket;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.DatagramChannel;

import com.stonybrook.replay.bean.ServerInstance;

public class CUDPClient /* implements Runnable */{
	public DatagramChannel channel = null;
	public String publicIP = null;
	public int port = 0;
	public CUDPClient(String publicIP) {
		super();
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
			channel = DatagramChannel.open();
			channel.socket().send(packet);
			this.port = channel.socket().getLocalPort();
		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}
	
	public void sendUDPPacket(byte[] payload, ServerInstance instance) throws Exception {
		//byte[] buf = UtilsManager.serialize(payload);
		/*Log.d("sending", "udp packet w/ payload length " + payload.length +
				" sent to server " + instance.server);*/
		/*DatagramPacket packet = new DatagramPacket(payload, payload.length,
				new InetSocketAddress(instance.server, Integer.parseInt(instance.port)));*/
		this.channel.send(ByteBuffer.wrap(payload), new InetSocketAddress(instance.server, Integer.parseInt(instance.port)));
		
	}

}
