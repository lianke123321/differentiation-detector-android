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
import java.util.Iterator;
import java.util.Locale;
import java.util.concurrent.ExecutionException;

import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.os.AsyncTask;
import android.os.Bundle;
import android.security.KeyChain;
import android.security.KeyChainAliasCallback;
import android.security.KeyChainException;
import android.support.v7.app.ActionBarActivity;
import android.support.v7.widget.Toolbar;
import android.text.Html;
import android.util.Base64;
import android.util.Log;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.GridView;
import android.widget.RelativeLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.gc.materialdesign.views.Button;
import com.stonybrook.android.data.TrustedCertificateEntry;
import com.stonybrook.android.data.VpnProfile;
import com.stonybrook.android.data.VpnProfileDataSource;
import com.stonybrook.replay.adapter.ImageCheckBoxListAdapter;
import com.stonybrook.replay.bean.ApplicationBean;
import com.stonybrook.replay.constant.ReplayConstants;
import com.stonybrook.replay.exception_handler.ExceptionHandler;
import com.stonybrook.replay.parser.JSONParser;
import com.stonybrook.replay.util.Config;
import com.stonybrook.replay.util.RandomString;

public class MainActivity extends ActionBarActivity {

	// add SharedPreferences for consent form
	public static final String STATUS = "MainActPrefsFile";
	private SharedPreferences settings;
	private SharedPreferences history;

	// GridView on Main Screen
	GridView appList;
	TextView useridTextView;

	Button nextButton;

	public HashMap<String, ApplicationBean> appsHashMap = null;
	public HashMap<String, ApplicationBean> randomHashMap = null;
	Context context;

	/**
	 * We can provide email account here on which VPN logs can be received
	 */
	public static final String CONTACT_EMAIL = "contact@ankeli.me";
	// private static final String DEFAULT_ALIAS = "replay5";

	public ArrayList<ApplicationBean> selectedApps = new ArrayList<ApplicationBean>();
	public ArrayList<ApplicationBean> selectedAppsRandom = new ArrayList<ApplicationBean>();

	String server = "replay-s.meddle.mobi";
	String enableTiming = "true";
	int iteration = 2;
	boolean doRandom = false;
	boolean doTest = false;
	boolean forceAddHeader = false;

	// String gateway = null;
	String randomID = null;
	Toolbar toolbar;

	// Remove this
	// @SuppressLint("NewApi")
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		// Register with Global Exception handler
		// Thread.setDefaultUncaughtExceptionHandler(new
		// ExceptionHandler(this));
		Thread.currentThread().setUncaughtExceptionHandler(
				new ExceptionHandler(this));

		setContentView(R.layout.activity_main_image);
		toolbar = (Toolbar) findViewById(R.id.mainimage_bar);
		setSupportActionBar(toolbar);
		getSupportActionBar().setTitle(
				getResources().getString(R.string.main_page_title));

		nextButton = (Button) findViewById(R.id.nextButton);
		nextButton.setOnClickListener(nextButtonOnClick);

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
		/**
		 * Read configuration file and long it into Config object. Configuration
		 * file is located in assets/configuration.properties.
		 */
		try {
			Config.readConfigFile(ReplayConstants.CONFIG_FILE,
					getApplicationContext());
		} catch (Exception e) {
			// TODO Auto-generated catch block
			Log.e("MainActivity", "read config file failed!");
			e.printStackTrace();
			this.finish();
		}
		// gateway = Config.get("vpn_server");

