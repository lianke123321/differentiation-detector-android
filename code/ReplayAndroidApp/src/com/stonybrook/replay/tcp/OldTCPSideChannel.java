package com.stonybrook.replay.tcp;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.SocketException;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.nio.channels.SocketChannel;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Set;

import org.json.JSONObject;

import android.util.Log;

import com.stonybrook.replay.bean.SocketInstance;

/**
 Client uses SideChannel to:
        0- Initiate SideChannel connection
        1- Identify itself to the server (by sending id)
        2- Receive port mapping from the server (useful if server not user original ports)
        3- Request and receive results (once done with the replay)
        4- At this point, the server itself will close the connection
 @author rajesh
 *
 */
public class OldTCPSideChannel {
	private String id = null;
	private SocketInstance instance = null;
	public SocketChannel socketChannel = null;
	public Selector selector = null;
	public SelectionKey key = null;

	/**
	 * Iniate side channel connection
	 * @param instance
	 * @param id
	 */
	public OldTCPSideChannel(SocketInstance instance, String id) {
		this.id = id;
		this.instance = instance;

		try {
			socketChannel = SocketChannel.open();
			InetSocketAddress endPoint = new InetSocketAddress(this.instance.getIP(), this.instance.getPort());
			//Non-blocking
			socketChannel.configureBlocking(false);
			socketChannel.connect(endPoint);
			while (!socketChannel.finishConnect()) {
				// wait, or do something else...
			}
			// @@@ open selector to monitor multiple channel in one thread
			selector = Selector.open();
			key = socketChannel.register(selector, SelectionKey.OP_READ);
		} catch (SocketException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}

	}

	//Indentify to server
	public void declareID(String replayName) throws Exception {
		send((id).getBytes());

	}

	/**
	 * Send buf to server
	 * @param buf
	 * @throws Exception
	 */
	private void send(byte[] buf) throws Exception {
		ByteBuffer buffer = ByteBuffer.allocate(buf.length);
		buffer.clear();
		buffer.put(buf);
		buffer.flip();
		Log.d("size", String.valueOf((new String(buf)).length()) + " " + new String(buf));
		while (buffer.hasRemaining())
			socketChannel.write(buffer);
	}

	/**
	 * Receive port mapping. Port mapping is received in JSON, Parsed and stored into HashMap.
	 * @return
	 * @throws Exception
	 */
	public HashMap<Integer, Integer> receivePortMappingNonBlock() throws Exception {
		HashMap<Integer, Integer> ports = new HashMap<Integer, Integer>();

		ByteBuffer lenBuf = ByteBuffer.allocate(2);
		ByteBuffer buf = null;
		int readyChannels = this.selector.select();	// @@@ get the # ready channels

		Set<SelectionKey> selectedKeys = this.selector.selectedKeys();	// @@@ <type> means this set could only store such type
		Iterator<SelectionKey> keyIterator = selectedKeys.iterator();

		while (keyIterator.hasNext()) {

			SelectionKey key = keyIterator.next();

			if (key.isReadable()) {
				// a channel is ready for reading
				lenBuf = ByteBuffer.allocate(10);
				int bytesRead = ((SocketChannel) key.channel()).read(lenBuf);	// @@@ read key(?) from specific channel
				lenBuf.rewind();
				// @@@ use trim() to get rid of space and tab at beginning and end of a string
				int len = Integer.parseInt(new String(lenBuf.array(), "ASCII").trim());

				if (len == 0)
					break;

				buf = ByteBuffer.allocate(len);
				bytesRead = ((SocketChannel) key.channel()).read(buf);	// @@@ read value(?) from that channel

				
				Log.d("Replay", "Received String" + new String(buf.array()));
				JSONObject jObject = new JSONObject(new String(buf.array()));
				Iterator<String> keys = jObject.keys();
				while (keys.hasNext()) {
					String k = keys.next();
					ports.put(Integer.valueOf(k), jObject.getInt(k));
				}


			}

			keyIterator.remove();
		}
		Log.d("Replay", "Size of ports Hashmap" + String.valueOf(ports.size()));
		return ports;
	}
	
	
}
