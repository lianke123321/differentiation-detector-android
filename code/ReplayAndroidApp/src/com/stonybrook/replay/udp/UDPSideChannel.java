package com.stonybrook.replay.udp;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.math.BigInteger;
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

import org.json.JSONArray;
import org.json.JSONObject;

import android.util.Log;
import android.util.SparseArray;

import com.stonybrook.replay.bean.RequestSet;
import com.stonybrook.replay.bean.ServerInstance;
import com.stonybrook.replay.bean.SocketInstance;

public class UDPSideChannel {
	private String id = null;
	private SocketInstance instance = null;
	public SocketChannel socketChannel = null;
	public Selector selector = null;
	public SelectionKey key = null;
	// adrian: for sendObject
	DataOutputStream dataOutputStream = null;
	DataInputStream dataInputStream = null;
	int objLen = 10;

	public UDPSideChannel(SocketInstance instance, String id) {
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

	public void declareID(String replayName) throws Exception {
		sendObject((id+";"+replayName).getBytes(), objLen);

	}
	
	private void sendObject(byte[] buf, int objLen) throws Exception {
		dataOutputStream.writeBytes(String.format("%010d", buf.length));
		dataOutputStream.write(buf);
	}
	
	public byte[] ask4Permission() throws Exception {
		return receiveObject(10);
	}
	
	public byte[] receiveObject(int objLen) throws Exception{
		byte[] recvObjSizeBytes = receiveKbytes(objLen);
		Log.d("Obj", new String(recvObjSizeBytes));
		int recvObjSize = (new BigInteger(new String(recvObjSizeBytes))).intValue();
		Log.d("Obj", String.valueOf(recvObjSize));
		return receiveKbytes(recvObjSize);
	}
	
	public byte[] receiveKbytes(int k) throws Exception{
    	int totalRead = 0;
    	byte[] b = new byte[k];
		while (totalRead < k) {
			int bytesRead = dataInputStream.read(b);
			if (bytesRead < 0) {
				throw new IOException("Data stream ended prematurely");
			}
			totalRead += bytesRead;
		}
		return b;
    }

/*	private void send(byte[] buf) throws Exception {
		ByteBuffer buffer = ByteBuffer.allocate(buf.length);
		buffer.clear();
		buffer.put(buf);
		buffer.flip();
		while (buffer.hasRemaining())
			socketChannel.write(buffer);
	}*/

	/*public SparseArray<Integer> receivePortMappingNonBlock() throws Exception {
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
	}*/
	
	public HashMap<String, HashMap<String, ServerInstance>> receivePortMappingNonBlock() throws Exception {
		HashMap<String, HashMap<String, ServerInstance>> ports = new HashMap<String, HashMap<String, ServerInstance>>();
		byte[] data = receiveObject(objLen);
	
		JSONObject jObject = new JSONObject(new String(data));
		Iterator<String> keys = jObject.keys();
		while (keys.hasNext()) {
			HashMap<String, ServerInstance> tempHolder = new HashMap<String, ServerInstance>();
			String key = keys.next();
			JSONObject firstLevel = (JSONObject) jObject.get(key);
			Iterator<String> firstLevelKeys = firstLevel.keys();
			while(firstLevelKeys.hasNext()) {
				String key1 = firstLevelKeys.next();
				JSONArray pair = firstLevel.getJSONArray(key1);
				tempHolder.put(key1, new ServerInstance(String.valueOf(pair.get(0)), String.valueOf(pair.get(1))));
			}
			ports.put(key, tempHolder);
		}
		return ports;
	}
	
	public int receiveSenderCount() throws Exception {
		byte[] data = receiveObject(objLen);
		int senderCount = data[0];
		
		Log.d("senderCount", String.valueOf(senderCount));
		
		return senderCount;
	}

	public int byteArrayToInt(byte[] b) {
		return b[3] & 0xFF | (b[2] & 0xFF) << 8 | (b[1] & 0xFF) << 16
				| (b[0] & 0xFF) << 24;
	}

	public HashMap<Integer, Integer> receivePortMapping() throws Exception {
		HashMap<Integer, Integer> ports = new HashMap<Integer, Integer>();
		BufferedReader socketReader = new BufferedReader(new InputStreamReader(
				socketChannel.socket().getInputStream()));
		// CHANGE THIS CODE>>> HARD CODED USE SOME MANUAL LOGIC
		String len = readBufferUpdate(socketReader, 2);
		int packetLen = Integer.parseInt(len);
		if (packetLen != 0) {
			String data = "";
			char buff[] = new char[packetLen * 2];
			while (data.length() < packetLen) {
				// socketReader.read(buff);
				data += readBufferUpdate(socketReader, packetLen).trim();
			}

			JSONObject jObject = new JSONObject(data);
			Iterator<String> keys = jObject.keys();
			while (keys.hasNext()) {
				String key = keys.next();
				ports.put(Integer.valueOf(key), jObject.getInt(key));
			}

		}
		return ports;
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
