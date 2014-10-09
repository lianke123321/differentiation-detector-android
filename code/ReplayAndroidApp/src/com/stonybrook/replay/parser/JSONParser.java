package com.stonybrook.replay.parser;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Hashtable;
import java.util.Iterator;
import java.util.concurrent.ExecutionException;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.Context;
import android.util.Log;
import android.widget.Toast;

import com.stonybrook.replay.bean.ApplicationBean;
import com.stonybrook.replay.bean.RequestSet;
import com.stonybrook.replay.bean.UDPAppJSONInfoBean;
import com.stonybrook.replay.constant.ReplayConstants;
public class JSONParser {
	
	/**
	 * This method parses applist json file located in assets folder. This file has all the basic details of apps for replay.
	 * @param context
	 * @return
	 * @throws Exception
	 */
	public static HashMap<String, ApplicationBean> parseAppJSON(Context context) throws Exception
	{
		HashMap<String, ApplicationBean> hashMap = new HashMap<String, ApplicationBean>();
		BufferedReader in  = null;
		try
		{
			StringBuilder buf=new StringBuilder();
		    InputStream json= context.getAssets().open(ReplayConstants.APPS_FILENAME);
		    in = new BufferedReader(new InputStreamReader(json));
		    String str;

		    while ((str=in.readLine()) != null) {
		      buf.append(str);
		    }

		    in.close();
		    
		    JSONObject jObject = new JSONObject(buf.toString());
		    JSONArray jArray = jObject.getJSONArray("apps");
		    
		    JSONObject appObj = null;
		    ApplicationBean bean = null;
		    for(int i = 0; i < jArray.length(); i++)
		    {
		    	appObj = jArray.getJSONObject(i);
		    	bean = new ApplicationBean();
		    	
		    	bean.setName(appObj.getString("name"));
		    	bean.setConfigfile(appObj.getString("configfile"));
		    	bean.setDataFile(appObj.getString("datafile"));
		    	bean.setSize(appObj.getDouble("size"));
		    	bean.setImage(appObj.getString("image"));
		    	bean.setType(appObj.getString("type"));
		    	bean.setTime(appObj.getString("time"));
		    	hashMap.put(bean.getName(), bean);
		    	
		    }   
		}
		catch(IOException ex)
		{
			Log.d(ReplayConstants.LOG_APPNAME , "IOException while reading file " + ReplayConstants.APPS_FILENAME   );
			ex.printStackTrace();
			throw ex;
		}
		catch(JSONException ex)
		{
			Log.d(ReplayConstants.LOG_APPNAME , "JSONException while parsing JSON file " + ReplayConstants.APPS_FILENAME   );
			ex.printStackTrace();
			throw ex;
		}
		catch(Exception ex)
		{
			Log.d(ReplayConstants.LOG_APPNAME , "Exception while parsing JSON file " + ReplayConstants.APPS_FILENAME   );
			ex.printStackTrace();
			throw ex;
		}
		finally
		{
			if(in != null)
				try {
					in.close();
				} catch (IOException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
		}
		
		return hashMap;
		
		
		
	}

	public static UDPAppJSONInfoBean parseUDPJSON(String appDataFile, Context context) throws Exception {

		
		UDPAppJSONInfoBean appData = new UDPAppJSONInfoBean();
		ArrayList<RequestSet> Q = new ArrayList<RequestSet>();
		HashMap<String, ArrayList<Integer>> csPairs = new HashMap<String, ArrayList<Integer>>();
		String replayName = null;
		BufferedReader in  = null;
		try
		{
			StringBuilder buf=new StringBuilder();
		    InputStream json= context.getAssets().open(appDataFile);
		    in = new BufferedReader(new InputStreamReader(json));
		    String str;

		    while ((str=in.readLine()) != null) {
		      buf.append(str);
		    }

		    in.close();
		    
		    JSONObject jObject = new JSONObject(buf.toString());
		    JSONArray qArray = jObject.getJSONArray("Q");
		    JSONObject temp = null;
		    RequestSet tempRS = null;
		    for(int i= 0; i<qArray.length(); i++)
		    {
		    	temp = qArray.getJSONObject(i);
		    	tempRS = new RequestSet();
		    	tempRS.setc_s_pair(temp.getString("c_s_pair"));
		    	//tempRS.setPayload(temp.get("payload"));
		    	tempRS.setTimestamp(temp.getDouble("timestamp"));
		    	Q.add(tempRS);
		    }
		    
		    
		    JSONObject csPairObject = jObject.getJSONObject("c_s_pairs");
		    Iterator<String> csPairIterator = csPairObject.keys();
		    JSONArray csPairTemp = null;  
		    while(csPairIterator.hasNext())
		    {
		    	String key = csPairIterator.next();
		    	csPairTemp = csPairObject.getJSONArray(key);
		    	ArrayList<Integer> ports = new ArrayList<Integer>();
		    	for(int i= 0; i<csPairTemp.length(); i++)
		    	{
		    		ports.add(csPairTemp.getInt(i));
		    	}
		    	
		    	csPairs.put(key, ports);
		    }
		    
		    replayName = jObject.getString("replay_name");
		    
		    appData.setQ(Q);
		    appData.setCsPairs(csPairs);
		    appData.setReplayName(replayName);
		    
		    
		    
		}
		catch(IOException ex)
		{
			Log.d(ReplayConstants.LOG_APPNAME , "IOException while reading file " + ReplayConstants.APPS_FILENAME   );
			ex.printStackTrace();
			throw ex;
		}
		catch(JSONException ex)
		{
			Log.d(ReplayConstants.LOG_APPNAME , "JSONException while parsing JSON file " + ReplayConstants.APPS_FILENAME   );
			ex.printStackTrace();
			throw ex;
		}
		catch(Exception ex)
		{
			Log.d(ReplayConstants.LOG_APPNAME , "Exception while parsing JSON file " + ReplayConstants.APPS_FILENAME   );
			ex.printStackTrace();
			throw ex;
		}
		finally
		{
			if(in != null)
				try {
					in.close();
				} catch (IOException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
		}
		
		return appData;
	}
	
}
