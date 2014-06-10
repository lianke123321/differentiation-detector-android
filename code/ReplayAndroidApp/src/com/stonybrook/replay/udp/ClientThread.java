package com.stonybrook.replay.udp;

import java.io.IOException;
import java.net.DatagramPacket;

import android.util.Log;

public class ClientThread implements Runnable{

	private UDPClient client = null;
	public ClientThread(UDPClient client) {
		this.client = client;
	}
	
	/**
	 *  Keeps receiving on the socket. It will be terminated by the side channel
        when a send done confirmation is received from the server.
	 */
	
	@Override
	public void run() {
		byte[] buf;
		DatagramPacket packet;
		while(true)
		{
			try {
				buf = new byte[4096];
				packet = new DatagramPacket(buf, buf.length);
				if(this.client.getSocket().isClosed())
					break;
				this.client.getSocket().receive(packet);
				Log.d("UDP", "Got data on " + this.client.getCSPair());
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
		
	}

	public UDPClient getClient() {
		return client;
	}

	public void setClient(UDPClient client) {
		this.client = client;
	}

}
