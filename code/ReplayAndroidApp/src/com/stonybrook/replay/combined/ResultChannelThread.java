package com.stonybrook.replay.combined;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Iterator;
import java.util.Locale;

import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.util.Log;

import com.stonybrook.replay.ReplayActivity;
import com.stonybrook.replay.adapter.ImageReplayRecyclerViewAdapter;
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
	public volatile int counter = 0;

	// for storing results
	private SharedPreferences settings;
	// Set<String> results;
	JSONArray results;

	private String path;
	private String analyzerServerUrl = null;
	private String id;
	private ArrayList<ApplicationBean> selectedApps = null;
	private String finishVpn;
	private String finishRandom;
	// private ImageReplayListAdapter adapter = null;
	private ImageReplayRecyclerViewAdapter adapter = null;
	private ReplayActivity replayAct;

	public ResultChannelThread(ReplayActivity replayAct, String path, int port,
			String id, ArrayList<ApplicationBean> selectedApps,
			String finishVpn, String finishRandom,
			/*ImageReplayListAdapter*/ImageReplayRecyclerViewAdapter adapter,
			SharedPreferences settings) {
		this.replayAct = replayAct;
		this.path = path;
		this.analyzerServerUrl = ("http://" + path + ":" + port + "/Results");
		this.id = id;
		this.selectedApps = selectedApps;
		this.finishVpn = finishVpn;
		this.finishRandom = finishRandom;
		this.adapter = adapter;
		this.settings = settings;
		this.results = new JSONArray();
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
			int giveupCounter[] = new int[selectedApps.size()];
			for (int i = 0; i < giveupCounter.length; i++) {
				// initialize give up counter
				giveupCounter[i] = 5;
			}

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
								// if client cannot get result after 5 attempts,
								// give up
								// and display another message
								if (giveupCounter[i] > 0) {
									giveupCounter[i] -= 1;
									Log.w("Result Channel",
											"Server result not ready");
								} else {
									synchronized (selectedApps) {
										selectedApps.get(i).status = "Analyzer server error";
										updateUI();
										counter -= 1;
									}
								}
								continue;
							}

							counter -= 1;
							JSONObject response = raw_response.getJSONObject(0);

							Log.d("Result Channel",
									"response: " + response.toString());

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
									// put new result into array list
									Log.d("Result Channel",
											"put result to json array");
									// results.add(response.toString());
									results.put(response);

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
						} else {
							synchronized (selectedApps) {
								String error = result.getString("error");
								Log.w("Result Channel", "Error: " + error);
								selectedApps.get(i).status = "Analyzer server error";
								updateUI();
								counter -= 1;
							}
						}
						Thread.sleep(1000);
					}
				}

				if (doneReplay && counter == 0) {
					Log.d("Result Channel", "Done replay");
					// put results into shared preference
					if (results.length() > 0) {
						Log.d("Result Channel", "Storing results");
						// get current date and time, and use it as the key of
						// this batch of results
						DateFormat dateFormat = new SimpleDateFormat(
								"yyyy/MM/dd HH:mm:ss", Locale.US);
						Date date = new Date();
						String strDate = dateFormat.format(date);
						// get current results, if not exist, create a json
						// object with date as the key
						JSONObject resultsWithDate = new JSONObject(
								settings.getString("lastResult", "{}"));
						// remove one history result if there are too many
						if (resultsWithDate.length() >= 5) {
							Iterator<String> it = resultsWithDate.keys();
							if (it.hasNext())
								resultsWithDate.remove(it.next());
							else
								Log.w("Result Channel",
										"iterator doesn't have next but length is not 0");
						}

						resultsWithDate.put(strDate, results);

						Editor editor = settings.edit();
						editor.putString("lastResult",
								resultsWithDate.toString());
						editor.commit();
					}

					counter = -1;
					Log.d("Result Channel", "Exiting normally");
					break;
				}

				if (forceQuit) {
					Log.w("Result Channel", "Force quit!");
					break;
				}

				Thread.sleep(10000);
			}
		} catch (InterruptedException ex) {
			Log.w("Result Channel", "interrupted!");
		} catch (JSONException e) {
			Log.e("Result Channel", "parsing json error");
			e.printStackTrace();
		} catch (Exception e) {
			Log.e("Result Channel", "unkown exception");
			e.printStackTrace();
		}
	}

	private JSONObject ask4analysis(String id, int historyCount) {
		String urlParas = "";
		urlParas += "command=analyze&";
		urlParas += ("userID=" + id + "&");
		urlParas += ("historyCount=" + String.valueOf(historyCount));

		JSONObject res = sendRequest("POST", urlParas);
		return res;
	}

	private JSONObject getSingleResult(String id, int historyCount) {
		/*ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "singleResult");
		data.add("historyCount=" + String.valueOf(historyCount));*/
		
		String urlParas = "";
		urlParas += ("userID=" + id + "&");
		urlParas += ("command=singleResult&");
		urlParas += ("historyCount=" + String.valueOf(historyCount));

		JSONObject res = sendRequest("GET", urlParas);
		return res;

	}

	// overload getSingleResult method. historyCount are not given as a
	// parameter
	private JSONObject getSingleResult(String id) {
		String urlParas = "";
		urlParas += ("userID=" + id + "&");
		urlParas += ("command=singleResult&");

		JSONObject res = sendRequest("GET", urlParas);
		return res;
	}

	private JSONObject getMultipleResult(String id, int maxHistoryCount) {
		String urlParas = "";
		urlParas += ("userID=" + id + "&");
		urlParas += ("command=multiResults&");
		urlParas += ("maxHistoryCount=" + String.valueOf(maxHistoryCount));

		JSONObject res = sendRequest("GET", urlParas);
		return res;
	}

	// overload getMultiple method. maxHistoryCount is not given as a parameter
	private JSONObject getMultipleResult(String id) {
		int maxHistoryCount = 10;
		
		String urlParas = "";
		urlParas += ("userID=" + id + "&");
		urlParas += ("command=multiResults&");
		urlParas += ("maxHistoryCount=" + String.valueOf(maxHistoryCount));

		JSONObject res = sendRequest("GET", urlParas);
		return res;
	}

	private JSONObject sendRequest(String method, String urlParas) {
		// create return object
		JSONObject json = null;
		
		if (method.equalsIgnoreCase("GET")) {
			//String dataURL = URLEncoder(data);
			String url_string = this.analyzerServerUrl + "?" + urlParas;
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
			byte[] postData = urlParas.getBytes();
			Log.d("Result Channel", url_string);

			try {
				URL url = new URL(url_string);
				Log.w("Result Channel", "1");
				HttpURLConnection conn = (HttpURLConnection) url
						.openConnection();
				Log.w("Result Channel", "2");
				conn.setRequestMethod("POST");
				conn.setReadTimeout(10000);
				conn.setConnectTimeout(15000);
				conn.setUseCaches(false);
				conn.setDoInput(true);
				conn.setDoOutput(true);

				DataOutputStream wr = new DataOutputStream(
						conn.getOutputStream());
				wr.write(postData);

				BufferedReader reader = new BufferedReader(
						new InputStreamReader(conn.getInputStream()));

				// os.close();
				StringBuilder sb = new StringBuilder();
				String line;
				while ((line = reader.readLine()) != null) {
					sb.append(line);
				}
				reader.close();

				// parse String to json file.
				json = new JSONObject(sb.toString());

			} catch (MalformedURLException e1) {
				e1.printStackTrace();
				json = null;
			} catch (IOException e) {
				e.printStackTrace();
				json = null;
			} catch (JSONException e) {
				e.printStackTrace();
				json = null;
			} catch (Exception e) {
				e.printStackTrace();
				json = null;
			}

			/*try {
				Log.w("Result Channel", "1");
				HttpClient httpClient = new DefaultHttpClient();
				HttpPost post = new HttpPost(url_string);
				post.setEntity(new UrlEncodedFormEntity(pairs));
				Log.w("Result Channel", "2");
				HttpResponse response = httpClient.execute(post);
				Log.w("Result Channel", "3");
				BufferedReader rd = new BufferedReader(new InputStreamReader(
						response.getEntity().getContent()));
				Log.w("Result Channel", "4");
				StringBuilder res = new StringBuilder();

				// parse BufferReader rd to StringBuilder res
				String line;
				while ((line = rd.readLine()) != null) {
					res.append(line);
				}
				rd.close();
				Log.w("Result Channel", "5");
				// parse String to json file.
				json = new JSONObject(res.toString());
			} catch (JSONException e) {
				e.printStackTrace();
				Log.e("Result Channel", "convert string to json failed");
				json = null;
			} catch (Exception e) {
				e.printStackTrace();
				Log.e("Result Channel", "sendRequest POST failed");
			}*/
		}

		return json;

	}

	// overload URLencoder to encode map to an url.
	/*private String URLEncoder(ArrayList<String> map) {
		StringBuilder data = new StringBuilder();
		for (String s : map) {
			if (data.length() > 0) {
				data.append("&");
			}
			data.append(s);
		}

		return data.toString();

	}*/

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
