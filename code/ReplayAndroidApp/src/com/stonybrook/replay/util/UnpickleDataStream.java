package com.stonybrook.replay.util;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLConnection;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedList;

import net.razorvine.pickle.Unpickler;
import net.razorvine.pickle.objects.ClassDict;

import org.json.JSONArray;
import org.json.JSONObject;

import android.content.Context;
import android.content.res.AssetManager;
import android.os.AsyncTask;
import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;
import com.stonybrook.replay.bean.TCPAppJSONInfoBean;
import com.stonybrook.replay.bean.UDPAppJSONInfoBean;
import com.stonybrook.replay.bean.combinedAppJSONInfoBean;
import com.stonybrook.replay.constant.ReplayConstants;

public class UnpickleDataStream {

	/**
	 * Accepts the filename and parse it which is in python pickle data format
	 * and return Queue of packets which need to be replayed
	 * 
	 * @param filename
	 *            : file to parse
	 * @param context
	 *            : Activity context
	 * @return Queue of packets to be replayed
	 * @throws Exception
	 */
	public java.util.Queue<RequestSet> unpickle(String filename, Context context)
			throws Exception {
		java.util.Queue<RequestSet> packets = new LinkedList<RequestSet>();
		RequestSet requestSet;
		AssetManager assetManager;
		InputStream inputStream;
		Unpickler unpickler;
		ArrayList data;
		try {
			assetManager = context.getAssets();
			inputStream = assetManager.open(filename);
			unpickler = new Unpickler();
			data = (ArrayList) unpickler.load(inputStream);
			int noOfPackets = data.size();
			for (int i = 0; i < noOfPackets; i++) {
				ClassDict dictionary = (ClassDict) data.get(i);
				requestSet = new RequestSet();
				requestSet.setc_s_pair((String) dictionary.get("c_s_pair"));
				//requestSet.setPayload(dictionary.get("payload"));
				requestSet.setTimestamp((Double) (dictionary.get("timestamp")));
				// requestSet.setResponse_hash((Long)dictionary.get("response_hash"));
				requestSet.setResponse_len((Integer) dictionary
						.get("response_len"));
				packets.add(requestSet);
			}
			Log.d("Replay", "No of packets " + packets.size());
		} catch (Exception ex) {
			ex.printStackTrace();
			Log.e("Error", ex.toString());
			throw ex;
		}
		return packets;
	}

	/**
	 * Unpickles the file containing data for UDP replay and stores result in
	 * UDPAppJSONInfoBean instance
	 * 
	 * @param filename
	 * @param context
	 * @return
	 * @throws Exception
	 */
	public static UDPAppJSONInfoBean unpickleUDP(String filename,
			Context context) throws Exception {
		java.util.Queue<RequestSet> packets = new LinkedList<RequestSet>();
		AssetManager assetManager;
		InputStream inputStream;
		Unpickler unpickler;
		UDPAppJSONInfoBean appData = new UDPAppJSONInfoBean();
		ArrayList<RequestSet> Q = new ArrayList<RequestSet>();
		HashMap<String, ArrayList<Integer>> csPairs = new HashMap<String, ArrayList<Integer>>();
		String replayName = null;
		BufferedReader in = null;
		try {
			assetManager = context.getAssets();
			inputStream = assetManager.open(filename);
			unpickler = new Unpickler();
			Object[] obj = (Object[]) unpickler.load(inputStream);

			ArrayList qArray = (ArrayList) obj[0];
			RequestSet tempRS = null;
			for (int i = 0; i < qArray.size(); i++) {
				ClassDict dictionary = (ClassDict) qArray.get(i);
				tempRS = new RequestSet();
				tempRS.setc_s_pair((String) dictionary.get("c_s_pair"));
				//tempRS.setPayload(dictionary.get("payload"));
				tempRS.setTimestamp((Double) dictionary.get("timestamp"));
				Q.add(tempRS);
			}
			appData.setQ(Q);
			appData.setCsPairs((HashMap<String, ArrayList<Integer>>) obj[1]);
			appData.setReplayName((String) obj[2]);

		} catch (Exception ex) {
			ex.printStackTrace();
			Log.e("Error", ex.toString());
			throw ex;
		}
		return appData;
	}

	/**
	 * Unpickles received port mapping string from server
	 * 
	 * @param bs
	 * @return
	 * @throws Exception
	 */
	public static HashMap<Integer, Integer> unpicklePortMapping(byte[] bs)
			throws Exception {
		try {
			Unpickler unpickler = new Unpickler();
			return (HashMap<Integer, Integer>) unpickler.loads(bs);
		} catch (Exception ex) {
			ex.printStackTrace();
			throw ex;
		}
	}

