package com.stonybrook.replay.udp;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.SocketChannel;
import java.util.Iterator;
import java.util.Set;

import android.util.Pair;

import com.stonybrook.replay.util.UtilsManager;

public class UDPClient {
	private String CSPair = null;
	private String destIP = null;
	private int destPort;
	private DatagramSocket socket = null;
	private int port;
	private int NATPort;

	public UDPClient(String cSPair, String destIP, int destPort) {
		super();
		CSPair = cSPair;
		this.destIP = destIP;
		this.destPort = destPort;
		this.createSocket();
	}

	private void createSocket() {
		try {
			byte[] buffer = "".getBytes();
			InetSocketAddress endPoint = new InetSocketAddress("127.0.0.1", 100);
			DatagramPacket packet = new DatagramPacket(buffer, buffer.length, endPoint);
			socket = new DatagramSocket();
			socket.send(packet);
			this.port = socket.getLocalPort();
		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}

	public Pair<Integer, Integer> identify(UDPSideChannel sideChannel, String id, String replayName) throws IOException {
		int NATport = 0;
		Pair<Integer, Integer> NATMapping = null;
		while (true) {
			byte[] message = (id + ";" + this.CSPair + ";" + replayName).getBytes();
			DatagramPacket packet = new DatagramPacket(message, message.length, new InetSocketAddress(destIP, destPort));
			socket.send(packet);
			int readyChannels = sideChannel.selector.select(1000);
			if (readyChannels == 0)
				continue;
			Set<SelectionKey> selectedKeys = sideChannel.selector.selectedKeys();

			Iterator<SelectionKey> keyIterator = selectedKeys.iterator();

			while (keyIterator.hasNext()) {

				SelectionKey key = keyIterator.next();

				if (key.isReadable()) {
					// a channel is ready for reading
					ByteBuffer buf = ByteBuffer.allocate(5);
					int bytesRead = ((SocketChannel) key.channel()).read(buf);
					NATport = Integer.parseInt(new String(buf.array(), "ASCII").trim());
				}

				keyIterator.remove();
			}
			this.NATPort = NATport;
			NATMapping = Pair.create(NATport, this.port);
			break;
		}
		return NATMapping;
	}

	public void close() throws Exception {
		this.socket.close();
	}

	public void sendUDPPacket(Object payload) throws Exception {
		byte[] buf = UtilsManager.serialize(payload);
		DatagramPacket packet = new DatagramPacket(buf, buf.length, new InetSocketAddress(destIP, destPort));
		this.socket.send(packet);
	}

	public String getCSPair() {
		return CSPair;
	}

	public void setCSPair(String cSPair) {
		CSPair = cSPair;
	}

	public String getDestIP() {
		return destIP;
	}

	public void setDestIP(String destIP) {
		this.destIP = destIP;
	}

	public int getDestPort() {
		return destPort;
	}

	public void setDestPort(int destPort) {
		this.destPort = destPort;
	}

	public DatagramSocket getSocket() {
		return socket;
	}

	public void setSocket(DatagramSocket socket) {
		this.socket = socket;
	}

	public int getPort() {
		return port;
	}

	public void setPort(int port) {
		this.port = port;
	}

	public int getNATPort() {
		return NATPort;
	}

	public void setNATPort(int nATPort) {
		NATPort = nATPort;
	}

}
