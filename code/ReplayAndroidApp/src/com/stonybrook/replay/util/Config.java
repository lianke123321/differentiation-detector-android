package com.stonybrook.replay.util;

import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Properties;

import android.content.Context;
import android.content.res.AssetManager;
import android.util.Log;

/**
 * @author rajesh Configuration main class
 */
public class Config {
	
	static private Context context = null;
	static private Properties properties = new Properties();

	static int maxlen = 0;

	public Config() {
		/*
		 * if (properties == null) { properties = new Properties();
		 * 
		 * }
		 */

	}

	/**
	 * @param configFile
	 * @param context_c
	 *            Read properties file and put all of these key-value pairs in
	 *            properties
	 */
	public static void readConfigFile(String configFile, Context context_c)
			throws Exception {
		AssetManager assetManager;
		InputStream inputStream;
		try {
			context = context_c;
			/**
			 * getAssets() Return an AssetManager instance for your
			 * application's package. AssetManager Provides access to an
			 * application's raw asset files;
			 */
			assetManager = context.getAssets();
			/**
			 * Open an asset using ACCESS_STREAMING mode. This
			 */
			inputStream = assetManager.open(configFile);
			/**
			 * Loads properties from the specified InputStream,
			 */
			properties.load(inputStream);

		} catch (IOException e) {
			e.printStackTrace();
			Log.e("Replay", e.toString());
			throw e;
		}

	}

	/**
	 * @param map
	 *            Add Hashmap to properties object
	 */
	public static void addMapToConfigs(HashMap<String, String> map) {
		for (String key : map.keySet())
			set("port-" + key, String.valueOf(map.get(key)));
	}

	/**
	 * Put key value pair to properties object
	 * 
	 * @param key
	 * @param value
	 */
	public static void set(String key, String value) {
		properties.put(key, value);
	}

	/**
	 * Get value for key from properties object
	 * 
	 * @param key
	 * @return
	 */
	public static String get(String key) {
		return properties.get(key).toString();
	}

	static String show(String key, String value) {
		return key + " \t " + value + " \n ";
	}

	static String showAll() {
		StringBuffer buffer = new StringBuffer();
		for (Object k : properties.keySet())
			buffer.append((String) k).append("\t")
					.append(properties.getProperty((String) k)).append("\n");
		return buffer.toString();
	}

}
