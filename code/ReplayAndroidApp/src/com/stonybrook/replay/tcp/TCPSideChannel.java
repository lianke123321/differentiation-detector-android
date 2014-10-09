package com.stonybrook.replay.tcp;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.math.BigInteger;
import java.net.InetSocketAddress;
import java.net.Socket;
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
import com.stonybrook.replay.util.UnpickleDataStream;

public class TCPSideChannel {
	private String id = null;
	int bufSize = 4096;
	Socket socket = null;
	DataOutputStream dataOutputStream = null;
	DataInputStream dataInputStream = null;
	int objLen = 10;
	public TCPSideChannel(SocketInstance instance, String id) {
		this.id = id;
		try {
			
			socket = new Socket();
			InetSocketAddress endPoint = new InetSocketAddress(instance.getIP(), instance.getPort());
			socket.setTcpNoDelay(true);
			socket.setReuseAddress(true);
			socket.setKeepAlive(false);

			socket.connect(endPoint);
			dataOutputStream = new DataOutputStream(socket.getOutputStream());
			dataInputStream = new DataInputStream(socket.getInputStream());
			
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
	
	private void getResult() throws Exception
	{
		sendObject("GiveMeResults".getBytes(), objLen);
		byte[] result = receiveObject(objLen);
	}
	
	public HashMap<Integer, Integer> receivePortMappingNonBlock() throws Exception {
		HashMap<Integer, Integer> ports = new HashMap<Integer, Integer>();
		byte[] data = receiveObject(objLen);
		JSONObject jObject = new JSONObject(new String(data));
		Iterator<String> keys = jObject.keys();
		while (keys.hasNext()) {
			String k = keys.next();
			ports.put(Integer.valueOf(k), jObject.getInt(k));
		}
		return ports;
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
}
