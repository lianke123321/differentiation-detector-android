package com.stonybrook.replay.tcp;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.channels.SocketChannel;
import java.util.concurrent.atomic.AtomicBoolean;

import org.apache.http.util.EntityUtils;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;
import com.stonybrook.replay.util.UtilsManager;

public class TCPClient /*implements Runnable */{
	public String CSPair = null;
	private String destIP = null;
	private int destPort;
	public Socket socket = null;
	private int port;
	private int NATPort;
	private String id = null;
	private String replayName = null;
	public SocketChannel sc = null;
	//TODO: Check proper usage later
	public AtomicBoolean flag = new AtomicBoolean();

	public TCPClient(String cSPair, String destIP, int destPort, String randomID, String replayName) {
		super();
		CSPair = cSPair;
		this.destIP = destIP;
		this.destPort = destPort;
		this.id = randomID;
		this.replayName = replayName;
	}

	
	/**
	 * Steps:
            1- Create and connect TCP socket
            2- Identifies itself --> tells server what's replaying (replay_name and c_s_pair)
	 */
	public void createSocket() {
		try {
			socket = new Socket();
			InetSocketAddress endPoint = new InetSocketAddress(destIP, destPort);
			socket.setTcpNoDelay(false);
			socket.setReuseAddress(true);
			socket.setKeepAlive(true);
			socket.connect(endPoint);
			
			//this.identify();
		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}
	
	//Not Used
	public void identify_channel() throws IOException {
		//Log.d("Identify", id + ";" + this.CSPair + ";" + replayName);
		byte[] message = (id + ";" + this.CSPair + ";" + replayName).getBytes();
		ByteBuffer buf = ByteBuffer.wrap(message);
		//this.sc.write(ByteBuffer.wrap(String.format("%010d", message.length).getBytes()));
		this.sc.write(buf);
	}

	/**
	 * Before anything, client needs to identify itself to the server and tell
        which c_s_pair it will be replaying.
	 * @throws IOException
	 */
	public void identify() throws Exception {
		Log.d("Replay", id + ";" + this.CSPair + ";" + replayName);
		byte[] message = (id + ";" + this.CSPair + ";" + replayName).getBytes();
		sendObject(message);

	}
	
	private void sendObject(byte[] buf) throws Exception {
		DataOutputStream dataOutputStream = new DataOutputStream(socket.getOutputStream());
		dataOutputStream.writeBytes(String.format("%010d", buf.length));
		dataOutputStream.write(buf);
	}
	
	public void close() throws Exception {
		this.socket.close();
	}
	
	@Override
	public boolean equals(Object o) {
		return this.CSPair.equals(((TCPClient)o).CSPair);
	}
	
	@Override
	public int hashCode() {
		return CSPair.hashCode();
	}
}
