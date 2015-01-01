package com.stonybrook.replay.combined;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.math.BigInteger;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketException;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Queue;

import org.json.JSONArray;
import org.json.JSONObject;

import android.util.Log;

import com.stonybrook.replay.bean.ServerInstance;
import com.stonybrook.replay.bean.SocketInstance;

public class CombinedSideChannel {
	private String id = null;
	int bufSize = 4096;
	Socket socket = null;
	DataOutputStream dataOutputStream = null;
	DataInputStream dataInputStream = null;
	int objLen = 10;
	Queue<String> closeQ = null;
	
	public CombinedSideChannel(SocketInstance instance, String id) {
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

	public void declareID(String replayName, String extraString) throws Exception {
		String temp = extraString.replace('_', '-');
		sendObject((id+";"+"SINGLE"+";"+replayName+";"+temp).getBytes(), objLen);
		Log.d("id", id);

	}

	private void sendObject(byte[] buf, int objLen) throws Exception {
		dataOutputStream.writeBytes(String.format("%010d", buf.length));
		dataOutputStream.write(buf);
	}
	
	/*private void getResult() throws Exception
	{
		sendObject("GiveMeResults".getBytes(), objLen);
		byte[] result = receiveObject(objLen);
	}*/
	
	public HashMap<String, HashMap<String, HashMap<String, ServerInstance>>> receivePortMappingNonBlock() throws Exception {
		HashMap<String, HashMap<String, HashMap<String, ServerInstance>>> ports = new HashMap<String, HashMap<String, HashMap<String, ServerInstance>>>();
		byte[] data = receiveObject(objLen);
	
		/*JSONObject jObject = new JSONObject(new String(data));
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
		}*/
		String tempStr = new String(data);
		Log.d("receivePortMapping", "length: " + tempStr.length());
		JSONObject jObject = new JSONObject(tempStr);
		Iterator<String> keys = jObject.keys();
		while(keys.hasNext()) {
			HashMap<String, HashMap<String, ServerInstance>> tempHolder = new HashMap<String, HashMap<String, ServerInstance>>();
			String key = keys.next();
			JSONObject firstLevel = (JSONObject) jObject.get(key);
			Iterator<String> firstLevelKeys = firstLevel.keys();
			while(firstLevelKeys.hasNext()) {
				HashMap<String, ServerInstance> tempHolder1 = new HashMap<String, ServerInstance>();
				String key1 = firstLevelKeys.next();
				JSONObject secondLevel = (JSONObject) firstLevel.get(key1);
				Iterator<String> secondLevelKeys = secondLevel.keys();
				while(secondLevelKeys.hasNext()) {
					String key2 = secondLevelKeys.next();
					JSONArray pair = secondLevel.getJSONArray(key2);
					tempHolder1.put(key2, new ServerInstance(String.valueOf(pair.get(0)), String.valueOf(pair.get(1))));
				}
				tempHolder.put(key1, tempHolder1);
			}
			ports.put(key, tempHolder);
		}
		
		return ports;
		
	}
	
	public int receiveSenderCount() throws Exception {
		byte[] data = receiveObject(objLen);
		String tempStr = new String(data);
		//ByteBuffer wrapped = ByteBuffer.wrap(data);
		Log.d("receiveSenderCount", "senderCount: " + Integer.valueOf(tempStr));
		return Integer.valueOf(tempStr);
		
	}
	
	public byte[] receiveObject(int objLen) throws Exception{
		byte[] recvObjSizeBytes = receiveKbytes(objLen);
		Log.d("Obj", new String(recvObjSizeBytes));
		int recvObjSize = (new BigInteger(new String(recvObjSizeBytes))).intValue();
		Log.d("Obj", String.valueOf(recvObjSize));
		return receiveKbytes(recvObjSize);
	}
	
	public String[] ask4Permission() throws Exception {
		byte[] data = receiveObject(objLen);
		String tempPermission = new String(data);
		String[] permission = tempPermission.split(";");
		return permission;
	}
	
	public void sendIperf() throws Exception{
		Log.d("sendIperf", "always no iperf!");
		String noIperf = "NoIperf";
		sendObject(noIperf.getBytes(), objLen);
	}
	
	public void notifier(int senderCount) throws Exception{
		while (senderCount > 0) {
			byte[] data = receiveObject(objLen);
			String tempNotf = new String(data);
			String[] Notf = tempNotf.split(";");
			if (Notf[0].equalsIgnoreCase("DONE")) {
				senderCount -= 1;
				this.closeQ.add(Notf[1]);
			} else {
				Log.d("Notifier", "received unknown message!");
				break;
			}
		}
	}
	
	int fromByteArray(byte[] bytes) {
	     return ByteBuffer.wrap(bytes).getInt();
	}
	
	/**
	 * Rajesh's original code has bug, if message is more than 4096, this
	 * method will return disordered byte
	 * 
	 * Fixed by adrian
	 * 
	 * @param k
	 * @return
	 * @throws Exception
	 */
    public byte[] receiveKbytes(int k) throws Exception{
    	int totalRead = 0;
    	byte[] b = new byte[k];
		while (totalRead < k) {
			int bytesRead = dataInputStream.read(b, totalRead, Math.min(k - totalRead, bufSize));
			if (bytesRead < 0) {
				throw new IOException("Data stream ended prematurely");
			}
			/*if (k - totalRead < bytesRead)
				bytesRead = k - totalRead;*/
			totalRead += bytesRead;
		}
		return b;
    }    		
}