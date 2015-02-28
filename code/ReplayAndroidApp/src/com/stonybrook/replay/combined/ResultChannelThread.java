package com.stonybrook.replay.combined;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.URI;
import java.util.ArrayList;

import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.client.HttpClient;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicNameValuePair;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.util.Log;

import com.stonybrook.replay.ReplayActivity;
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
	public volatile boolean forceQuit = false;

	private String path;
	private String analyzerServerUrl = null;
	private String id;
	private ArrayList<ApplicationBean> selectedApps = null;
	private String finishVpn;
	private String finishRandom;
	private ImageReplayListAdapter adapter = null;
	private ReplayActivity replayAct;

	public ResultChannelThread(ReplayActivity replayAct, String path, int port,
			String id, ArrayList<ApplicationBean> selectedApps,
			String finishVpn, String finishRandom, ImageReplayListAdapter adapter) {
		this.replayAct = replayAct;
		this.path = path;
		this.analyzerServerUrl = ("http://" + path + ":" + port + "/Results");
		this.id = id;
		this.selectedApps = selectedApps;
		this.finishVpn = finishVpn;
		this.finishRandom = finishRandom;
		this.adapter = adapter;
		Log.d("Result Channel",
				"path: " + this.path + " port: " + String.valueOf(port)
						+ " finishVpn: " + this.finishVpn + " finishRandom: "
						+ this.finishRandom);
	}

	@Override
	public void run() {
		Thread.currentThread().setName("ResultChannelThread (Thread)");
		try {
			String wait = "Waiting for server result";
			int counter = 0;

			while (true) {

				for (int i = 0; i < selectedApps.size(); i++) {
					if ((selectedApps.get(i).status == finishVpn)
							|| (selectedApps.get(i).status == finishRandom)) {
						// asking server to analyze data
						JSONObject result = ask4analysis(id,
								selectedApps.get(i).historyCount);

						if (result == null) {
							Log.d("Result Channel",
									"ask4analysis returned null!");
							synchronized (selectedApps) {
								selectedApps.get(i).status = "Analysis server unavailable";
								updateUI();

							}
							continue;
						}

						boolean success = result.getBoolean("success");
						if (!success) {
							Log.d("Result Channel", "ask4analysis failed!");
							synchronized (selectedApps) {
								selectedApps.get(i).status = "Error getting result";
								updateUI();

							}
							continue;
						}

						synchronized (selectedApps) {
							selectedApps.get(i).status = wait;
							updateUI();
						}
						counter += 1;
						// adapter.notifyDataSetChanged();

						// sanity check
						if (selectedApps.get(i).historyCount < 0) {
							Log.e("Result Channel",
									"historyCount value not correct!");
							return;
						}

						Log.d("Result Channel", "ask4analysis succeeded!");
					} else if (selectedApps.get(i).status == wait) {

						JSONObject result = getSingleResult(id,
								selectedApps.get(i).historyCount);
						if (result == null) {
							Log.d("Result Channel",
									"getSingleResult returned null!");
							synchronized (selectedApps) {
								selectedApps.get(i).status = "Analysis server unavailable";
								updateUI();

							}
							continue;
						}

						boolean success = result.getBoolean("success");
						if (success) {
							Log.d("Result Channel", "retrieve result succeed");

							// parse content of response
							JSONArray raw_response = result
									.getJSONArray("response");

							if (raw_response.length() == 0) {
								Log.w("Result Channel", "Server result not ready");
								continue;
							}

							counter -= 1;
							JSONObject response = raw_response.getJSONObject(0);

							String userID = response.getString("userID");
							double rate = response.getDouble("rate");
							int historyCount = response.getInt("historyCount");
							int diff = response.getInt("diff");
							String replayName = response
									.getString("replayName");
							String date = response.getString("date");

							Log.d("Result Channel",
									"userID: " + userID + " rate: "
											+ String.valueOf(rate)
											+ " historyCount: "
											+ String.valueOf(historyCount)
											+ " diff: " + String.valueOf(diff)
											+ " replayName: " + replayName
											+ " date: " + date);

							// sanity check
							synchronized (selectedApps) {
								if ((!userID.trim().equalsIgnoreCase(id))
										|| (historyCount != selectedApps.get(i).historyCount)) {
									Log.e("Result Channel",
											"Result didn't pass sanity check! correct id: "
													+ id
													+ " correct historyCount: "
													+ selectedApps.get(i).historyCount);
									Log.e("Result Channel", "Result content: "
											+ response.toString());
									selectedApps.get(i).status = "Result error";
								} else {

									/*switch (diff) {
									    case -1:
									        selectedApps.get(i).status = "No differentiation";
									    case 0:
									        selectedApps.get(i).status = "There might be differentiation";
									    case 1:
									        selectedApps.get(i).status = "Differentiation detected!";
									    default:
									        selectedApps.get(i).status = "unknown result! "
									                + String.valueOf(diff);
									}*/
									if (diff == -1) {
										selectedApps.get(i).status = "No Differentiation";
										selectedApps.get(i).rate = rate;
									} else if (diff == 0) {
										selectedApps.get(i).status = "Inconclusive Result";
										selectedApps.get(i).rate = rate;
									} else if (diff == 1) {
										selectedApps.get(i).status = "Differentiation Detected";
										selectedApps.get(i).rate = rate;
									} else {
										selectedApps.get(i).status = "Unknown Code: "
												+ String.valueOf(diff);
									}
								}
								updateUI();
							}
							// adapter.notifyDataSetChanged();
						}
						Thread.sleep(1000);
					}
				}

				if (doneReplay && counter == 0) {
					Log.d("Result Channel", "Done replay! Exiting thread.");
					break;
				}

				if (forceQuit) {
					Log.d("Result Channel", "Force quit!");
					break;
				}

				Thread.sleep(10000);
			}
		} catch (InterruptedException ex) {
			Log.d("Result Channel", "interrupted!");
		} catch (JSONException e) {
			Log.d("Result Channel", "parsing json error");
			e.printStackTrace();
		}
	}

	public JSONObject ask4analysis(String id, int historyCount) {
		ArrayList<NameValuePair> pairs = new ArrayList<NameValuePair>();
		pairs.add(new BasicNameValuePair("command", "analyze"));
		pairs.add(new BasicNameValuePair("userID", id));
		pairs.add(new BasicNameValuePair("historyCount", String
				.valueOf(historyCount)));

		JSONObject res = sendRequest("POST", null, pairs);
		return res;
	}

	public JSONObject getSingleResult(String id, int historyCount) {
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "singleResult");
		data.add("historyCount=" + String.valueOf(historyCount));

		JSONObject res = sendRequest("GET", data, null);
		return res;

	}

	// overload getSingleResult method. historyCount are not given as a
	// parameter
	public JSONObject getSingleResult(String id) {
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "singleResult");

		JSONObject res = sendRequest("GET", data, null);
		return res;
	}

	public JSONObject getMultipleResult(String id, int maxHistoryCount) {
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "multiResults");
		data.add("maxHistoryCount=" + String.valueOf(maxHistoryCount));

		JSONObject res = sendRequest("GET", data, null);
		return res;
	}

	// overload getMultiple method. maxHistoryCount is not given as a parameter
	public JSONObject getMultipleResult(String id) {
		int maxHistoryCount = 10;
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "multiResults");
		data.add("maxHistoryCount=" + String.valueOf(maxHistoryCount));

		JSONObject res = sendRequest("GET", data, null);
		return res;
	}

	public JSONObject sendRequest(String method, ArrayList<String> data,
			ArrayList<NameValuePair> pairs) {

		JSONObject json = null;
		if (method.equalsIgnoreCase("GET")) {
			String dataURL = URLEncoder(data);
			String url_string = this.analyzerServerUrl + "?" + dataURL;
			Log.d("Result Channel", url_string);

			try {
				HttpClient httpClient = new DefaultHttpClient();
				HttpGet request = new HttpGet();
				URI uri = new URI(url_string);
				request.setURI(uri);
				HttpResponse response = httpClient.execute(request);
				BufferedReader rd = new BufferedReader(new InputStreamReader(
						response.getEntity().getContent()));
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
				Log.e("Result Channel", "sendRequest GET failed");
			}
		} else if (method.equalsIgnoreCase("POST")) {
			String url_string = this.analyzerServerUrl;
			Log.d("Result Channel", url_string);

			try {
				HttpClient httpClient = new DefaultHttpClient();
				HttpPost post = new HttpPost(url_string);
				// URI uri = new URI(url_string);
				post.setEntity(new UrlEncodedFormEntity(pairs));
				HttpResponse response = httpClient.execute(post);
				BufferedReader rd = new BufferedReader(new InputStreamReader(
						response.getEntity().getContent()));
				StringBuilder res = new StringBuilder();

				// parse BufferReader rd to StringBuilder res
				String line;
				while ((line = rd.readLine()) != null) {
					res.append(line);
				}
				rd.close();

				// parse String to json file.
				json = new JSONObject(res.toString());
			} catch (JSONException e) {
				e.printStackTrace();
				Log.e("Result Channel", "convert string to json failed");
				json = null;
			}catch (Exception e) {
				e.printStackTrace();
				Log.e("Result Channel", "sendRequest POST failed");
			}
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
	
	// TODO: temporary way to updateUI from this thread
	// maybe find another way
	private void updateUI() {
		replayAct.runOnUiThread(new Runnable() {
			public void run() {
				adapter.notifyDataSetChanged();
				Log.d("Result Channel", "updated UI");
			}

		});
	}

}
