package com.stonybrook.replay.combined;

import java.net.DatagramPacket;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.DatagramChannel;

import android.util.Log;

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
			DatagramPacket packet = new DatagramPacket(buffer, buffer.length,
					endPoint);
			channel = DatagramChannel.open();
			channel.socket().send(packet);
			channel.configureBlocking(false);
			this.port = channel.socket().getLocalPort();
			Log.d("UDPClient", "port is " + port);
			// channel.socket().bind(new InetSocketAddress(this.publicIP,
			// this.port));
		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}

	public void sendUDPPacket(byte[] payload, ServerInstance instance)
			throws Exception {
		// Log.d("sendUDP", "server IP: " + instance.server + " port: " +
		// instance.port);
		/*channel.disconnect();
		channel.connect(new InetSocketAddress(instance.server, Integer
				.parseInt(instance.port)));*/
		this.channel.send(ByteBuffer.wrap(payload), new InetSocketAddress(
				instance.server, Integer.parseInt(instance.port)));

	}

}