		try {
			/*
			 * First check to see of Internet access is available
			 * TODO : Identify if connection is WiFi or Cellular
			 */
			/*if (!isNetworkAvailable()) {
				new AlertDialog.Builder(this,
						AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
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
			}*/
			context = MainActivity.this.getApplicationContext();

			// This method parses JSON file which contains details for different
			// Applications
			// and returns HashMap of ApplicationBean type
			appsHashMap = JSONParser.parseAppJSON(context);
			randomHashMap = JSONParser.parseRandomJSON(context);

			// Main screen checkbox Adapter. This is populated from HashMap
			// retrieved from above method
			ImageCheckBoxListAdapter adapter = new ImageCheckBoxListAdapter(
					appsHashMap, randomHashMap, getLayoutInflater(), this);

			appList = (GridView) findViewById(R.id.appsListView);
			appList.setAdapter(adapter);

			// to get randomID
			settings = getSharedPreferences(STATUS, Context.MODE_PRIVATE);
			history = getSharedPreferences(ReplayActivity.STATUS,
					Context.MODE_PRIVATE);

			// generate or retrieve an id for this phone
			boolean hasID = settings.getBoolean("hasID", false);
			if (!hasID) {
				randomID = new RandomString(10).nextString();
				Editor editor = settings.edit();
				editor.putBoolean("hasID", true);
				editor.putString("ID", randomID);
				editor.commit();
				Log.d("MainActivity", "generate new ID: " + randomID);
			} else {
				randomID = settings.getString("ID", null);
				Log.d("MainActivity", "retrieve existing ID: " + randomID);
			}

			useridTextView = (TextView) findViewById(R.id.useridTextView);
			useridTextView.setText("User ID: " + randomID);

			/*Toast.makeText(
					context,
					"Please click the tick button on top right when finishing choosing applications",
					Toast.LENGTH_LONG).show();*/

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
			Log.d("cert", "in");
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

	/*@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if ((keyCode == KeyEvent.KEYCODE_BACK)) {
			super.onDestroy();
			finish();
			System.runFinalization();
			System.exit(0);
		}
		return super.onKeyDown(keyCode, event);
	}*/

	OnClickListener installOnClick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			boolean userAllowed = settings.getBoolean("userAllowed", false);
			if (!userAllowed) {
				new AlertDialog.Builder(MainActivity.this,
						AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
						.setTitle("PLEASE READ ME!!!")
						.setMessage(
								"We are going to install a certificate that allows our tests to run."
										+ "When prompted for a password,\n\n    TYPE: 1234\n\n"
										+ "and click \"OK\".\n\n"
										+ "If you are using Android 5.x, please restart your phone after "
										+ "installing certificate to avoid a bug of Android.")
						.setPositiveButton(
								"Read instructions above carefully before clicking here!",
								new DialogInterface.OnClickListener() {
									public void onClick(DialogInterface dialog,
											int which) {
										Log.d("MainActivity",
												"proceed to install credential");
										// download credentials
										downloadAndInstallVpnCreds();
									}
								}).show();

				/*downloadAndInstallVpnCreds();

				KeyChain.choosePrivateKeyAlias(MainActivity.this,
						new SelectUserCertOnClickListener(), // Callback
						new String[] {}, // Any key types.
						null, // Any issuers.
						"localhost", // Any host
						-1, // Any port
						null);*/
			} else {
				Toast.makeText(context,
						"Certificate has already been installed!",
						Toast.LENGTH_LONG).show();
			}
		}

	};

