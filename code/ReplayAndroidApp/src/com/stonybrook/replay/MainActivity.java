package com.stonybrook.replay;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.concurrent.ExecutionException;

import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.json.JSONException;
import org.json.JSONObject;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.AsyncTask;
import android.os.Bundle;
import android.security.KeyChain;
import android.security.KeyChainAliasCallback;
import android.security.KeyChainException;
import android.util.Base64;
import android.util.Log;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.Window;
import android.widget.Button;
import android.widget.GridView;
import android.widget.Spinner;
import android.widget.Toast;

import com.stonybrook.android.data.TrustedCertificateEntry;
import com.stonybrook.android.data.VpnProfile;
import com.stonybrook.android.data.VpnProfileDataSource;
import com.stonybrook.replay.adapter.ImageCheckBoxListAdapter;
import com.stonybrook.replay.bean.ApplicationBean;
import com.stonybrook.replay.constant.ReplayConstants;
import com.stonybrook.replay.exception_handler.ExceptionHandler;
import com.stonybrook.replay.parser.JSONParser;

public class MainActivity extends Activity {

	// add SharedPreferences for consent form
	public static final String STATUS = "MainActPrefsFile";
	SharedPreferences settings;

	// GridView on Main Screen
	GridView appList;
	Button nextButton, settingsButton;
	public HashMap<String, ApplicationBean> appsHashMap = null;
	Context context;

	/**
	 * We can provide email account here on which VPN logs can be received
	 */
	public static final String CONTACT_EMAIL = "demo@gmail.com";
	private static final String DEFAULT_ALIAS = "replay-cert";

	public ArrayList<ApplicationBean> selectedApps = new ArrayList<ApplicationBean>();

	String server = null;
	String enableTiming = null;

	String gateway = "replay.meddle.mobi";

	// Remove this
	// @SuppressLint("NewApi")
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		this.requestWindowFeature(Window.FEATURE_NO_TITLE);

		// Register with Global Exception hanndler
		Thread.setDefaultUncaughtExceptionHandler(new ExceptionHandler(this));

		setContentView(R.layout.activity_main_image);

		// In Android, Network cannot be done on Main thread. But Initially for
		// testing
		// purposes this hack was placed which allowed network usage on main
		// thread
		// Remove this hack...very bad....for only testing purpose
		/*
		 * StrictMode.ThreadPolicy policy = new
		 * StrictMode.ThreadPolicy.Builder().permitAll().build();
		 * StrictMode.setThreadPolicy(policy);
		 */

