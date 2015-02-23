package com.stonybrook.replay.combined;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;

import org.json.JSONArray;
import org.json.JSONObject;

import android.os.Build;
import android.util.Log;

import com.stonybrook.replay.bean.DeviceInfoBean;
import com.stonybrook.replay.bean.JitterBean;
import com.stonybrook.replay.bean.ServerInstance;
import com.stonybrook.replay.bean.SocketInstance;
import com.stonybrook.replay.bean.UDPReplayInfoBean;
import com.stonybrook.replay.util.Mobilyzer;
import com.stonybrook.replay.util.UtilsManager;

public class CombinedSideChannel {
	private String id = null;
	int bufSize = 4096;
	public Socket socket = null;
	// public SocketChannel channel = null;
	DataOutputStream dataOutputStream = null;
	DataInputStream dataInputStream = null;
	int objLen = 10;

	// SocketInstance instance;

	public CombinedSideChannel(SocketInstance instance, String id)
			throws Exception {
		this.id = id;
		// this.instance = instance;

		socket = new Socket();
		// channel = SocketChannel.open();
		InetSocketAddress endPoint = new InetSocketAddress(instance.getIP(),
				instance.getPort());
		socket.setTcpNoDelay(true);
		// channel.socket().setTcpNoDelay(true);
		socket.setReuseAddress(true);
		// channel.socket().setReuseAddress(true);
		socket.setKeepAlive(true);
		// channel.socket().setKeepAlive(true);
		// channel.configureBlocking(false);

		socket.connect(endPoint);
		// channel.connect(endPoint);
		dataOutputStream = new DataOutputStream(socket.getOutputStream());
		dataInputStream = new DataInputStream(socket.getInputStream());

	}

	public void declareID(String replayName, String testID, String extraString,
			String historyCount) throws Exception {
		/*String round = testID.replace('_', '-');
		String extra = extraString.replace('_', '-');*/
		sendObject((id + ";" + testID + ";" + replayName + ";" + extraString
				+ ";" + historyCount).getBytes(), objLen);
		Log.d("declareID", id);

	}

	public void sendMobileStats(String sendMobileStat, Mobilyzer mobilyzer)
			throws Exception {

		if (sendMobileStat.equalsIgnoreCase("true")) {
			Log.d("sendMobileStats", "will send mobile stats!");
			DeviceInfoBean deviceInfoBean = mobilyzer.getDeviceInfo();

			JSONObject deviceInfo = new JSONObject();
			JSONObject osInfo = new JSONObject();
			JSONObject locationInfo = new JSONObject();

			deviceInfo.put("manufacturer", deviceInfoBean.manufacturer);
			deviceInfo.put("model", deviceInfoBean.model);

			osInfo.put("INCREMENTAL", Build.VERSION.INCREMENTAL);
			osInfo.put("RELEASE", Build.VERSION.RELEASE);
			osInfo.put("SDK_INT", Build.VERSION.SDK_INT);

			deviceInfo.put("os", osInfo);
			deviceInfo.put("carrierName", deviceInfoBean.carrierName);
			deviceInfo.put("networkType", deviceInfoBean.networkType);
			deviceInfo.put("cellInfo", deviceInfoBean.cellInfo);

			locationInfo.put("latitude",
					String.valueOf(deviceInfoBean.location.getLatitude()));
			locationInfo.put("longitude",
					String.valueOf(deviceInfoBean.location.getLongitude()));

			deviceInfo.put("locationInfo", locationInfo);

			Log.d("sendMobileStats", deviceInfo.toString());

			sendObject("WillSendMobileStats".getBytes(), objLen);
			sendObject(deviceInfo.toString().getBytes(), objLen);

		} else {
			Log.d("sendMobileStats", "don't send mobile stats!");
			sendObject("NoMobileStats".getBytes(), objLen);
		}
	}

	public void sendDone(double duration) throws Exception {
		sendObject(("DONE;" + String.valueOf(duration)).getBytes(), objLen);
	}