	OnClickListener nextButtonOnClick = new OnClickListener() {
		@Override
		public void onClick(View v) {
			// TODO Auto-generated method stub
			boolean userAllowed = settings.getBoolean("userAllowed", false);
			if (!userAllowed) {
				KeyChain.choosePrivateKeyAlias(MainActivity.this,
						new SelectUserCertOnClickListener(), // Callback
						new String[] {}, // Any key types.
						null, // Any issuers.
						"localhost", // Any host
						-1, // Any port
						null);

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
						"Please select at least one application",
						Toast.LENGTH_LONG).show();
				return;
			}

			// Create Intent for ReplayActivity and make data of selected apps
			// by user available to ReplayActivity
			Intent intent = new Intent(MainActivity.this, ReplayActivity.class);
			intent.putParcelableArrayListExtra("selectedApps", selectedApps);
			intent.putParcelableArrayListExtra("selectedAppsRandom",
					selectedAppsRandom);

			// If user did not select anything from settings dialog then use
			// default preferences and
			// make this available to next activity i.e. ReplayActivity
			if (server == null)
				server = getResources().getStringArray(R.array.server)[0];

			if (enableTiming == null)
				enableTiming = getResources().getStringArray(R.array.timing)[0];

			intent.putExtra("server", server);
			intent.putExtra("timing", enableTiming);
			intent.putExtra("iteration", iteration);
			intent.putExtra("doRandom", doRandom);
			intent.putExtra("doTest", doTest);
			intent.putExtra("forceAddHeader", forceAddHeader);
			intent.putExtra("randomID", randomID);

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

	public boolean onOptionsItemSelected(MenuItem item) {
		// Handle action bar item clicks here. The action bar will
		// automatically handle clicks on the Home/Up button, so long
		// as you specify a parent activity in AndroidManifest.xml.
		int id = item.getItemId();
		if (id == R.id.main_navigate) {
			/**
			 * This will be called when user clicks on the tick button on main
			 * screen. This method redirects user to ReplayActivity page which
			 * display users apps selected on main page.
			 */
			// check if user allowed to use certificate

			boolean userAllowed = settings.getBoolean("userAllowed", false);
			if (!userAllowed) {
				KeyChain.choosePrivateKeyAlias(MainActivity.this,
						new SelectUserCertOnClickListener(), // Callback
						new String[] {}, // Any key types.
						null, // Any issuers.
						"localhost", // Any host
						-1, // Any port
						null);

				Toast.makeText(
						context,
						"Please click \"Allow\" to allow using certificate. "
								+ "No need to worry about \"Network may be monitored\" "
								+ "message :)", Toast.LENGTH_LONG).show();
				return true;
			}

			// Check to see if user has selected at least one app from the list.
			if (selectedApps.size() == 0) {
				Toast.makeText(MainActivity.this,
						"Please select at least one application",
						Toast.LENGTH_LONG).show();
				return true;
			}

			// Create Intent for ReplayActivity and make data of selected apps
			// by user available to ReplayActivity
			Intent intent = new Intent(MainActivity.this, ReplayActivity.class);
			intent.putParcelableArrayListExtra("selectedApps", selectedApps);
			intent.putParcelableArrayListExtra("selectedAppsRandom",
					selectedAppsRandom);

			// If user did not select anything from settings dialog then use
			// default preferences and
			// make this available to next activity i.e. ReplayActivity
			if (server == null)
				server = getResources().getStringArray(R.array.server)[0];

			if (enableTiming == null)
				enableTiming = getResources().getStringArray(R.array.timing)[0];

			intent.putExtra("server", server);
			intent.putExtra("timing", enableTiming);
			intent.putExtra("iteration", iteration);
			intent.putExtra("doRandom", doRandom);
			intent.putExtra("doTest", doTest);
			intent.putExtra("forceAddHeader", forceAddHeader);
			intent.putExtra("randomID", randomID);

			// Start ReplayActivity with slideIn animation.
			startActivity(intent);
			MainActivity.this.overridePendingTransition(R.anim.slide_in_right,
					R.anim.slide_out_left);
		} else if (id == R.id.action_settings) {
			/**
			 * This method is executed when user clicks on settings button on
			 * main screen. Comments are added inline.
			 */

			// Creating dialog to display to use
			AlertDialog.Builder builder = new AlertDialog.Builder(
					MainActivity.this, AlertDialog.THEME_DEVICE_DEFAULT_LIGHT);
			// builder.setTitle("Settings");

			/**
			 * Select which layout to use. For this dialog, settings_layout.xml
			 * is used.
			 */
			View view = LayoutInflater
					.from(MainActivity.this)
					.inflate(
							R.layout.settings_layout,
							(RelativeLayout) findViewById(R.layout.activity_main_image));
			builder.setView(view);

			// Set elements of dialog
			final Spinner spinnerTiming = (Spinner) view
					.findViewById(R.id.settings_timing);
			// set value of timing
			if (enableTiming.equalsIgnoreCase("true"))
				spinnerTiming.setSelection(0);
			else
				spinnerTiming.setSelection(1);

			/*final Spinner spinnerServer = (Spinner) view
					.findViewById(R.id.settings_server);*/
			final EditText textServer = (EditText) view
					.findViewById(R.id.settings_server);
			textServer.setText(server);
			final Spinner spinnerIteration = (Spinner) view
					.findViewById(R.id.settings_iteration);
			// set value of iteration
			if (iteration == 2)
				spinnerIteration.setSelection(0);
			else if (iteration == 3)
				spinnerIteration.setSelection(1);

			final CheckBox checkBoxRandom = (CheckBox) view
					.findViewById(R.id.selectRandomCheckBox);
			checkBoxRandom.setChecked(doRandom);

			final CheckBox checkBoxAddHeader = (CheckBox) view
					.findViewById(R.id.forceAddHeaderCheckBox);
			checkBoxAddHeader.setChecked(forceAddHeader);

			final CheckBox checkBoxTest = (CheckBox) view
					.findViewById(R.id.selectTestCheckBox);
			checkBoxTest.setChecked(doTest);

			// set installCert button

			final Button installCertButton = (Button) view
					.findViewById(R.id.installCertButton);
			// final Button installCertButton = (Button) view
			// .findViewById(R.id.installCertButton);
			installCertButton.setOnClickListener(installOnClick);

			// (EditText)view.findViewById(R.id.settings_server_txt);

			builder.setPositiveButton(R.string.ok,
					new DialogInterface.OnClickListener() {
						@Override
						public void onClick(DialogInterface dialog, int id) {
							server = (String) textServer.getText().toString()
									.trim();
							Config.set("vpn_server", server);
							enableTiming = (String) spinnerTiming
									.getSelectedItem();
							iteration = Integer
									.parseInt((String) spinnerIteration
											.getSelectedItem());
							// doRandom = checkBoxRandom.isCheck();
							doRandom = checkBoxRandom.isChecked();
							forceAddHeader = checkBoxAddHeader.isChecked();
							doTest = checkBoxTest.isChecked();
							/*Log.d("settings", "doRandom: " + doRandom
									+ " forceAddHeader: " + forceAddHeader
									+ " doTest: " + doTest);
							Log.d("MainActivity",
									"Iteration time: "
											+ String.valueOf(iteration));*/

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

			// Toast.makeText(this, "Hey you just hit "+item.getTitle(),
			// Toast.LENGTH_SHORT).show();
			// return true;
		} else if (id == R.id.action_history) {
			// Creating dialog to display to use
			AlertDialog.Builder builder = new AlertDialog.Builder(
					MainActivity.this, AlertDialog.THEME_DEVICE_DEFAULT_LIGHT);
			builder.setTitle("Previous Results");

			View view = LayoutInflater.from(MainActivity.this).inflate(
					R.layout.history_layout,
					(RelativeLayout) findViewById(R.layout.activity_main_image));
			builder.setView(view);
			TextView tv = (TextView) view.findViewById(R.id.historyTextview);

			// get results
			// Set<String> results = settings.getStringSet("lastResult", null);
			try {
				JSONObject resultsWithDate = new JSONObject(history.getString(
						"lastResult", "{}"));

				String finalResult = "";

				// if (results != null && !results.isEmpty()) {
				if (resultsWithDate.length() > 0) {
					Log.d("MainActivity",
							"Retrieve results succeeded! results: "
									+ resultsWithDate.toString());
					// Iterator<String> it = results.iterator();
					Iterator<String> it = resultsWithDate.keys();
					while (it.hasNext()) {
						String strDate = it.next();
						finalResult += (strDate + ": \n\n");

						// JSONObject response = new JSONObject(it.next());
						JSONArray responses = resultsWithDate
								.getJSONArray(strDate);
						for (int i = 0; i < responses.length(); i++) {
							JSONObject response = responses.getJSONObject(i);
							String replayName = response
									.getString("replayName").split("-")[0]
									.toUpperCase(Locale.US);
							int diff = response.getInt("diff");
							double rate = response.getDouble("rate");

							if (diff == -1) {
								finalResult += ("    " + replayName + ":\n        no differentiation\n\n");
							} else if (diff == 0) {
								finalResult += ("    " + replayName + ":\n        inconclusive result\n\n");
							} else if (diff == 1) {
								String speed = rate < 0 ? "faster" : "slower";
								String processedRate = String
										.valueOf((int) Math.abs(rate * 100))
										+ "% ";
								finalResult += ("    "
										+ replayName
										+ ":\n        differentiation detected, "
										+ processedRate + speed + "\n\n");
							} else {
								Log.w("MainActivity",
										"diff has abnormal value");
							}
						}
					}

					// display processed results
					tv.setText(finalResult);
				} else {
					Log.d("MainActivity", "No result available");
				}
			} catch (JSONException e1) {
				// TODO Auto-generated catch block
				e1.printStackTrace();
			}

			builder.setPositiveButton(R.string.ok,
					new DialogInterface.OnClickListener() {
						@Override
						public void onClick(DialogInterface dialog, int id) {
							dialog.dismiss();
						}
					});

			// Create Dialog from DialogBuilder and display it to user
			builder.create().show();
		} else if (id == R.id.action_help) {
			// Creating dialog to display to use
			AlertDialog.Builder builder = new AlertDialog.Builder(
					MainActivity.this, AlertDialog.THEME_DEVICE_DEFAULT_LIGHT);
			builder.setTitle("Help");

			View view = LayoutInflater
					.from(MainActivity.this)
					.inflate(
							R.layout.help_layout,
							(RelativeLayout) findViewById(R.layout.activity_main_image));
			builder.setView(view);
			TextView helpTextView = (TextView) view
					.findViewById(R.id.helpTextView);
			helpTextView.setText(Html.fromHtml(getResources().getString(
					R.string.help_info)));

			builder.setPositiveButton(R.string.ok,
					new DialogInterface.OnClickListener() {
						@Override
						public void onClick(DialogInterface dialog, int id) {
							dialog.dismiss();
						}
					});

			// Create Dialog from DialogBuilder and display it to user
			builder.create().show();
		}

		return super.onOptionsItemSelected(item);
	}

	@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		// TODO Auto-generated method stub
		if (keyCode == KeyEvent.KEYCODE_BACK) {
			MainActivity.this.finish();
			MainActivity.this.overridePendingTransition(
					android.R.anim.slide_in_left,
					android.R.anim.slide_out_right);
		}

		return super.onKeyDown(keyCode, event);
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
			Log.d("getAndUpdateProfileData",
					"vpn_server: " + Config.get("vpn_server"));
			FetchCredentialTask task = new FetchCredentialTask(
					Config.get("vpn_server"));
			task.execute("");
			JSONObject json = (JSONObject) task.get();

			// we fetch a JSON object, now we need to create a cert from it
			TrustedCertificateEntry mUserCertEntry = new TrustedCertificateEntry(
					json.getString("alias"),
					(X509Certificate) getCertFromString(
							json.getString("alias"), json.getString("cert"),
							json.getString("pass")));

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
	private Certificate getCertFromString(String alias, String certData,
			String passwd) {
		KeyStore keyStore;
		try {
			keyStore = KeyStore.getInstance("PKCS12");

			String pkcs12 = certData;
			byte pkcsBytes[] = Base64.decode(pkcs12.getBytes(), Base64.DEFAULT);
			InputStream sslInputStream = new ByteArrayInputStream(pkcsBytes);
			keyStore.load(sslInputStream, passwd.toCharArray());

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
						+ ":50080/dyn/getTempCertPassRandom"));
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