		try {
			/*
			 * First check to see of Internet access is available
			 * TODO : Identify if connection is WiFi or Cellular
			 */
			if (!isNetworkAvailable()) {
				new AlertDialog.Builder(this)
						.setTitle("Network Error")
						.setMessage(
								"No Internet connection available. Try After connecting to Intenet.")
						.setPositiveButton(android.R.string.ok,
								new DialogInterface.OnClickListener() {
									public void onClick(DialogInterface dialog,
											int which) {
										MainActivity.this.finish();
									}
								}).show();
			}
			context = MainActivity.this.getApplicationContext();

			// This method parses JSON file which contains details for different
			// Applications
			// and returns HashMap of ApplicationBean type
			appsHashMap = JSONParser.parseAppJSON(context);

			// Main screen checkbox Adapter. This is populated from HashMap
			// retrieved from above method
			ImageCheckBoxListAdapter adapter = new ImageCheckBoxListAdapter(
					appsHashMap, getLayoutInflater(), this);

			appList = (GridView) findViewById(R.id.appsListView);
			appList.setAdapter(adapter);

			// Settings of click listeners of buttons on Main Screen
			nextButton = (Button) findViewById(R.id.nextButton);
			nextButton.setOnClickListener(nextButtonClick);

			settingsButton = (Button) findViewById(R.id.settingsButton);
			settingsButton.setOnClickListener(settingsButtonclick);

			// to get certificate status
			settings = getSharedPreferences(STATUS, Context.MODE_PRIVATE);
			boolean userAllowed = settings.getBoolean("userAllowed", false);

			if (!userAllowed) {
				KeyChain.choosePrivateKeyAlias(this,
						new SelectUserCertOnClickListener(), // Callback
						new String[] {}, // Any key types.
						null, // Any issuers.
						"localhost", // Any host
						-1, // Any port
						DEFAULT_ALIAS);

				Toast.makeText(
						context,
						"Please click \"Allow\" to allow using certificate. "
								+ "No need to worry about \"Network may be monitored\" "
								+ "message :)", Toast.LENGTH_LONG).show();
			}

		} catch (Exception ex) {
			Log.d(ReplayConstants.LOG_APPNAME,
					"Exception while parsing JSON file "
							+ ReplayConstants.APPS_FILENAME);
			ex.printStackTrace();
		}

	}

	private class SelectUserCertOnClickListener implements
			KeyChainAliasCallback {
		@Override
		public void alias(final String alias) {
			if (alias != null) {
				try {
					final X509Certificate[] chain = KeyChain
							.getCertificateChain(MainActivity.this, alias);

					Editor editor = settings.edit();
					editor.putBoolean("userAllowed", true);
					editor.commit();

				} catch (KeyChainException e) {
					e.printStackTrace();
				} catch (InterruptedException e) {
					e.printStackTrace();
				}
			} else {
				MainActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						Toast.makeText(MainActivity.this,
								"Please allow us to use certificate!",
								Toast.LENGTH_LONG).show();
					}
				});

				Editor editor = settings.edit();
				editor.putBoolean("userAllowed", false);
				editor.commit();
			}
		}
	}

	@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if ((keyCode == KeyEvent.KEYCODE_BACK)) {
			super.onDestroy();
			finish();
			/*System.runFinalization();
			System.exit(0);*/
		}
		return super.onKeyDown(keyCode, event);
	}

	/**
	 * This method is executed when user clicks on settings button on main
	 * screen. Comments are added inline.
	 */
	OnClickListener settingsButtonclick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			// Creating dialog to display to use
			AlertDialog.Builder builder = new AlertDialog.Builder(
					MainActivity.this);
			builder.setTitle("Settings");

			/**
			 * Select which layout to use. For this dialog, settings_layout.xml
			 * is used. TODO: Layout needs some tweaking such that it can be
			 * made presentable to user
			 */
			View view = LayoutInflater.from(MainActivity.this).inflate(
					R.layout.settings_layout, null);
			builder.setView(view);

			// Set elements of dialog
			final Spinner spinnerTiming = (Spinner) view
					.findViewById(R.id.settings_timing);
			final Spinner spinnerServer = (Spinner) view
					.findViewById(R.id.settings_server);

			// adrian: set installCert button
			final Button installCertButton = (Button) view
					.findViewById(R.id.installCertButton);
			installCertButton.setOnClickListener(installOnClick);

			// final EditText txtServer =
			// (EditText)view.findViewById(R.id.settings_server_txt);

			/**
			 * This will be called when user presses OK button on the dialog.
			 * This will save user preferences. TODO: Here, user preference
			 * saving scope is only session based i.e. If user closes the
			 * application then all the saved preferences lost. Store this
			 * preferences globally. For this Shared preferences can be used
			 * which should be easy to do.
			 */
			builder.setPositiveButton(R.string.ok,
					new DialogInterface.OnClickListener() {
						@Override
						public void onClick(DialogInterface dialog, int id) {
							server = (String) spinnerServer.getSelectedItem();
							enableTiming = (String) spinnerTiming
									.getSelectedItem();
							/*if(!txtServer.getText().toString().trim().isEmpty())
								server = txtServer.getText().toString().trim();*/
							dialog.dismiss();
						}
					});

			/**
			 * Close dialog on click of close button.
			 */
			builder.setNegativeButton(R.string.cancel,
					new DialogInterface.OnClickListener() {
						@Override
						public void onClick(DialogInterface dialog, int id) {
							dialog.dismiss();
						}
					});

			// Create Dialog from DialogBuilder and display it to user
			builder.create().show();
		}
	};

	OnClickListener installOnClick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			downloadAndInstallVpnCreds();

			KeyChain.choosePrivateKeyAlias(MainActivity.this,
					new SelectUserCertOnClickListener(), // Callback
					new String[] {}, // Any key types.
					null, // Any issuers.
					"localhost", // Any host
					-1, // Any port
					DEFAULT_ALIAS);
		}

	};

	/**
	 * This method will be called when user clicks on the next button on main
	 * screen. This method redirects user to ReplayActivity page which display
	 * users apps selected on main page.
	 */
	OnClickListener nextButtonClick = new OnClickListener() {

		@Override
		public void onClick(View v) {

			// check if user allowed to use certificate
			boolean userAllowed = settings.getBoolean("userAllowed", false);
			if (!userAllowed) {
				KeyChain.choosePrivateKeyAlias(MainActivity.this,
						new SelectUserCertOnClickListener(), // Callback
						new String[] {}, // Any key types.
						null, // Any issuers.
						"localhost", // Any host
						-1, // Any port
						DEFAULT_ALIAS);

				Toast.makeText(
						context,
						"Please click \"Allow\" to allow using certificate. "
								+ "No need to worry about \"Network may be monitored\" "
								+ "message :)", Toast.LENGTH_LONG).show();
				return;
			}
			// Check to see if user has selected at least one app from the list.
			if (selectedApps.size() == 0) {
				Toast.makeText(MainActivity.this,
						"Please select at least one application", 1).show();
				return;
			}

			// Create Intent for ReplayActivity and make data of selected apps
			// by user available to ReplayActivity
			Intent intent = new Intent(MainActivity.this, ReplayActivity.class);
			intent.putParcelableArrayListExtra("selectedApps", selectedApps);

			// If user did not select anything from settings dialog then use
			// default preferences and
			// make this available to next activity i.e. ReplayActivity
			if (server == null)
				server = getResources().getStringArray(R.array.server)[0];

			if (enableTiming == null)
				enableTiming = getResources().getStringArray(R.array.timing)[0];

			intent.putExtra("server", server);
			intent.putExtra("timing", enableTiming);

			// Start ReplayActivity with slideIn animation.
			startActivity(intent);
			MainActivity.this.overridePendingTransition(R.anim.slide_in_right,
					R.anim.slide_out_left);
		}
	};

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.main, menu);
		return true;
	}

	/**
	 * This Method checks the network Availability. For this NetworkInfo class
	 * is used and this should also provide type of connectivity i.e. Wi-Fi,
	 * Cellular ..
	 * 
	 * @return
	 */
	private boolean isNetworkAvailable() {
		ConnectivityManager connectivityManager = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
		NetworkInfo activeNetworkInfo = connectivityManager
				.getActiveNetworkInfo();
		return activeNetworkInfo != null && activeNetworkInfo.isConnected();
	}

	/**
	 * Gets VPN credentials and stores them in the VPN datastore
	 */
	private void downloadAndInstallVpnCreds() {

		// get reference to database for storing credentials
		Context context = this.getApplicationContext();
		VpnProfileDataSource mDataSource = new VpnProfileDataSource(context);
		mDataSource.open();

		// create VPN proile, fill it up and save it in the database
		VpnProfile mProfile = new VpnProfile();
		getAndUpdateProfileData(mProfile);

	}

	/**
	 * Fills the VpnProfile object with credentials fetched from the server
	 * 
	 * @param mProfile
	 */
	private void getAndUpdateProfileData(VpnProfile mProfile) {

		try {

			// fetch credentials in an async thread
			FetchCredentialTask task = new FetchCredentialTask(gateway);
			task.execute("");
			JSONObject json = (JSONObject) task.get();

			// we fetch a JSON object, now we need to create a cert from it
			TrustedCertificateEntry mUserCertEntry = new TrustedCertificateEntry(
					json.getString("alias"),
					(X509Certificate) getCertFromString(
							json.getString("alias"), json.getString("cert")));

		} catch (JSONException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (InterruptedException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (ExecutionException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	/**
	 * Converts string of a certificate into an X509 object
	 * 
	 * @param alias
	 * @param certData
	 * @return
	 */
	private Certificate getCertFromString(String alias, String certData) {
		KeyStore keyStore;
		try {
			keyStore = KeyStore.getInstance("PKCS12");

			String pkcs12 = certData;
			byte pkcsBytes[] = Base64.decode(pkcs12.getBytes(), Base64.DEFAULT);
			InputStream sslInputStream = new ByteArrayInputStream(pkcsBytes);
			keyStore.load(sslInputStream, "".toCharArray());

			Intent installIntent = KeyChain.createInstallIntent();

			installIntent.putExtra(KeyChain.EXTRA_PKCS12, pkcsBytes);
			startActivityForResult(installIntent, 0);

			return keyStore.getCertificate(alias);
		} catch (KeyStoreException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (NoSuchAlgorithmException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (CertificateException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		return null;
	}

	/**
	 * Fetches JSON object with VPN credentials
	 * 
	 * @author choffnes
	 * 
	 */
	private class FetchCredentialTask extends AsyncTask {
		private String gateway;

		/**
		 * 
		 * @param gateway
		 *            the domain of host with credentials
		 */
		public FetchCredentialTask(String gateway) {
			this.gateway = gateway;
		}

		@Override
		protected Object doInBackground(Object... arg0) {

			JSONObject json = null;
			try {
				json = new JSONObject(getWebPage("http://" + gateway
						+ ":50080/dyn/getTempCertNoPass"));
			} catch (JSONException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}

			return json;

		}

		private String getWebPage(String url) {
			HttpResponse response = null;
			HttpGet httpGet = null;
			HttpClient mHttpClient = null;
			String s = "";

			try {
				if (mHttpClient == null) {
					mHttpClient = new DefaultHttpClient();
				}

				httpGet = new HttpGet(url);

				response = mHttpClient.execute(httpGet);
				s = EntityUtils.toString(response.getEntity(), "UTF-8");

			} catch (IOException e) {
				e.printStackTrace();
			}
			return s;
		}
	}

}
