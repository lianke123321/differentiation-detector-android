package com.stonybrook.replay.combined;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;

import org.json.JSONObject;

public class ResultChannel {
	
	private String path;

	public ResultChannel(String Path){
		path = Path;
		System.out.println(path);
	}
	
	public JSONObject ask4analysis(String id, int historyCount){
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "analyze");
		data.add("historyCount=" + String.valueOf(historyCount));
		
		JSONObject res = sendRequest("POST", data);
		return res;
	}
	
	public JSONObject getSingleResult(String id, int historyCount){
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "singleResult");
		data.add("historyCount=" + String.valueOf(historyCount));
	
		JSONObject res = sendRequest("GET", data);
		return res;
		
	}
	
	// overload getSingleResult method. historyCount are not given as a parameter
	public JSONObject getSingleResult(String id){
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "singleResult");
	
		JSONObject res = sendRequest("GET", data);
		return res;
	}
	
	
	public JSONObject getMultipleResult(String id, int maxHistoryCount){
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "multiResults");
		data.add("maxHistoryCount=" + String.valueOf(maxHistoryCount));
		
		JSONObject res = sendRequest("GET",data);
		return res;
	}
	
	
	// overload getMultiple method. maxHistoryCount is not given as a parameter
	public JSONObject getMultipleResult(String id){
		int maxHistoryCount = 10;
		ArrayList<String> data = new ArrayList<String>();
		data.add("userID=" + id);
		data.add("command=" + "multiResults");
		data.add("maxHistoryCount=" + String.valueOf(maxHistoryCount));

		JSONObject res = sendRequest("GET",data);
		return res;
	}
	
	
	public JSONObject sendRequest(String method, ArrayList<String> data){
		System.out.println(data);
		String dataURL = URLEncoder(data);
		System.out.println(dataURL);
		String url_string = "";
		if(method.equalsIgnoreCase("GET")){
			url_string = this.path + "?" + dataURL;
		}			
		else if(method.equalsIgnoreCase("POST")){
			url_string = this.path + dataURL;			
		}
		System.out.println(url_string);
		JSONObject json = null;
		try{
			URL url = new URL(url_string);
			HttpURLConnection conn = (HttpURLConnection) url.openConnection();
			conn.setRequestMethod("GET");
			BufferedReader rd = new BufferedReader(new
					InputStreamReader(conn.getInputStream()));
			
			StringBuilder res = new StringBuilder();
			
			//parse BufferReader rd to StringBuilder res
		    String line;
		    while ((line = rd.readLine()) != null) {
		        res.append(line);
		    }
			rd.close();
	
		    //parse String to json file.
			json = new JSONObject(res.toString());
		}catch(Exception e){
			e.printStackTrace();
		}
			        				
		return json;
		
	}
	
	//overload URLencoder to encode map to an url.
	public String URLEncoder(ArrayList<String> map){		
		StringBuilder data = new StringBuilder();
	    for ( String s : map) {
	        if (data.length() > 0) {
	            data.append("&");
	        }
	        data.append(s);
	    }
	    
	    return data.toString();  	
		
	}
	
	public static void main(String[] args)
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
			
	}
}
