/* Copyright 2012 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.stonybrook.replay.util;

import java.util.List;

import android.content.Context;
import android.location.Criteria;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.location.LocationProvider;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Build;
import android.os.Bundle;
import android.os.Looper;
import android.telephony.NeighboringCellInfo;
import android.telephony.TelephonyManager;
import android.util.Log;

import com.stonybrook.replay.bean.DeviceInfoBean;

public class Mobilyzer {

	private Context context;
	private TelephonyManager telephonyManager;
	private ConnectivityManager connectivityManager;
	private LocationManager locationManager;
	private String locationProviderName;
	private Criteria criteriaCoarse;
	private LoggingLocationListener locationListener;

	private static final String[] NETWORK_TYPES = { "UNKNOWN", // 0 -
																// NETWORK_TYPE_UNKNOWN
			"GPRS", // 1 - NETWORK_TYPE_GPRS
			"EDGE", // 2 - NETWORK_TYPE_EDGE
			"UMTS", // 3 - NETWORK_TYPE_UMTS
			"CDMA", // 4 - NETWORK_TYPE_CDMA
			"EVDO_0", // 5 - NETWORK_TYPE_EVDO_0
			"EVDO_A", // 6 - NETWORK_TYPE_EVDO_A
			"1xRTT", // 7 - NETWORK_TYPE_1xRTT
			"HSDPA", // 8 - NETWORK_TYPE_HSDPA
			"HSUPA", // 9 - NETWORK_TYPE_HSUPA
			"HSPA", // 10 - NETWORK_TYPE_HSPA
			"IDEN", // 11 - NETWORK_TYPE_IDEN
			"EVDO_B", // 12 - NETWORK_TYPE_EVDO_B
			"LTE", // 13 - NETWORK_TYPE_LTE
			"EHRPD", // 14 - NETWORK_TYPE_EHRPD
			"HSPAP", // 15 - NETWORK_TYPE_HSPAP
	};

	public Mobilyzer(Context context) {
		super();
		this.context = context;

		// initialize telephone manager
		this.telephonyManager = (TelephonyManager) this.context
				.getSystemService(Context.TELEPHONY_SERVICE);

		// initialize connectivity manager
		this.connectivityManager = (ConnectivityManager) this.context
				.getSystemService(Context.CONNECTIVITY_SERVICE);

		// initialize location manager
		this.locationManager = (LocationManager) this.context
				.getSystemService(Context.LOCATION_SERVICE);
		criteriaCoarse = new Criteria();
		/*
		 * "Coarse" accuracy means "no need to use GPS". Typically a gShots
		 * phone would be located in a building, and GPS may not be able to
		 * acquire a location. We only care about the location to determine the
		 * country, so we don't need a super accurate location, cell/wifi is
		 * good enough.
		 */
		criteriaCoarse.setAccuracy(Criteria.ACCURACY_COARSE);
		criteriaCoarse.setPowerRequirement(Criteria.POWER_LOW);
		locationProviderName = this.locationManager.getBestProvider(
				criteriaCoarse, true);

		List<String> providers = this.locationManager.getAllProviders();
		for (String providerNameIter : providers) {
			try {
				LocationProvider provider = this.locationManager
						.getProvider(providerNameIter);
			} catch (SecurityException se) {
				// Not allowed to use this provider
				Log.w("Mobilyzer", "Unable to use provider " + providerNameIter);
				// se.printStackTrace();
				continue;
			}
			Log.i("Mobilyzer", providerNameIter + ": " + (this.locationManager
					.isProviderEnabled(providerNameIter) ? "enabled" : "disabled"));
		}

		/*
		 * Make sure the provider updates its location. Without this, we may get
		 * a very old location, even a device powercycle may not update it.
		 * {@see android.location.LocationManager.getLastKnownLocation}.
		 */
		locationListener = new LoggingLocationListener();
		this.locationManager.requestLocationUpdates(locationProviderName, 0, 0,
				locationListener, Looper.getMainLooper());
	}

	public DeviceInfoBean getDeviceInfo() {

		DeviceInfoBean deviceInfoBean = new DeviceInfoBean();

		// deviceInfoBean.deviceId = getDeviceId();
		deviceInfoBean.manufacturer = Build.MANUFACTURER;
		deviceInfoBean.model = Build.MODEL;
		deviceInfoBean.os = getVersionStr();
		// deviceInfoBean.user = Build.VERSION.CODENAME;

		// get phone type
		/*
		 * switch (telephonyManager.getPhoneType()) {
		 * 
		 * case TelephonyManager.PHONE_TYPE_SIP: deviceInfoBean.phoneType =
		 * "SIP"; case TelephonyManager.PHONE_TYPE_CDMA:
		 * deviceInfoBean.phoneType = "CDMA"; case
		 * TelephonyManager.PHONE_TYPE_GSM: deviceInfoBean.phoneType = "GSM";
		 * case TelephonyManager.PHONE_TYPE_NONE: deviceInfoBean.phoneType =
		 * "NONE"; default: deviceInfoBean.phoneType = "UNKNOWN"; }
		 */

		// get network operator name
		deviceInfoBean.carrierName = telephonyManager.getNetworkOperatorName();

		// get network type
		NetworkInfo networkInfo = connectivityManager
				.getNetworkInfo(ConnectivityManager.TYPE_WIFI);
		if (networkInfo != null
				&& networkInfo.getState() == NetworkInfo.State.CONNECTED) {
			deviceInfoBean.networkType = "WIFI";
		} else {
			int typeIndex = telephonyManager.getNetworkType();
			if (typeIndex < NETWORK_TYPES.length)
				deviceInfoBean.networkType = NETWORK_TYPES[typeIndex];
			else
				deviceInfoBean.networkType = "Unrecognized: " + typeIndex;
		}

		// get cell info
		List<NeighboringCellInfo> infos = telephonyManager
				.getNeighboringCellInfo();
		StringBuffer buf = new StringBuffer();
		String tempResult = "";
		if (infos.size() > 0) {
			for (NeighboringCellInfo info : infos) {
				tempResult = info.getLac() + "," + info.getCid() + ","
						+ info.getRssi() + ";";
				buf.append(tempResult);
			}
			// Removes the trailing semicolon
			buf.deleteCharAt(buf.length() - 1);
			deviceInfoBean.cellInfo = buf.toString();
		} else {
			deviceInfoBean.cellInfo = "FAILED";
		}

		// get location
		try {
			Location location = locationManager
					.getLastKnownLocation(locationProviderName);
			if (location == null) {
				Log.e("Mobilyzer", "Cannot obtain location from provider "
						+ locationProviderName);
				deviceInfoBean.location = new Location("unknown");
			} else {
				deviceInfoBean.location = location;
			}
		} catch (IllegalArgumentException e) {
			Log.e("Mobilyzer", "Cannot obtain location", e);
			deviceInfoBean.location = new Location("unknown");
		}
		// shouldn't remove the listener since the following replays also
		// need to get location
		//locationManager.removeUpdates(locationListener);
		
		// get APN setting
		/*final Uri PREFERRED_APN_URI = Uri.parse("content://telephony/carriers/preferapn");
		Cursor c = this.context.getContentResolver().query(PREFERRED_APN_URI, null, null, null, null);
		c.moveToFirst();
		int index = c.getColumnIndex("name");
		Log.d("Mobilyzer", c.getString(index));*/

		return deviceInfoBean;
	}

	/*
	 * private String getDeviceId() { // This ID is permanent to a physical
	 * phone. String deviceId = telephonyManager.getDeviceId();
	 * 
	 * // "generic" means the emulator. if (deviceId == null ||
	 * Build.DEVICE.equals("generic")) {
	 * 
	 * // This ID changes on OS reinstall/factory reset. deviceId =
	 * Secure.getString(context.getContentResolver(), Secure.ANDROID_ID); }
	 * 
	 * return deviceId; }
	 */

	private static String getVersionStr() {
		return String.format("INCREMENTAL:%s, RELEASE:%s, SDK_INT:%s",
				Build.VERSION.INCREMENTAL, Build.VERSION.RELEASE,
				Build.VERSION.SDK_INT);
	}

	/**
	 * A dummy listener that just logs callbacks.
	 */
	private static class LoggingLocationListener implements LocationListener {

		@Override
		public void onLocationChanged(Location location) {
			Log.d("Mobilyzer", "location changed");
		}

		@Override
		public void onProviderDisabled(String provider) {
			Log.d("Mobilyzer", "provider disabled: " + provider);
		}

		@Override
		public void onProviderEnabled(String provider) {
			Log.d("Mobilyzer", "provider enabled: " + provider);
		}

		@Override
		public void onStatusChanged(String provider, int status, Bundle extras) {
			Log.d("Mobilyzer", "status changed: " + provider + "=" + status);
		}
	}
}
