package com.stonybrook.replay.combined;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;

import org.json.JSONException;
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
                        synchronized (selectedApps) {
                            selectedApps.get(i).status = wait;
                        }

                        // adapter.notifyDataSetChanged();

                        // sanity check
                        if (selectedApps.get(i).historyCount < 0) {
                            Log.e("Result Channel",
                                    "historyCount value not correct!");
                            return;
                        }
                    }

                    if (selectedApps.get(i).status == wait) {

                        JSONObject result = getSingleResult(id,
                                selectedApps.get(i).historyCount);
                        if (result == null)
                            continue;

                        boolean success = result.getBoolean("success");
                        if (success) {
                            Log.d("Result Channel", "retrieve result succeed");

                            // parse content of response
                            JSONObject response = result.getJSONArray(
                                    "response").getJSONObject(0);

                            String userID = response.getString("userID");
                            double rate = response.getDouble("rate");
                            int historyCount = response.getInt("historyCount");
                            int diff = response.getInt("diff");
                            String replayName = response
                                    .getString("replayName");
                            String date = response.getString("date");

                            // sanity check
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
                                synchronized (selectedApps) {
                                    switch (diff) {
                                        case -1:
                                            selectedApps.get(i).status = "No differentiation";
                                        case 0:
                                            selectedApps.get(i).status = "There might be differentiation";
                                        case 1:
                                            selectedApps.get(i).status = "Differentiation detected!";
                                        default:
                                            selectedApps.get(i).status = "unknown result! "
                                                    + String.valueOf(diff);
                                    }
                                }
                            }
                            // adapter.notifyDataSetChanged();
                        }
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
        } catch (JSONException e) {
            Log.d("Result Channel", "parsing json error");
            e.printStackTrace();
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
            Log.e("Result Channel", "sendRequest failed");
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

}