	/***
	 * Unpickles the file containing data for TCP replay and stores in
	 * TCPAppJSONInfoBean type object
	 * 
	 * @param filename
	 * @param context
	 * @return
	 * @throws Exception
	 */
	public static TCPAppJSONInfoBean unpickleTCP(String filename,
			Context context) throws Exception {
		java.util.Queue<RequestSet> packets = new LinkedList<RequestSet>();
		AssetManager assetManager;
		InputStream inputStream;
		Unpickler unpickler;
		TCPAppJSONInfoBean appData = new TCPAppJSONInfoBean();
		ArrayList<RequestSet> Q = new ArrayList<RequestSet>();
		HashMap<String, ArrayList<Integer>> csPairs = new HashMap<String, ArrayList<Integer>>();
		String replayName = null;
		BufferedReader in = null;
		File file = null;
		try {
			assetManager = context.getAssets();
			inputStream = assetManager.open(filename);
			unpickler = new Unpickler();
			Object[] obj = (Object[]) unpickler.load(inputStream);

			ArrayList qArray = (ArrayList) obj[0];
			RequestSet tempRS = null;
			for (int i = 0; i < qArray.size(); i++) {
				ClassDict dictionary = (ClassDict) qArray.get(i);
				tempRS = new RequestSet();
				tempRS.setc_s_pair((String) dictionary.get("c_s_pair"));
				//tempRS.setPayload(dictionary.get("payload"));
				tempRS.setTimestamp((Double) dictionary.get("timestamp"));
				// Log.d("Time", (i+1) + " " +
				// String.valueOf(tempRS.getTimestamp()));
				tempRS.setResponse_len((Integer) dictionary.get("response_len"));
				Q.add(tempRS);
			}
			appData.setQ(Q);
			appData.setCsPairs((ArrayList<String>) obj[1]);
			Log.d("Name", (String) obj[2]);
			appData.setReplayName((String) obj[2]);

		} catch (Exception ex) {
			ex.printStackTrace();
			Log.e("Error", ex.toString());
			throw ex;
		}
		return appData;
	}

	public static TCPAppJSONInfoBean unpickleTCPJSON(String filename,
			Context context) throws Exception {
//		java.util.Queue<RequestSet> packets = new LinkedList<RequestSet>();
		AssetManager assetManager;
		InputStream inputStream;
//		Unpickler unpickler;
		TCPAppJSONInfoBean appData = new TCPAppJSONInfoBean();
		ArrayList<RequestSet> Q = new ArrayList<RequestSet>();
//		HashMap<String, ArrayList<Integer>> csPairs = new HashMap<String, ArrayList<Integer>>();
//		String replayName = null;
//		BufferedReader in = null;
//		File file = null;
		try {
			assetManager = context.getAssets();
			inputStream = assetManager.open(filename);
			int size = inputStream.available();
			byte[] buffer = new byte[size];
			inputStream.read(buffer);
			inputStream.close();

			String jsonStr = new String(buffer, "UTF-8");
			
			JSONArray json = new JSONArray(jsonStr);
			
			JSONArray qArray = (JSONArray) json.get(0);
			RequestSet tempRS = null;
			for (int i = 0; i < qArray.length(); i++) {
				JSONObject dictionary = (JSONObject)qArray.get(i) ;
				tempRS = new RequestSet();
				tempRS.setc_s_pair((String) dictionary.get("c_s_pair"));
				tempRS.setPayload(DecodeHex.decodeHex(((String)dictionary.get("payload")).toCharArray()));
				tempRS.setTimestamp((Double) dictionary.get("timestamp"));
				// Log.d("Time", (i+1) + " " +
				// String.valueOf(tempRS.getTimestamp()));
				tempRS.setResponse_len((Integer) dictionary.get("response_len"));
				Q.add(tempRS);
			}
			appData.setQ(Q);
			
			JSONArray csArray = (JSONArray)json.get(1);
			ArrayList<String> csStrArray = new ArrayList<String>(); 
			for (int i = 0; i < csArray.length(); i++) { 
				csStrArray.add((String)csArray.get(i));
			}
			
			appData.setCsPairs(csStrArray);
			Log.d("Name", (String) json.get(2));
			appData.setReplayName((String) json.get(2));

		} catch (Exception ex) {
			ex.printStackTrace();
			Log.e("Error", ex.toString());
			throw ex;
		}
		return appData;
	}
	
