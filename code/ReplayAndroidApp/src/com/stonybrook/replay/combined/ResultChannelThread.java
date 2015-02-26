package com.stonybrook.replay.combined;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;

import org.json.JSONObject;

import android.util.Log;

import com.stonybrook.replay.adapter.ImageReplayListAdapter;
import com.stonybrook.replay.bean.ApplicationBean;

/**
 * This class will be running through the whole replay, and periodically check
 * selected apps to see if there are finished traces. If it is, tries to query
 * analysis server for results.
 * 
 * @author Boyu, Adrian
 * 
 */
public class ResultChannelThread implements Runnable {

	public volatile boolean doneReplay = false;

	private String path;
	private int port;
	private String analyzerServerUrl = null;
	private String id;
	private ArrayList<ApplicationBean> selectedApps = null;
	private String finishVpn;
	private String finishRandom;
	private ImageReplayListAdapter adapter = null;

	public ResultChannelThread(String path, int port, String id,
			ArrayList<ApplicationBean> selectedApps, String finishVpn,
			String finishRandom, ImageReplayListAdapter adapter) {
		this.path = path;
		this.port = port;
		this.analyzerServerUrl = ("http://" + path + ":" + port + "/Results");
		this.id = id;
		this.selectedApps = selectedApps;
		this.finishVpn = finishVpn;
		this.finishRandom = finishRandom;
		this.adapter = adapter;
		Log.d("Result Channel", "path: " + this.path + " finishVpn: "
				+ this.finishVpn + " finishRandom: " + this.finishRandom);
	}

	@Override
	public void run() {
		Thread.currentThread().setName("ResultChannelThread (Thread)");
		try {
			String wait = "Waiting for server result";

			while (true) {
				for (int i = 0; i < selectedApps.size(); i++) {
					if ((selectedApps.get(i).status == finishVpn)
							|| (selectedApps.get(i).status == finishRandom)) {
						selectedApps.get(i).status = wait;
						// adapter.notifyDataSetChanged();

						// sanity check
						if (selectedApps.get(i).historyCount < 0) {
							Log.e("Result Channel",
									"historyCount value not correct!");
							return;
						}
					}

					if (selectedApps.get(i).status == wait) {
						JSONObject result = getSingleResult(id);
						Log.d("Result Channel",
								"received result: " + result.toString());
						selectedApps.get(i).status = "Result received";
						// adapter.notifyDataSetChanged();
						Thread.sleep(2000);
					}
				}

				if (doneReplay) {
					Log.d("Result Channel", "Done replay! Exiting thread.");
					break;
				}

				Thread.sleep(2000);
			}
		} catch (InterruptedException ex) {
			Log.d("Result Channel", "interrupted!");
		}
	}

	public JSONObject ask4analysis(String id, int historyCount) {
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "analyze");
		data.add("historyCount=" + String.valueOf(historyCount));

		JSONObject res = sendRequest("POST", data);
		return res;
	}

	public JSONObject getSingleResult(String id, int historyCount) {
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "singleResult");
		data.add("historyCount=" + String.valueOf(historyCount));

		JSONObject res = sendRequest("GET", data);
		return res;

	}

	// overload getSingleResult method. historyCount are not given as a
	// parameter
	public JSONObject getSingleResult(String id) {
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "singleResult");

		JSONObject res = sendRequest("GET", data);
		return res;
	}

	public JSONObject getMultipleResult(String id, int maxHistoryCount) {
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "multiResults");
		data.add("maxHistoryCount=" + String.valueOf(maxHistoryCount));

		JSONObject res = sendRequest("GET", data);
		return res;
	}

	// overload getMultiple method. maxHistoryCount is not given as a parameter
	public JSONObject getMultipleResult(String id) {
		int maxHistoryCount = 10;
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "multiResults");
		data.add("maxHistoryCount=" + String.valueOf(maxHistoryCount));

		JSONObject res = sendRequest("GET", data);
		return res;
	}

	public JSONObject sendRequest(String method, ArrayList<String> data) {
		// Log.d("Result Channel", data.toString());
		String dataURL = URLEncoder(data);
		// Log.d("Result Channel", dataURL);
		String url_string = "";
		if (method.equalsIgnoreCase("GET")) {
			url_string = this.analyzerServerUrl + "?" + dataURL;
		} else if (method.equalsIgnoreCase("POST")) {
			url_string = this.analyzerServerUrl + dataURL;
		}
		// System.out.println(url_string);
		Log.d("Result Channel", url_string);
		JSONObject json = null;
		try {
			URL url = new URL(url_string);
			HttpURLConnection conn = (HttpURLConnection) url.openConnection();
			conn.setRequestMethod("GET");
			BufferedReader rd = new BufferedReader(new InputStreamReader(
					conn.getInputStream()));

			StringBuilder res = new StringBuilder();

			// parse BufferReader rd to StringBuilder res
			String line;
			while ((line = rd.readLine()) != null) {
				res.append(line);
			}
			rd.close();

			// parse String to json file.
			json = new JSONObject(res.toString());
		} catch (Exception e) {
			e.printStackTrace();
		}

		return json;

	}

	// overload URLencoder to encode map to an url.
	public String URLEncoder(ArrayList<String> map) {
		StringBuilder data = new StringBuilder();
		for (String s : map) {
			if (data.length() > 0) {
				data.append("&");
			}
			data.append(s);
		}

		return data.toString();

	}

	/*public static void main(String[] args)
	{
		String analyzerServerPort = "56565";
		String analyzerServerIP   = "54.87.92.45";
		String analyzerServerPath = ("http://" + analyzerServerIP 
				+ ":" + analyzerServerPort + "/Results");
		
		ResultChannel sendT1 = new ResultChannel(analyzerServerPath);
		
		JSONObject json_single1,json_single2,json_multi1,json_multi2;
		json_single1 = sendT1.getSingleResult("KSiZr4RAqA", 9);
		json_single2 = sendT1.getSingleResult("KSiZr4RAqA");				
		json_multi1 = sendT1.getMultipleResult("KSiZr4RAqA", 9);
		json_multi2 = sendT1.getMultipleResult("KSiZr4RAqA");
		
		System.out.println("JSON for singleResult:");
		System.out.println(json_single1);
		System.out.println();
		System.out.println("JSON for singleResult w.o historyCount:");
		System.out.println(json_single2);
		System.out.println();
		System.out.println("JSON for multiResults");
		System.out.println(json_multi1);
		System.out.println();
		System.out.println("JSON for multiResults w.o maxHistoryCount");
		System.out.println(json_multi2);
		System.out.println();
			
	}*/
}