	private void sendObject(byte[] buf, int objLen) throws Exception {
		dataOutputStream.writeBytes(String.format("%010d", buf.length));
		dataOutputStream.write(buf);
	}

	/*
	 * private void getResult() throws Exception {
	 * sendObject("GiveMeResults".getBytes(), objLen); byte[] result =
	 * receiveObject(objLen); }
	 */

	public HashMap<String, HashMap<String, HashMap<String, ServerInstance>>> receivePortMappingNonBlock()
			throws Exception {
		HashMap<String, HashMap<String, HashMap<String, ServerInstance>>> ports = new HashMap<String, HashMap<String, HashMap<String, ServerInstance>>>();
		byte[] data = receiveObject(objLen);

		/*
		 * JSONObject jObject = new JSONObject(new String(data));
		 * Iterator<String> keys = jObject.keys(); while (keys.hasNext()) {
		 * HashMap<String, ServerInstance> tempHolder = new HashMap<String,
		 * ServerInstance>(); String key = keys.next(); JSONObject firstLevel =
		 * (JSONObject) jObject.get(key); Iterator<String> firstLevelKeys =
		 * firstLevel.keys(); while(firstLevelKeys.hasNext()) { String key1 =
		 * firstLevelKeys.next(); JSONArray pair =
		 * firstLevel.getJSONArray(key1); tempHolder.put(key1, new
		 * ServerInstance(String.valueOf(pair.get(0)),
		 * String.valueOf(pair.get(1)))); } ports.put(key, tempHolder); }
		 */
		String tempStr = new String(data);
		Log.d("receivePortMapping", "length: " + tempStr.length());
		JSONObject jObject = new JSONObject(tempStr);
		Iterator<String> keys = jObject.keys();
		while (keys.hasNext()) {
			HashMap<String, HashMap<String, ServerInstance>> tempHolder = new HashMap<String, HashMap<String, ServerInstance>>();
			String key = keys.next();
			JSONObject firstLevel = (JSONObject) jObject.get(key);
			Iterator<String> firstLevelKeys = firstLevel.keys();
			while (firstLevelKeys.hasNext()) {
				HashMap<String, ServerInstance> tempHolder1 = new HashMap<String, ServerInstance>();
				String key1 = firstLevelKeys.next();
				JSONObject secondLevel = (JSONObject) firstLevel.get(key1);
				Iterator<String> secondLevelKeys = secondLevel.keys();
				while (secondLevelKeys.hasNext()) {
					String key2 = secondLevelKeys.next();
					JSONArray pair = secondLevel.getJSONArray(key2);
					tempHolder1.put(key2,
							new ServerInstance(String.valueOf(pair.get(0)),
									String.valueOf(pair.get(1))));
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
		// ByteBuffer wrapped = ByteBuffer.wrap(data);
		Log.d("receiveSenderCount", "senderCount: " + Integer.valueOf(tempStr));
		return Integer.valueOf(tempStr);

	}

	public byte[] receiveObject(int objLen) throws Exception {
		byte[] recvObjSizeBytes = receiveKbytes(objLen);
		// Log.d("Obj", new String(recvObjSizeBytes));
		int recvObjSize = Integer.parseInt(new String(recvObjSizeBytes));
		// Log.d("Obj", String.valueOf(recvObjSize));
		return receiveKbytes(recvObjSize);
	}

	public String[] ask4Permission() throws Exception {
		byte[] data = receiveObject(objLen);
		String tempPermission = new String(data);
		String[] permission = tempPermission.split(";");
		return permission;
	}

	public void sendIperf() throws Exception {
		Log.d("sendIperf", "always no iperf!");
		String noIperf = "NoIperf";
		sendObject(noIperf.getBytes(), objLen);
	}

	public CombinedNotifierThread notifierCreater(
			UDPReplayInfoBean udpReplayInfoBean) throws Exception {
		CombinedNotifierThread notifier = new CombinedNotifierThread(
				udpReplayInfoBean, this.socket);
		return notifier;
	}

	public void sendJitter(String id, String jitter, JitterBean jitterBean)
			throws Exception {
		// if jitter is set to false, don't send jitter
		if (jitter != "true") {
			Log.d("sendJitter", "No jitter");
			sendObject(("NoJitter;" + id).getBytes(), objLen);
		} else {
			sendObject(("WillSendClientJitter;" + id).getBytes(), objLen);

			int i;
			String sentJitter = "";
			String rcvdJitter = "";

			if ((jitterBean.sentJitter.size() != jitterBean.sentPayload.size())
					|| (jitterBean.rcvdJitter.size() != jitterBean.rcvdPayload
							.size())) {
				Log.d("sendJitter", "size does not match!");
				return;
			}

			if (jitterBean.sentJitter.size() > 0) {
				sentJitter += (jitterBean.sentJitter.get(0) + "\t" + UtilsManager
						.getUnsignedInt(Arrays.hashCode(jitterBean.sentPayload
								.get(0))));
				for (i = 1; i < jitterBean.sentJitter.size(); i++) {
					// Log.d("sendJitter", jitterBean.sentJitter.get(i)[1]);
					sentJitter += ("\n" + jitterBean.sentJitter.get(i) + "\t" + UtilsManager
							.getUnsignedInt(Arrays
									.hashCode(jitterBean.sentPayload.get(i))));
				}
			}

			if (jitterBean.rcvdJitter.size() > 0) {
				rcvdJitter += (jitterBean.rcvdJitter.get(0) + "\t" + UtilsManager
						.getUnsignedInt(Arrays.hashCode(jitterBean.rcvdPayload
								.get(0))));
				Log.d("rcvdJitter",
						String.valueOf(jitterBean.rcvdJitter.size()));
				for (i = 1; i < jitterBean.rcvdJitter.size(); i++) {
					rcvdJitter += ("\n" + jitterBean.rcvdJitter.get(i) + "\t" + UtilsManager
							.getUnsignedInt(Arrays
									.hashCode(jitterBean.rcvdPayload.get(i))));
				}
			}

			sendObject(sentJitter.getBytes(), objLen);
			sendObject(rcvdJitter.getBytes(), objLen);
		}

		// receive confirmation from server
		byte[] data = receiveObject(objLen);
		String str = new String(data);
		if (!str.trim().equalsIgnoreCase("OK")) {
			Log.d("sendJitter", "server returned bad! " + str);
			return;
		}

		Log.d("sendJitter", "finished sending jitter");
	}

	public void getResult(String result) throws Exception {
		if (result.trim().equalsIgnoreCase("false")) {
			sendObject("Result;No".getBytes(), objLen);
			byte[] data = receiveObject(objLen);
			String str = new String(data);
			if (!str.trim().equalsIgnoreCase("OK")) {
				Log.d("getResult", "return value abnormal! " + str);
				return;
			}
		} else {
			sendObject("Result;Yes".getBytes(), objLen);
			byte[] data = receiveObject(objLen);
			String str = new String(data);
			Log.d("getResult", "received result is: " + str);
		}

		Log.d("getResult", "finished getting result!");
	}

	public void closeSideChannelSocket() throws Exception {
		socket.close();
	}

	/*
	 * int fromByteArray(byte[] bytes) { return ByteBuffer.wrap(bytes).getInt();
	 * }
	 */

	/**
	 * Rajesh's original code has bug, if message is more than 4096, this method
	 * will return disordered byte
	 * 
	 * Fixed by adrian
	 * 
	 * @param k
	 * @return
	 * @throws Exception
	 */
	public byte[] receiveKbytes(int k) throws Exception {
		int totalRead = 0;
		byte[] b = new byte[k];
		while (totalRead < k) {
			int bytesRead = dataInputStream.read(b, totalRead,
					Math.min(k - totalRead, bufSize));
			if (bytesRead < 0) {
				throw new IOException("Data stream ended prematurely");
			}
			/*
			 * if (k - totalRead < bytesRead) bytesRead = k - totalRead;
			 */
			totalRead += bytesRead;
		}
		return b;
	}
}