	public static combinedAppJSONInfoBean unpickleCombinedJSON(String filename,
			Context context) throws Exception {
		AssetManager assetManager;
		InputStream inputStream;
		combinedAppJSONInfoBean appData = new combinedAppJSONInfoBean();
		ArrayList<RequestSet> Q = new ArrayList<RequestSet>();
		try {
			assetManager = context.getAssets();
			inputStream = assetManager.open(filename);
			int size = inputStream.available();
			byte[] buffer = new byte[size];
			inputStream.read(buffer);
			inputStream.close();

			String jsonStr = new String(buffer, "UTF-8");
			
			JSONArray json = new JSONArray(jsonStr);
			
			JSONArray qArray = (JSONArray) json.get(0);
			
			for (int i = 0; i < qArray.length(); i++) {
				RequestSet tempRS = new RequestSet();
				JSONObject dictionary = qArray.getJSONObject(i) ;
				tempRS.setc_s_pair((String) dictionary.get("c_s_pair"));
				tempRS.setPayload(DecodeHex.decodeHex(((String)dictionary.get("payload")).toCharArray()));
				tempRS.setTimestamp((Double) dictionary.get("timestamp"));
				// Log.d("Time", (i+1) + " " +
				// String.valueOf(tempRS.getTimestamp()));
				
				// adrian: for tcp
				if (dictionary.has("response_len"))
					tempRS.setResponse_len((Integer) dictionary.get("response_len"));
				/*else
					tempRS.setResponse_len(-1);*/
				
				if (dictionary.has("response_hash"))
					tempRS.setResponse_hash(dictionary.get("response_hash").toString());
				
				// adrian: for udp
				if (dictionary.has("end"))
					tempRS.setEnd((Boolean) dictionary.get("end"));
				
				Q.add(tempRS);
			}
			appData.setQ(Q);
			
			// adrian: store udpClientPorts
			JSONArray portArray = (JSONArray)json.get(1);
			ArrayList<String> portStrArray = new ArrayList<String>(); 
			for (int i = 0; i < portArray.length(); i++)
				portStrArray.add((String)portArray.getString(i));
			appData.setUdpClientPorts(portStrArray);
			
			
			JSONArray csArray = (JSONArray)json.get(2);
			ArrayList<String> csStrArray = new ArrayList<String>(); 
			for (int i = 0; i < csArray.length(); i++)
				csStrArray.add((String)csArray.get(i));
			appData.setTcpCSPs(csStrArray);
			
			Log.d("Name", (String) json.get(3));
			appData.setReplayName((String) json.get(3));

		} catch (Exception ex) {
			ex.printStackTrace();
			Log.e("Error", ex.toString());
			throw ex;
		}
		return appData;
	}

	/**
	 * !!! Not used Anymore !!! Send request to the server for free ports and
	 * parse the returned pickle file and insert these ports into the
	 * configuration map
	 * 
	 * @param context
	 * @return
	 * @return
	 * @throws Exception
	 *             TODO : Get URL dynamically from Properties file
	 */
	public HashMap<String, String> unpickleFreePorts(Context context)
			throws Exception {

		return new PortsAsyncTask().execute(
				"http://54.200.20.20:8080/MeddlePorts/GetServerPorts").get();
	}

	/**
	 * !! Not Used Anymore !!
	 * 
	 * @author rajesh
	 * 
	 */
	private class PortsAsyncTask extends
			AsyncTask<String, String, HashMap<String, String>> {

		// String... arg0 is the same as String[] args
		protected HashMap<String, String> doInBackground(String... args) {
			URL url;
			URLConnection connection;
			BufferedReader bufferReader;
			String line, stream = "";
			InputStream inputStream;
			Unpickler unpickler;
			HashMap<String, String> data = null;
			try {
				url = new URL(args[0]);
				connection = url.openConnection();
				bufferReader = new BufferedReader(new InputStreamReader(
						connection.getInputStream()));

				while ((line = bufferReader.readLine()) != null) {
					stream += line + "\n";
				}
				Log.d("Stream", stream);
				inputStream = new ByteArrayInputStream(stream.getBytes());
				unpickler = new Unpickler();
				data = (HashMap<String, String>) unpickler.load(inputStream);
				Log.d("Replay", "No of Ports " + data.size());
			} catch (MalformedURLException e) {
				e.printStackTrace();
			} catch (IOException e) {
				e.printStackTrace();
			} catch (Exception e) {
				e.printStackTrace();
			}
			return data;

		}

		protected void onPostExecute(HashMap<String, String> result) {
			Log.d(ReplayConstants.LOG_APPNAME, "Downloaded " + result.size()
					+ " ports details.");
		}

	}

}
