package com.stonybrook.replay.udp;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.InetSocketAddress;
import java.net.SocketException;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.nio.channels.SocketChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Set;

import org.json.JSONObject;

import android.util.Log;
import android.util.SparseArray;

import com.stonybrook.replay.bean.RequestSet;
import com.stonybrook.replay.bean.SocketInstance;

/**
 *  Steps:
        1- Initiate connection
        2- Identify --> send id
        3- Receive server_port_mapping
        4- Receive acks (which is the NAT port) on Client identification
           This is called from Client.identify()
        5- Wait for fin acks from server (#fin acks = number of clients)
        6- Send client ports to server so it knows client is done and can clean maps
        7- Request and receive results
        8- Terminate
 * @author rajesh
 *
 */

public class SideChannel {
	private String id = null;
	private SocketInstance instance = null;
	public SocketChannel socketChannel = null;
	public Selector selector = null;
	public SelectionKey key = null;

	public SideChannel(SocketInstance instance, String id) {
		this.id = id;
		this.instance = instance;

		try {
			socketChannel = SocketChannel.open();
			InetSocketAddress endPoint = new InetSocketAddress(
					this.instance.getIP(), this.instance.getPort());
			// socket.setReuseAddress(true);
			socketChannel.configureBlocking(false);
			// socketChannel.socket().bind(endPoint);
			socketChannel.connect(endPoint);
			while (!socketChannel.finishConnect()) {
				// wait, or do something else...
			}
			selector = Selector.open();
			key = socketChannel.register(selector, SelectionKey.OP_READ);
		} catch (SocketException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}

	}

	public void declareID() throws Exception {
		send(this.id.getBytes());

	}

	private void send(byte[] buf) throws Exception {
		ByteBuffer buffer = ByteBuffer.allocate(buf.length);
		buffer.clear();
		buffer.put(buf);
		buffer.flip();
		while (buffer.hasRemaining())
			socketChannel.write(buffer);
	}

	public SparseArray<Integer> receivePortMappingNonBlock() throws Exception {
		SparseArray<Integer> ports = new SparseArray<Integer>();

		ByteBuffer lenBuf = ByteBuffer.allocate(2);
		ByteBuffer buf = null;
		int readyChannels = this.selector.select();

		Set<SelectionKey> selectedKeys = this.selector.selectedKeys();
		Iterator<SelectionKey> keyIterator = selectedKeys.iterator();

		while (keyIterator.hasNext()) {

			SelectionKey key = keyIterator.next();

			if (key.isReadable()) {
				// a channel is ready for reading
				lenBuf = ByteBuffer.allocate(10);
				int bytesRead = ((SocketChannel) key.channel()).read(lenBuf);
				lenBuf.rewind();
				int len = Integer.parseInt(new String(lenBuf.array(), "ASCII")
						.trim());

				if (len == 0)
					break;

				buf = ByteBuffer.allocate(len);
				bytesRead = ((SocketChannel) key.channel()).read(buf);

				JSONObject jObject = new JSONObject(new String(buf.array(),
						"ASCII").trim());
				Iterator<String> keys = jObject.keys();
				while (keys.hasNext()) {
					String keyPort = keys.next();
					ports.put(Integer.valueOf(keyPort), jObject.getInt(keyPort));
				}

			}

			keyIterator.remove();
		}
		return ports;
	}

	
	public int byteArrayToInt(byte[] b) {
		return b[3] & 0xFF | (b[2] & 0xFF) << 8 | (b[1] & 0xFF) << 16
				| (b[0] & 0xFF) << 24;
	}



	public String readBufferUpdate(BufferedReader is, int count)
			throws IOException {
		char[] buffer = new char[count];
		int bytesRead = is.read(buffer, 0, count);
		return new String(buffer, 0, bytesRead);
	}

	public void terminate(ArrayList<ClientThread> cSPairMapping)
			throws Exception {
		String message = "";
		for (ClientThread cThread : cSPairMapping) {
			message += cThread.getClient().getNATPort() + ";";
		}
		message += "FIN";

		send(message.getBytes());

		for (ClientThread cThread : cSPairMapping) {
			cThread.getClient().close();
		}

		this.socketChannel.finishConnect();
		this.socketChannel.close();

	}

	/**
	 * Keeps reading 5 bytes at a time (port numbers are 5 bytes)
        Every time it receives a port number it means that server is done 
        sending to that port.
	 * @param portMap
	 * @param nATMap
	 * @throws Exception
	 */
	public void waitForFinish(SparseArray<ClientThread> portMap,
			SparseArray<Integer> nATMap) throws Exception {
		ByteBuffer lenBuf;
		int i = 0;
		while (true) {

			int readyChannels = this.selector.select();
			if (readyChannels == 0)
				continue;
			
			Set<SelectionKey> selectedKeys = this.selector.selectedKeys();
			Iterator<SelectionKey> keyIterator = selectedKeys.iterator();

			while (keyIterator.hasNext()) {

				SelectionKey key = keyIterator.next();

				if (key.isReadable()) {
					// a channel is ready for reading
					lenBuf = ByteBuffer.allocate(5);
					((SocketChannel) key.channel())
							.read(lenBuf);
					int port = Integer.parseInt(new String(lenBuf.array(), "ASCII").trim());
					if(nATMap.get(port) != null)
						port = nATMap.get(port);
					if(portMap.get(port) != null)
						i++;
					Log.d("UDPReplay", "closing socket from port " + port + " still " + portMap.size() + " sockets are open.");
				}

				keyIterator.remove();
			}
			
			Log.d("UDPClose", "PortMapSize " + portMap.size() + " i " + i);
			if(portMap.size() == i)
				break;
		}
	}
}
