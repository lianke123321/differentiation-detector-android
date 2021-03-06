package mobi.meddle.diffdetector;

import java.io.IOException;
import java.net.ConnectException;
import java.net.InetAddress;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.HashMap;

import mobi.meddle.diffdetector.R;
import mobi.meddle.diffdetector.adapter.ImageReplayRecyclerViewAdapter;
import mobi.meddle.diffdetector.bean.ApplicationBean;
import mobi.meddle.diffdetector.bean.JitterBean;
import mobi.meddle.diffdetector.bean.ServerInstance;
import mobi.meddle.diffdetector.bean.SocketInstance;
import mobi.meddle.diffdetector.bean.UDPReplayInfoBean;
import mobi.meddle.diffdetector.bean.UpdateUIBean;
import mobi.meddle.diffdetector.bean.combinedAppJSONInfoBean;
import mobi.meddle.diffdetector.combined.CTCPClient;
import mobi.meddle.diffdetector.combined.CUDPClient;
import mobi.meddle.diffdetector.combined.CombinedNotifierThread;
import mobi.meddle.diffdetector.combined.CombinedQueue;
import mobi.meddle.diffdetector.combined.CombinedReceiverThread;
import mobi.meddle.diffdetector.combined.CombinedSideChannel;
import mobi.meddle.diffdetector.combined.ResultChannelThread;
import mobi.meddle.diffdetector.exception_handler.ExceptionHandler;
import mobi.meddle.diffdetector.util.Config;
import mobi.meddle.diffdetector.util.Mobilyzer;
import mobi.meddle.diffdetector.util.ReplayCompleteListener;
import mobi.meddle.diffdetector.util.UnpickleDataStream;

import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.BasicHttpParams;
import org.apache.http.params.HttpConnectionParams;
import org.apache.http.params.HttpParams;
import org.apache.http.util.EntityUtils;
import org.json.JSONException;

import android.app.AlertDialog;
import android.app.Dialog;
import android.app.DialogFragment;
import android.app.ProgressDialog;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.VpnService;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v7.app.ActionBarActivity;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.support.v7.widget.Toolbar;
import android.util.Log;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.WindowManager;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import com.gc.materialdesign.views.ButtonFloat;
import com.stonybrook.android.data.VpnProfile;
import com.stonybrook.android.data.VpnProfileDataSource;
import com.stonybrook.android.logic.CharonVpnService;
import com.stonybrook.android.logic.TrustedCertificateManager;

/**
 * This activity handles all replay-related stuff TODO: find a way to safely
 * kill all threads when app is crashed or interrupted by user
 * 
 * @author Rajesh, Adrian
 * 
 */
public class ReplayActivity extends ActionBarActivity implements
		ReplayCompleteListener {

	// add SharedPreferences for consent form
	public static final String STATUS = "ReplayActPrefsFile";
	SharedPreferences settings;
	boolean networkAvailable = true;

	ArrayList<ApplicationBean> selectedApps = null;
	ArrayList<ApplicationBean> selectedAppsRandom = null;

	RecyclerView appsRecyclerView = null;
	RecyclerView.LayoutManager appsRecyclerViewLayoutManager;
	// ListView appsListView = null;
	TextView selectedAppsMsgTextView = null;
	TextView selectedAppsSizeTextView = null;
	Context context = null;
	ProgressDialog progress = null;

	boolean replayOngoing = false;

	// adrian: for progress bar
	// ProgressBarDeterminate prgBar;
	ProgressBar prgBar;
	ButtonFloat replayButton;
	// ProgressBar prgBar;
	UpdateUIBean updateUIBean;

	int currentReplayCount = 0;
	int currentIterationCount = 0;
	// ImageReplayListAdapter adapter = null;
	ImageReplayRecyclerViewAdapter adapter = null;

	String server = null;
	String enableTiming = null;
	int iteration = 2;
	boolean doRandom = false;
	boolean doTest = false;
	boolean forceAddHeader = false;
	boolean onlyRandom = false;

	// String GATE_WAY = Config.get("vpn_server");
	String meddleIP = null;

	// This is AsyncTasks for replay. Run in background.
	QueueCombinedAsync queueCombined = null;
	String currentTask = "none";
	String randomID = null;
	int historyCount;

	// This is result channel thread
	ResultChannelThread resultChannelThread = null;
	Thread resultThread = null;

	// VPN Changes
	private Bundle mProfileInfo;
	/**
	 * We can provide email account here on which VPN logs can be received
	 */
	private static final int PREPARE_VPN_SERVICE = 0;
	boolean isKeyChainInitialized = false;
	boolean isVPNConnected = false;

	// Objects to store data for apps
	combinedAppJSONInfoBean appData_combined = null;

	// for testing mobilyzer
	public Mobilyzer mobilyzer = null;

	// for all asynctask, create here
	TestVPN testVpn = null;
	VPNConnected vpnConnected = null;
	VPNDisconnected vpnDisconnected = null;
	RandomReplay randomReplay = null;
	Toolbar toolbar;

	// define all asynctasks here for future clean up
	// CertificateLoadTask certificateLoadTask = null;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		// Thread.setDefaultUncaughtExceptionHandler(new
		// ExceptionHandler(this));
		Thread.currentThread().setUncaughtExceptionHandler(
				new ExceptionHandler(this));
		setContentView(R.layout.activity_replay_image);
		toolbar = (Toolbar) findViewById(R.id.relay_main_bar);
		setSupportActionBar(toolbar);
		getSupportActionBar().setTitle(
				getResources().getString(R.string.selected_apps));

		getSupportActionBar().setHomeButtonEnabled(true);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);

		replayButton = (ButtonFloat) findViewById(R.id.replayButtonFloat);
		replayButton.setOnClickListener(replayButtonOnClick);

		// keep the screen on
		getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

		// First check to see of Internet access is available

		if (!isNetworkAvailable()) {
			new AlertDialog.Builder(this,
					AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
					.setTitle("Network Error")
					.setMessage(
							"No Internet connection available. Try After connecting to Intenet.")
					.setPositiveButton(android.R.string.ok,
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int which) {
									ReplayActivity.this.finish();
								}
							}).show();
			networkAvailable = false;
		} else {
			(new GetReplayServerAndMeddleIP()).execute("");
		}

		// Extract data that was sent by previous activity. In our case, list of
		// apps, server and timing
		context = getApplicationContext();
		selectedApps = getIntent().getParcelableArrayListExtra("selectedApps");
		selectedAppsRandom = getIntent().getParcelableArrayListExtra(
				"selectedAppsRandom");

		for (int i = 0; i < selectedApps.size(); i++)
			Log.d("Replay", "selected JSON name: " + selectedApps.get(i).name
					+ " " + selectedAppsRandom.get(i).name);

		enableTiming = (String) getIntent().getStringExtra("timing");
		iteration = (int) getIntent().getIntExtra("iteration", 2);
		doRandom = getIntent().getBooleanExtra("doRandom", false);
		doTest = getIntent().getBooleanExtra("doTest", false);
		forceAddHeader = getIntent().getBooleanExtra("forceAddHeader", false);
		randomID = getIntent().getStringExtra("randomID");
		Log.d("ReplayActivity", "iteration: " + String.valueOf(iteration)
				+ " doRandom: " + doRandom + " doTest: " + doTest
				+ " forceAddHeader: " + forceAddHeader + " randomID: "
				+ randomID);

		// Create layout for this page
		// adapter = new ImageReplayListAdapter(selectedApps,
		// getLayoutInflater(),
		// this, iteration, doRandom);
		adapter = new ImageReplayRecyclerViewAdapter(selectedApps, this,
				iteration, doRandom);

		appsRecyclerView = (RecyclerView) findViewById(R.id.appsRecyclerView);
		appsRecyclerViewLayoutManager = new LinearLayoutManager(this);
		appsRecyclerView.setLayoutManager(appsRecyclerViewLayoutManager);
		appsRecyclerView.setAdapter(adapter);

		// appsListView = (ListView) findViewById(R.id.appsListView);
		// appsListView.setAdapter(adapter);

		// Register button listeners
		currentReplayCount = 0;

		updateSelectedTextViews(selectedApps);

		// to get historyCount
		settings = getSharedPreferences(STATUS, Context.MODE_PRIVATE);

		// generate or retrieve an historyCount for this phone
		boolean hasHistoryCount = settings.getBoolean("hasHistoryCount", false);
		if (!hasHistoryCount) {
			historyCount = 0;
			Editor editor = settings.edit();
			editor.putBoolean("hasHistoryCount", true);
			editor.putInt("historyCount", historyCount);
			editor.commit();
			Log.d("Replay", "initialized history count.");
		} else {
			historyCount = settings.getInt("historyCount", -1);
			Log.d("Replay", "retrieve existing historyCount: " + historyCount);
		}
		// check if retrieve historyCount succeeded
		if (historyCount == -1)
			throw new RuntimeException();

		// adrian: for progress bar
		prgBar = (ProgressBar) findViewById(R.id.prgBar);
		// prgBar = (ProgressBar) findViewById(R.id.prgBar);
		prgBar.setVisibility(View.GONE);
		updateUIBean = new UpdateUIBean();

		Log.d("Replay", "Loading VPN certificates");
		new CertificateLoadTask().executeOnExecutor(
				AsyncTask.THREAD_POOL_EXECUTOR, false);

		/**
		 * Dave commented out to test auto-credentials
		 * KeyChain.choosePrivateKeyAlias(ReplayActivity.this, new
		 * SelectUserCertOnClickListener(), new String[] { "RSA" }, null, null,
		 * -1, "adrian-replay");
		 */

		// initialize mobilyzer
		mobilyzer = new Mobilyzer(this.context);

		/*while (server == null) {
			try {
				Log.w("Replay", "Main thread sleeping!");
				Thread.sleep(1000);
			} catch (InterruptedException e) {
				Log.w("Replay", "sleeping interrupted");
			}
		}*/

		if (networkAvailable) {
			/*Toast.makeText(
					context,
					"Please click the tick button on top right to start the replay!",
					Toast.LENGTH_LONG).show();*/

			new AlertDialog.Builder(ReplayActivity.this,
					AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
					.setTitle("One more thing...")
					.setMessage(
							"Please leave the app running in the foreground "
									+ "until replay is over in order to avoid "
									+ "interruptions from other apps in your "
									+ "phone.\n\nThe screen will stay on during "
									+ "the replay.\n\nThank you for your cooperation!")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								@Override
								public void onClick(DialogInterface dialog,
										int which) {
									// nothing
								}
							}).show();
		}

		// this is for testing log sending code
		// throw new RuntimeException("Crash!");
		// ACRA.getErrorReporter().handleSilentException(
		// new RuntimeException("test ACRA"));

		// test result sharing
		/*Set<String> results = new HashSet<String>();
		results.add("{\"replayName\":\"youtube-360p\",\"diff\":0,\"rate\":0}");
		results.add("{\"replayName\":\"viber-video-10secs\",\"diff\":1,\"rate\":0.3}");
		results.add("{\"replayName\":\"skype-video-10secs\",\"diff\":1,\"rate\":-0.24}");
		results.add("{\"replayName\":\"hangout-video-10secs\",\"diff\":-1,\"rate\":0}");
		results.add("{\"replayName\":\"netflix-auto-5secs\",\"diff\":0,\"rate\":0}");
		results.add("{\"replayName\":\"spotify-normal-15secs\",\"diff\":1,\"rate\":0.735}");
		Log.d("Replay", "fake results: " + results.toString());
		Editor editor = settings.edit();
		editor.putStringSet("lastResult", results);
		editor.commit();*/

	}

	@Override
	protected void onStop() {

		super.onStop();
		if (replayOngoing) {
			ReplayActivity.this.runOnUiThread(new Runnable() {
				public void run() {
					Toast.makeText(ReplayActivity.this, "Replay aborted",
							Toast.LENGTH_LONG).show();
				}

			});
		}
		disconnectVPN();

		// here I clean up all dangling threads and AsyncTasks
		if (queueCombined != null) {
			queueCombined.cancel(true);
		}
		/*if (certificateLoadTask != null) {
			certificateLoadTask.cancel(true);
			Log.d("onStop", "certificateLoadTask is cancelled? "
					+ certificateLoadTask.isCancelled());
		}*/
		if (resultChannelThread != null)
			resultChannelThread.forceQuit = true;

		// this.finish();
	}

	/*@Override
	protected void onDestroy() {
		// TODO: figure out if I need to do anything here
		this.onStop();
		super.onDestroy();
	}*/

	OnClickListener replayButtonOnClick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			if (!networkAvailable) {
				Toast.makeText(
						context,
						"Network not available, please re-open this app after connecting to network.",
						Toast.LENGTH_LONG).show();
			} else if (!replayOngoing) {
				currentReplayCount = 0;
				processApplicationReplay();

			} else
				Toast.makeText(context,
						"Replay is ongoing! Please do not start again.",
						Toast.LENGTH_LONG).show();
		}

	};

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
	 * This method is entry point for any application replay Here, first server
	 * reachability is checked and according to type of app (TCP or UDP) request
	 * is forwarded to methods
	 */
	void processApplicationReplay() {

		// update progress
		selectedApps.get(currentReplayCount).status = getResources().getString(
				R.string.start_replay);
		adapter.notifyDataSetChanged();

		replayOngoing = true;

		try {

			Config.set("timing", enableTiming);

			// make sure server is initialized!
			while (server == null) {
				Thread.sleep(1000);
			}
			Config.set("server", server);

			// adrian: added cause arash's code
			Config.set("jitter", "true");
			// Config.set("sendMobileStats", "true");
			// adrian: set result
			// Config.set("result", "false");
			// adrian: set public IP
			Config.set("publicIP", "");
			new Thread(new Runnable() {
				public void run() {
					Config.set("publicIP", getPublicIP());
				}

			}).start();

			while (Config.get("publicIP") == "") {
				Thread.sleep(500);
			}

			if (Config.get("publicIP") == "127.0.0.1")
				Log.e("Replay", "failed to get public ip");

			Log.d("Replay", "public IP: " + Config.get("publicIP"));
			// Check server reachability
			boolean isAvailable = (new ServerReachable()).execute(server).get();
			Log.d("Replay",
					"Server availability " + String.valueOf(isAvailable));

			if (isAvailable) {
				// Creating result channel thread here
				resultChannelThread = new ResultChannelThread(
						ReplayActivity.this, server, Integer.valueOf(Config
								.get("result_port")), randomID, selectedApps,
						getResources().getString(R.string.finish_vpn),
						getResources().getString(R.string.finish_random),
						adapter, settings);
				resultThread = new Thread(resultChannelThread);
				resultThread.start();

				// If server is available. Change status from to processing
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.processing);
				adapter.notifyDataSetChanged();

				// Forward request to respective method with required data
				/*
				 * if (selectedApps.get(currentReplayCount).getType()
				 * .equalsIgnoreCase("tcp"))
				 * processTCPApplication(selectedApps.get(currentReplayCount));
				 * else
				 * processUDPApplication(selectedApps.get(currentReplayCount));
				 */

				// start new task to test vpn
				onVpnProfileSelected(null);
				Log.d("Replay", "VPN started");

				testVpn = new TestVPN();
				testVpn.execute(this);

			} else {
				replayOngoing = false;
				Toast.makeText(ReplayActivity.this,
						"Sorry, server is not available. Try after some time.",
						Toast.LENGTH_LONG).show();
			}

		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}

	/**
	 * This method processes Replay for combined application. 1) Parse pickle
	 * file 2) Start AsyncTask for combined with the parsed pickle data
	 * 
	 * @param applicationBean
	 * @throws Exception
	 */
	private void processCombinedApplication(ApplicationBean applicationBean,
			String env) throws Exception {

		currentTask = "combined";

		// adrian: update progress
		applicationBean.status = getResources().getString(R.string.load_q);
		ReplayActivity.this.runOnUiThread(new Runnable() {
			public void run() {
				adapter.notifyDataSetChanged();
			}
		});

		/*appData_combined = UnpickleDataStream.unpickleCombinedJSON(
				applicationBean.getDataFile(), context);
		Log.d("Parsing", applicationBean.getDataFile());
		queueCombined = new QueueCombinedAsync(this, applicationBean, env);

		queueCombined.execute("");*/
		vpnDisconnected = new VPNDisconnected();
		vpnDisconnected.execute(this);

		// adrian: for testing VPN
		/*
		 * onVpnProfileSelected(null); Log.d("Replay", "Testing VPN");
		 * 
		 * selectedApps.get(currentReplayCount).status = getResources()
		 * .getString(R.string.vpn); adapter.notifyDataSetChanged();
		 * 
		 * (new VPNConnected()).execute(this);
		 */

	}

	void updateSelectedTextViews(ArrayList<ApplicationBean> list) {
		selectedAppsMsgTextView = (TextView) findViewById(R.id.selectedAppsMsgTextView);
		selectedAppsSizeTextView = (TextView) findViewById(R.id.selectedAppsSizeTextView);

		selectedAppsMsgTextView.setText(String.valueOf(list.size())
				+ (list.size() > 1 ? " applications selected"
						: " application selected"));
		double totalSize = 0.0;

		for (int i = 0; i < list.size(); i++) {
			if (doRandom)
				totalSize += list.get(i).getSize() * 3 * iteration;
			else
				totalSize += list.get(i).getSize() * 2 * iteration;
		}

		DecimalFormat df = new DecimalFormat("#.##");
		selectedAppsSizeTextView.setText(df.format(totalSize).toString()
				+ " MB");

	}

	/**
	 * Simple check to see if server is reachable. No port listen checks are
	 * being done here.
	 * 
	 * @author rajesh
	 * 
	 */
	class ServerReachable extends AsyncTask<String, String, Boolean> {

		@Override
		protected Boolean doInBackground(String... arg0) {
			Thread.currentThread().setName("ServerReachable (AsyncTask)");
			Boolean isReachable = true;
			String serverIP = arg0[0];
			try {
				isReachable = InetAddress.getByName(serverIP).isReachable(2000);
			} catch (Exception e) {
				isReachable = false;
				e.printStackTrace();
			}

			return isReachable;

		}

	}

	/**
	 * Right now pickle files are stored in Assets folder which increases the
	 * apk file size. I wrote this to get files from Server. For testing purpose
	 * I wrote small Server. This can be later integrated in to python Server.
	 * TODO: this need more work and testing. Try integrating this with main
	 * code and see what happens.
	 * 
	 * @author rajesh
	 * 
	 */
	/*
	 * private class FileDownload extends AsyncTask<Void, Void, Void> {
	 * 
	 * String serverName = null; int portNo; String appName;
	 * ReplayCompleteListener listener;
	 *//**
	 * @param serverName
	 * @param portNo
	 * @param appName
	 */
	/*
	 * public FileDownload(ReplayCompleteListener listener, String serverName,
	 * int portNo, String appName) { this.serverName = serverName; this.portNo =
	 * portNo; this.appName = appName; this.listener = listener; }
	 * 
	 * boolean success = true;
	 * 
	 * @Override protected void onPostExecute(Void result) {
	 * this.listener.fileExistsListener(success); }
	 *//**
	 * Actual work will be done here. Check if file exists. If it does then
	 * return otherwise Create socket and download file from server and save it
	 * to internal storage.
	 */
	/*
	 * @Override protected Void doInBackground(Void... params) { try { Socket
	 * client = null; PrintWriter writer; BufferedReader reader; int bytesRead;
	 * int currentTot = 0; File file = null; FileOutputStream fos = null;
	 * BufferedOutputStream bos = null; try {
	 * 
	 * // Check to see whether file exists file = new
	 * File(context.getFilesDir(), appName + ".pcap_client_pickle"); if
	 * (file.exists()) { Log.d("Replay", "File " + file.getName() +
	 * " exists!!!"); return null; } // If not download client = new Socket();
	 * client.connect(new InetSocketAddress(serverName, portNo)); reader = new
	 * BufferedReader(new InputStreamReader( client.getInputStream())); writer =
	 * new PrintWriter(client.getOutputStream(), true);
	 * 
	 * writer.println(appName);
	 * 
	 * long fileLen = Long.parseLong(reader.readLine()); Log.d("Replay",
	 * "File size is " + fileLen);
	 * 
	 * Log.d("Replay", "context directory path is " + context.getFilesDir());
	 * 
	 * byte[] bytearray = new byte[(int) fileLen]; InputStream is =
	 * client.getInputStream();
	 * 
	 * fos = new FileOutputStream(file); bos = new BufferedOutputStream(fos);
	 * bytesRead = is.read(bytearray, 0, bytearray.length); currentTot =
	 * bytesRead;
	 * 
	 * while (currentTot < fileLen && bytesRead > 0) { bytesRead =
	 * is.read(bytearray, currentTot, (bytearray.length - currentTot)); if
	 * (bytesRead >= 0) currentTot += bytesRead; } // Put this code in finally
	 * bos.write(bytearray, 0, currentTot); bos.flush();
	 * 
	 * } catch (Exception ex) { ex.printStackTrace(); } finally { if (bos !=
	 * null) bos.close(); try { if (client != null) client.close(); } catch
	 * (IOException e) { e.printStackTrace(); } } } catch (Exception ex) {
	 * success = false; ex.printStackTrace(); } return null; } }
	 */

	class QueueCombinedAsync extends AsyncTask<String, String, String> {

		combinedAppJSONInfoBean appData = null;
		ApplicationBean applicationBean = null;
		long timeStarted = 0;
		// This is Listener which will be called when this method finishes. More
		// information about this is provided in ReplayCompleteListener file.
		private ReplayCompleteListener listener;
		boolean success = true;
		// This simply identifies whether we are in open or VPN
		public String channel = null;

		public QueueCombinedAsync(ReplayCompleteListener listener,
				ApplicationBean applicationBean, String channel) {
			this.listener = listener;
			this.channel = channel;
			this.applicationBean = applicationBean;
			// this.prgBar = (ProgressBar) findViewById(R.id.prgBar);
		}

		@Override
		protected void onPostExecute(String result) {

			// Callback according to type of Replay with status of Replay
			if (channel.equalsIgnoreCase("open"))
				listener.openFinishCompleteCallback(success);
			else if (channel.equalsIgnoreCase("vpn"))
				listener.vpnFinishCompleteCallback(success);
			else if (channel.equalsIgnoreCase("random"))
				listener.randomFinishCompleteCallback(success);
			else {
				Log.d("Queue", "unknown replay type!");
				System.exit(0);
			}
		}

		// this method handles all UI updates, running on main thread
		protected void onProgressUpdate(String... values) {
			if (values[0].equalsIgnoreCase("updateStatus")) {
				applicationBean.status = values[1];
				adapter.notifyDataSetChanged();
			} else if (values[0].equalsIgnoreCase("updateUI")) {
				if (prgBar.getVisibility() == View.GONE)
					prgBar.setVisibility(View.VISIBLE);
				prgBar.setProgress(updateUIBean.getProgress());
			} else if (values[0].equalsIgnoreCase("finishProgress")) {
				prgBar.setProgress(0);
				prgBar.setVisibility(View.GONE);
			} else if (values[0].equalsIgnoreCase("makeToast")) {
				Toast.makeText(ReplayActivity.this, values[1],
						Toast.LENGTH_LONG).show();
			} else if (values[0].equalsIgnoreCase("makeDialog")) {
				new AlertDialog.Builder(ReplayActivity.this,
						AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
						.setTitle("Error")
						.setMessage(values[1])
						.setPositiveButton("OK",
								new DialogInterface.OnClickListener() {
									@Override
									public void onClick(DialogInterface dialog,
											int which) {
										queueCombined.cancel(true);
										disconnectVPN();
										if (resultChannelThread != null)
											resultChannelThread.forceQuit = true;
										ReplayActivity.this.finish();
									}
								}).show();
			} else
				Log.e("onProgressUpdate", "unknown instruction!");

		}

		@Override
		protected String doInBackground(String... str) {
			Thread.currentThread().setName("QueueCombinedAsync (AsyncTask)");
			// testing manually free memory
			System.gc();

			int replayIndex = 0;
			String replayTimeStatus = null;

			if (onlyRandom) {
				if (channel.equalsIgnoreCase("open"))
					replayIndex = currentIterationCount * 2 + 1;
				else if (channel.equalsIgnoreCase("random"))
					replayIndex = currentIterationCount * 2 + 2;
				else
					Log.w("replayIndex", "replay name error: " + channel);
			} else if (doRandom) {
				if (channel.equalsIgnoreCase("open"))
					replayIndex = currentIterationCount * 3 + 1;
				else if (channel.equalsIgnoreCase("vpn"))
					replayIndex = currentIterationCount * 3 + 2;
				else if (channel.equalsIgnoreCase("random"))
					replayIndex = currentIterationCount * 3 + 3;
				else
					Log.w("replayIndex", "replay name error: " + channel);
			} else {
				if (channel.equalsIgnoreCase("open"))
					replayIndex = currentIterationCount * 2 + 1;
				else if (channel.equalsIgnoreCase("vpn"))
					replayIndex = currentIterationCount * 2 + 2;
				else
					Log.w("replayIndex", "replay name error: " + channel);
			}

			replayTimeStatus = String.valueOf(replayIndex)
					+ "/"
					+ (doRandom ? String.valueOf(iteration * 3) : String
							.valueOf(iteration * 2)) + " ";

			// for testing crash handler
			/*if (true) {
				throw new RuntimeException();
			}*/

			if (channel.equalsIgnoreCase("open") && currentIterationCount == 0) {
				publishProgress("makeToast",
						"First iteration of current replay!");
			}

			this.appData = appData_combined;
			HashMap<String, CTCPClient> CSPairMapping = new HashMap<String, CTCPClient>();
			// adrian: create a hash map for udp
			HashMap<String, CUDPClient> udpPortMapping = new HashMap<String, CUDPClient>();

			try {
				/**
				 * used to wait 5 sec, now checkVPN is called in
				 * openFinishCompleteCallBack instead of here. So don't need to
				 * do anything here
				 * 
				 * @author Adrian
				 * 
				 */
				// adrian: update progress
				/*applicationBean.status = getResources().getString(
						R.string.create_side_channel);*/
				publishProgress("updateStatus", replayTimeStatus
						+ getResources()
								.getString(R.string.create_side_channel));

				int sideChannelPort = Integer.valueOf(Config
						.get("combined_sidechannel_port"));
				// String randomID = new RandomString(10).nextString();
				if (randomID == null) {
					Log.d("RecordReplay", "randomID does not exit!");
					System.exit(0);
				}

				SocketInstance socketInstance = new SocketInstance(server,
						sideChannelPort, null);
				Log.d("Server", server);

				CombinedSideChannel sideChannel = new CombinedSideChannel(
						socketInstance, randomID);
				// adrian: new format of serverPortsMap
				HashMap<String, HashMap<String, HashMap<String, ServerInstance>>> serverPortsMap = null;
				UDPReplayInfoBean udpReplayInfoBean = new UDPReplayInfoBean();

				// adrian: for recording jitter and payload
				JitterBean jitterBean = new JitterBean();

				// adrian: new declareID() function
				String testID = null;
				if (channel.equalsIgnoreCase("random"))
					testID = "RANDOM_"
							+ String.valueOf(currentIterationCount + 1);
				else if (channel.equalsIgnoreCase("vpn"))
					testID = "VPN_" + String.valueOf(currentIterationCount + 1);
				else
					testID = "NOVPN_"
							+ String.valueOf(currentIterationCount + 1);

				Log.d("testID", "testID is " + testID);

				if (testID.equalsIgnoreCase("NOVPN_1")) {
					// First update historyCount
					historyCount += 1;
					// Then write current historyCount to applicationBean
					applicationBean.historyCount = historyCount;
					Editor editor = settings.edit();
					editor.putInt("historyCount", historyCount);
					editor.commit();
					Log.d("Replay",
							"historyCount: " + String.valueOf(historyCount));

				}

				// initialize endOfTest value
				boolean endOfTest = false;
				if (currentIterationCount + 1 == iteration
						&& (channel.equalsIgnoreCase("random") || (channel
								.equalsIgnoreCase("vpn") && (!doRandom)))) {
					Log.w("Replay", "last replay!");
					endOfTest = true;
				}

				if (doTest)
					Log.w("Replay", "include -Test string");

				sideChannel.declareID(appData.getReplayName(),
						// for indicating end of test
						endOfTest ? "True" : "False",
						testID,
						// add a tail for testing data
						doTest ? Config.get("extraString") + "-Test" : Config
								.get("extraString"), String
								.valueOf(historyCount));

				// adrian: update progress
				/*applicationBean.status = getResources().getString(
						R.string.ask4permission);*/
				publishProgress("updateStatus", replayTimeStatus
						+ getResources().getString(R.string.ask4permission));

				String[] permission = sideChannel.ask4Permission();
				Log.d("Replay", "permission[0]: " + permission[0]
						+ " permission[1]: " + permission[1]);
				if (permission[0].trim().equalsIgnoreCase("0")) {
					if (permission[1].trim().equalsIgnoreCase("1")) {
						publishProgress("makeDialog",
								"No such replay on server!\n"
										+ "Click \"OK\" to go back.");
						// Thread.sleep(30000);
						throw new Exception();
					} else if (permission[1].trim().equalsIgnoreCase("2")) {
						publishProgress("makeDialog",
								"No permission: another client with same IP address is running. "
										+ "Wait for it to finish!\n"
										+ "Click \"OK\" to go back.");
						// Thread.sleep(30000);
						throw new Exception();
					} else {
						publishProgress("makeDialog", "Unknown error!\n"
								+ "Click \"OK\" to go back.");
						// Thread.sleep(30000);
						throw new Exception();
					}
				} else {
					if (forceAddHeader) {
						Log.w("Replay", "Enable addHeader by user instruction");
						Config.set("addHeader", "true");
					} else if (!getPublicIP().trim().equalsIgnoreCase(
							permission[1].trim())) {
						Log.w("Replay",
								"IP flipping detected! enable addHeader.");
						Config.set("addHeader", "true");
					} else if (!this.channel.equalsIgnoreCase("vpn")) {
						// if IP is consistent, disable addHeader
						Log.d("Replay",
								"public IP consistent. disable addHeader");
						Config.set("addHeader", "false");
					} else {
						// do nothing because this is vpn replay
					}

					Config.set("publicIP", permission[1].trim());
				}

				// always send noIperf here
				sideChannel.sendIperf();

				// send device info
				sideChannel.sendMobileStats(Config.get("sendMobileStats"),
						mobilyzer);

				/**
				 * Ask for port mapping from server. For some reason, port map
				 * info parsing was throwing error. so, I put while loop to do
				 * this until port mapping is parsed successfully.
				 */
				// adrian: update progress
				/*applicationBean.status = getResources().getString(
						R.string.receive_server_port_mapping);*/
				publishProgress(
						"updateStatus",
						replayTimeStatus
								+ getResources().getString(
										R.string.receive_server_port_mapping));

				try {
					// randomID = new RandomString(10).nextString();
					serverPortsMap = sideChannel.receivePortMappingNonBlock();
					udpReplayInfoBean.setSenderCount(sideChannel
							.receiveSenderCount());
					Log.d("Replay",
							"Successfully received serverPortsMap and senderCount!");
				} catch (JSONException ex) {
					Log.d("Replay",
							"failed to receive serverPortsMap and senderCount!");
					ex.printStackTrace();
					return "";
				}

				/**
				 * Create clients from CSPairs
				 */

				// adrian: update progress
				/*applicationBean.status = getResources().getString(
						R.string.create_tcp_client);*/
				publishProgress("updateStatus", replayTimeStatus
						+ getResources().getString(R.string.create_tcp_client));

				for (String csp : appData.getTcpCSPs()) {
					String destIP = csp.substring(csp.lastIndexOf('-') + 1,
							csp.lastIndexOf("."));
					String destPort = csp.substring(csp.lastIndexOf('.') + 1,
							csp.length());
					ServerInstance instance = serverPortsMap.get("tcp")
							.get(destIP).get(destPort);
					if (instance.server.trim().equals(""))
						instance.server = server; // serverPortsMap.get(destPort);
					// adrian: pass two more parameters: randomID and replayName
					// compared with python client
					CTCPClient c = new CTCPClient(csp, instance.server,
							Integer.valueOf(instance.port), randomID,
							appData.getReplayName(), Config.get("publicIP"),
							Boolean.valueOf(Config.get("addHeader")));
					CSPairMapping.put(csp, c);
				}
				Log.d("Replay", "created clients from CSPairs");

				/**
				 * adrian: create clients from udpClientPorts
				 */

				// adrian: update progress
				/*applicationBean.status = getResources().getString(
						R.string.create_udp_client);*/
				publishProgress("updateStatus", replayTimeStatus
						+ getResources().getString(R.string.create_udp_client));

				for (String originalClientPort : appData.getUdpClientPorts()) {
					CUDPClient c = new CUDPClient(Config.get("publicIP"));
					udpPortMapping.put(originalClientPort, c);
				}
				Log.d("Replay", "created clients from udpClientPorts");

				Log.d("Replay",
						"Size of CSPairMapping is "
								+ String.valueOf(CSPairMapping.size()));
				Log.d("Replay",
						"Size of udpPortMapping is "
								+ String.valueOf(udpPortMapping.size()));

				// adrian: for waiting for all threads to die
				ArrayList<Thread> threadList = new ArrayList<Thread>();

				// adrian: starting notifier thread

				// adrian: update progress
				/*applicationBean.status = getResources().getString(
						R.string.run_notf);*/
				publishProgress("updateStatus", replayTimeStatus
						+ getResources().getString(R.string.run_notf));

				CombinedNotifierThread notifier = sideChannel
						.notifierCreater(udpReplayInfoBean);
				Thread notfThread = new Thread(notifier);
				notfThread.start();
				threadList.add(notfThread);

				// adrian: starting receiver thread

				// adrian: update progress
				/*applicationBean.status = getResources().getString(
						R.string.run_receiver);*/
				publishProgress("updateStatus", replayTimeStatus
						+ getResources().getString(R.string.run_receiver));

				CombinedReceiverThread receiver = new CombinedReceiverThread(
						udpReplayInfoBean, jitterBean);
				Thread rThread = new Thread(receiver);
				rThread.start();
				threadList.add(rThread);

				// adrian: starting UI updating thread
				Thread UIUpdateThread = new Thread(new Runnable() {
					@Override
					public void run() {
						prgBar.setProgress(0);
						updateUIBean.setProgress(0);
						Thread.currentThread().setName(
								"UIUpdateThread (Thread)");
						while (updateUIBean.getProgress() < 100) {
							publishProgress("updateUI");
							try {
								Thread.sleep(500);
							} catch (InterruptedException e) {
								Log.d("UpdateUI", "sleeping interrupted!");
							}
						}

						// make progress bar to be 100%
						publishProgress("updateUI");

						Log.d("UpdateUI", "completed!");
					}
				});

				UIUpdateThread.start();
				threadList.add(UIUpdateThread);

				// Running the Queue (Sender)

				// adrian: update progress
				/*applicationBean.status = getResources().getString(
						R.string.run_sender);*/
				publishProgress("updateStatus", replayTimeStatus
						+ getResources().getString(R.string.run_sender));

				CombinedQueue queue = new CombinedQueue(appData.getQ(),
						jitterBean);
				this.timeStarted = System.nanoTime();
				queue.run(updateUIBean, CSPairMapping, udpPortMapping,
						udpReplayInfoBean, serverPortsMap.get("udp"),
						Boolean.valueOf(Config.get("timing")), server);

				// waiting for all threads to finish
				Log.d("Replay", "waiting for all threads to die!");

				Thread.sleep(1000);
				notifier.doneSending = true;
				notfThread.join();
				receiver.keepRunning = false;
				rThread.join();

				// Telling server done with replaying
				double duration = ((double) (System.nanoTime() - this.timeStarted)) / 1000000000;

				// adrian: update progress
				/*applicationBean.status = getResources().getString(
						R.string.send_done);*/
				publishProgress("updateStatus", replayTimeStatus
						+ getResources().getString(R.string.send_done));

				sideChannel.sendDone(duration);
				Log.d("Replay", "replay finished using time " + duration + " s");

				// Sending jitter

				// adrian: update progress
				String message = "";
				if (queue.ABORT == true) {
					Log.w("Replay", "replay aborted!");
					message = queue.abort_reason;
					success = false;
				} else {
					message = getResources().getString(R.string.send_jitter);
				}

				// applicationBean.status = message;
				publishProgress("updateStatus", replayTimeStatus + message);

				sideChannel.sendJitter(randomID, Config.get("jitter"),
						jitterBean);

				// Getting result
				sideChannel.getResult(Config.get("result"));

				// closing side channel socket
				sideChannel.closeSideChannelSocket();

				// set progress bar to invisible
				publishProgress("finishProgress");

			} catch (ConnectException ce) {
				Log.w("Replay", "Server unavailable!");
				ce.printStackTrace();
				success = false;

				publishProgress("makeToast",
						"Sorry, our server is currently not running. "
								+ "Please try another time.");
				this.cancel(true);
				if (resultChannelThread != null)
					resultChannelThread.forceQuit = true;
				ReplayActivity.this.finish();
			} catch (JSONException ex) {
				Log.e("Replay", "Error parsing JSON");
				ex.printStackTrace();
				success = false;
				this.cancel(true);
				if (resultChannelThread != null)
					resultChannelThread.forceQuit = true;
				// ACRA.getErrorReporter().handleException(ex);
				// ReplayActivity.this.finish();
			} catch (InterruptedException ex) {
				Log.w("Replay", "Replay interrupted!");
				success = false;
				this.cancel(true);
				if (resultChannelThread != null)
					resultChannelThread.forceQuit = true;
			} catch (SocketTimeoutException ex) {
				Log.e("Replay", "Replay failed due to socket timeout!");
				success = false;
				this.cancel(true);
				if (resultChannelThread != null)
					resultChannelThread.forceQuit = true;
			} catch (IOException ex) {
				Log.e("Replay", "Replay failed due to IOException!");
				ex.printStackTrace();
				success = false;
				this.cancel(true);
				if (resultChannelThread != null)
					resultChannelThread.forceQuit = true;
			} catch (Exception ex) {
				success = false;
				Log.e("Replay", "replay failed due to unknow reason!");
				ex.printStackTrace();

				/*publishProgress("makeToast",
						"Sorry, replay failed due to unknown reason.");*/
				// throw new RuntimeException();
				this.cancel(true);
				// ACRA.getErrorReporter().handleException(ex);
				if (resultChannelThread != null)
					resultChannelThread.forceQuit = true;
				ReplayActivity.this.finish();
			}

			Log.d("Replay", "queueCombined finished execution!");
			return null;
		}
	}

	/**
	 * This method is called when replay over VPN is finished
	 */
	@Override
	public void vpnFinishCompleteCallback(Boolean success) {
		try {
			server = Config.get("server");

			String oldStatus = selectedApps.get(currentReplayCount).status;

			// updating progress
			selectedApps.get(currentReplayCount).status = getResources()
					.getString(R.string.disconnect_vpn);
			adapter.notifyDataSetChanged();

			disconnectVPN();

			if (!success) {
				// Update status on screen and stop processing
				// selectedApps.get(currentReplayCount).resultImg = "p";
				/*selectedApps.get(currentReplayCount++).status = getResources()
						.getString(R.string.error);
				adapter.notifyDataSetChanged();*/
				replayOngoing = false;

				// set progress bar to invisible
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						prgBar.setProgress(0);
						prgBar.setVisibility(View.GONE);
					}
				});

				// restore abort reason to status
				selectedApps.get(currentReplayCount).status = oldStatus;
				adapter.notifyDataSetChanged();

				/*replayOngoing = false;

				new AlertDialog.Builder(ReplayActivity.this)
						.setTitle("Replay aborted!")
						.setMessage(
								"There is an error that happened during replay and caused "
										+ "the replay to stop. All previous successful "
										+ "replays are still recorded in our server.\n"
										+ "You could try it again.\n\n"
										+ "Thank you for your support and contribution "
										+ "to this research!")
						.setPositiveButton("Go back",
								new DialogInterface.OnClickListener() {
									@Override
									public void onClick(DialogInterface dialog,
											int which) {
										if (queueCombined != null) {
											vpnConnected.cancel(true);
											vpnDisconnected.cancel(true);
											randomReplay.cancel(true);
											queueCombined.cancel(true);
										}
										disconnectVPN();
										ReplayActivity.this.finish();
										ReplayActivity.this
												.overridePendingTransition(
														android.R.anim.slide_in_left,
														android.R.anim.slide_out_right);
									}
								}).show();

				return;*/

			} else {

				if (doRandom) {
					// updating progress
					selectedApps.get(currentReplayCount).status = getResources()
							.getString(R.string.random);
					adapter.notifyDataSetChanged();

					randomReplay = new RandomReplay();
					randomReplay.execute(this);
					return;
				}

				currentIterationCount++;

				if (currentIterationCount != iteration) {

					// tell user current iteration
					if (currentIterationCount == 1)
						Toast.makeText(ReplayActivity.this,
								"Second iteration of current replay!",
								Toast.LENGTH_LONG).show();
					else if (currentIterationCount == 2)
						Toast.makeText(ReplayActivity.this,
								"Third iteration of current replay!",
								Toast.LENGTH_LONG).show();
					else {
						Log.w("Replay", "Iteration number exceeds!");
						System.exit(0);
					}

					vpnDisconnected = new VPNDisconnected();
					vpnDisconnected.execute(this);
					return;
				}

				/**
				 * Change status on screen. Here currentReplayCount stores
				 * number of applications selected by user. ++ makes processing
				 * of next application in list when processApplicationReplay()
				 * is called.
				 */

				// selectedApps.get(currentReplayCount).resultImg = "p";
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.finish_vpn);
				adapter.notifyDataSetChanged();
			}

			// initialize this for the next application
			currentIterationCount = 0;

			// If there are more apps that require processing then start with
			// those.
			if (selectedApps.size() != (currentReplayCount + 1)) {
				// (new StartNextApp()).execute(this);
				// processCombinedApplication(selectedApps.get(++currentReplayCount),
				// "vpn");
				currentReplayCount++;
				vpnDisconnected = new VPNDisconnected();
				vpnDisconnected.execute(this);
			} else {
				// progressWait.setMessage("Finishing Analysis...");
				// Thread.sleep(10000);
				// progressWait.dismiss();
				currentReplayCount = 0;
				Log.d("Replay", "finished all replays!");
				replayOngoing = false;

				// notify result channel thread
				resultChannelThread.doneReplay = true;
				// wait for all results to be received

				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						new AlertDialog.Builder(ReplayActivity.this,
								AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
								.setTitle("Replay finished!")
								.setMessage(
										"Replay of all applications you have chosen is done! "
												+ "You might need to wait a few more seconds "
												+ "for all the results!\n\n"
												+ "Thank you and have a great day :-)")
								.setPositiveButton("OK",
										new DialogInterface.OnClickListener() {

											@Override
											public void onClick(
													DialogInterface dialog,
													int which) {
												// do nothing
											}
										}).show();
					}

				});
			}

		} catch (Exception ex) {
			ex.printStackTrace();
		} finally {
			// Disconnect VPN. No matter whether replay was successful or not
		}

	}

	@Override
	public void randomFinishCompleteCallback(Boolean success) {
		try {
			if (!success) {
				// Update status on screen and stop processing
				// selectedApps.get(currentReplayCount).resultImg = "p";
				/*selectedApps.get(currentReplayCount++).status = getResources()
						.getString(R.string.error);
				adapter.notifyDataSetChanged();*/
				replayOngoing = false;

				// set progress bar to invisible
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						prgBar.setProgress(0);
						prgBar.setVisibility(View.GONE);
					}
				});

				/*new AlertDialog.Builder(ReplayActivity.this)
						.setTitle("Replay aborted!")
						.setMessage(
								"There is an error happened during replay and caused "
										+ "replay to stop. All previous successful "
										+ "replays are still recorded in our server.\n"
										+ "You could try it again.\n\n"
										+ "Thank you for your support and contribution "
										+ "to this research!")
						.setPositiveButton("Go back",
								new DialogInterface.OnClickListener() {
									@Override
									public void onClick(DialogInterface dialog,
											int which) {
										if (queueCombined != null) {
											vpnConnected.cancel(true);
											vpnDisconnected.cancel(true);
											randomReplay.cancel(true);
											queueCombined.cancel(true);
										}
										disconnectVPN();
										ReplayActivity.this.finish();
										ReplayActivity.this
												.overridePendingTransition(
														android.R.anim.slide_in_left,
														android.R.anim.slide_out_right);
									}
								}).show();

				return;*/
			} else {

				currentIterationCount++;

				if (currentIterationCount != iteration) {

					// tell user current iteration
					if (currentIterationCount == 1)
						Toast.makeText(ReplayActivity.this,
								"Second iteration of current replay!",
								Toast.LENGTH_LONG).show();
					else if (currentIterationCount == 2)
						Toast.makeText(ReplayActivity.this,
								"Third iteration of current replay!",
								Toast.LENGTH_LONG).show();
					else {
						Log.w("Replay", "Iteration number exceeds!");
						System.exit(0);
					}

					vpnDisconnected = new VPNDisconnected();
					vpnDisconnected.execute(this);
					return;
				}

				/**
				 * Change status on screen. Here currentReplayCount stores
				 * number of applications selected by user. ++ makes processing
				 * of next application in list when processApplicationReplay()
				 * is called.
				 */

				// selectedApps.get(currentReplayCount).resultImg = "p";
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.finish_random);
				adapter.notifyDataSetChanged();
			}

			// initialize this for the next application
			currentIterationCount = 0;

			// If there are more apps that require processing then start with
			// those.
			if (selectedApps.size() != (currentReplayCount + 1)) {
				// (new StartNextApp()).execute(this);
				// processCombinedApplication(selectedApps.get(++currentReplayCount),
				// "vpn");
				currentReplayCount++;

				vpnDisconnected = new VPNDisconnected();
				vpnDisconnected.execute(this);
			} else {
				// progressWait.setMessage("Finishing Analysis...");
				// Thread.sleep(10000);
				// progressWait.dismiss();
				currentReplayCount = 0;
				Log.d("Replay", "finished all replays!");
				replayOngoing = false;

				// notify result channel thread
				resultChannelThread.doneReplay = true;
				// resultThread.join();

				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						new AlertDialog.Builder(ReplayActivity.this,
								AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
								.setTitle("Replay finished!")
								.setMessage(
										"Replay of all applications you have chosen is done! "
												+ "You might need to wait a few more seconds "
												+ "for all the results!\n\n"
												+ "Thank you and have a great day :-)")
								.setPositiveButton("OK",
										new DialogInterface.OnClickListener() {

											@Override
											public void onClick(
													DialogInterface dialog,
													int which) {
												// do nothing
											}
										}).show();
					}

				});

			}

		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}

	/**
	 * Called when Replay is finished over Open channel. Connects to VPN and
	 * starts replay for same App again
	 */
	@Override
	public void openFinishCompleteCallback(Boolean success) {
		try {
			// If Replay on Open was successful then schedule on VPN
			if (!success) {
				// Update status on screen and stop processing
				// selectedApps.get(currentReplayCount).resultImg = "p";
				/*selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.error);
				adapter.notifyDataSetChanged();*/
				replayOngoing = false;

				// set progress bar to invisible
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						prgBar.setProgress(0);
						prgBar.setVisibility(View.GONE);
					}
				});

				/*new AlertDialog.Builder(ReplayActivity.this)
						.setTitle("Replay aborted!")
						.setMessage(
								"There is an error happened during replay and caused "
										+ "replay to stop. All previous successful "
										+ "replays are still recorded in our server.\n"
										+ "You could try it again.\n\n"
										+ "Thank you for your support and contribution "
										+ "to this research!")
						.setPositiveButton("Go back",
								new DialogInterface.OnClickListener() {
									@Override
									public void onClick(DialogInterface dialog,
											int which) {
										if (queueCombined != null) {
											vpnConnected.cancel(true);
											vpnDisconnected.cancel(true);
											randomReplay.cancel(true);
											queueCombined.cancel(true);
										}
										disconnectVPN();
										ReplayActivity.this.finish();
										ReplayActivity.this
												.overridePendingTransition(
														android.R.anim.slide_in_left,
														android.R.anim.slide_out_right);
									}
								}).show();
				return;*/

				// initialize this for the next application
				currentIterationCount = 0;

				// If there are more apps that require processing then start
				// with those.
				if (selectedApps.size() != (currentReplayCount + 1)) {
					// (new StartNextApp()).execute(this);
					// processCombinedApplication(selectedApps.get(++currentReplayCount),
					// "vpn");
					currentReplayCount++;

					vpnDisconnected = new VPNDisconnected();
					vpnDisconnected.execute(this);
				} else {
					// progressWait.setMessage("Finishing Analysis...");
					// Thread.sleep(10000);
					// progressWait.dismiss();
					currentReplayCount = 0;
					Log.d("Replay", "finished all replays!");
					replayOngoing = false;

					// notify result channel thread
					resultChannelThread.doneReplay = true;
					// resultThread.join();

					ReplayActivity.this.runOnUiThread(new Runnable() {
						public void run() {
							new AlertDialog.Builder(ReplayActivity.this,
									AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
									.setTitle("Replay finished!")
									.setMessage(
											"Replay of all applications you have chosen is done! "
													+ "You might need to wait a few more seconds "
													+ "for all the results!\n\n"
													+ "Thank you and have a great day :-)")
									.setPositiveButton(
											"OK",
											new DialogInterface.OnClickListener() {

												@Override
												public void onClick(
														DialogInterface dialog,
														int which) {
													// do nothing
												}
											}).show();
						}

					});

				}

			} else {
				// Change screen status
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.finish_open);
				adapter.notifyDataSetChanged();

				// check if onlyRandom is true
				if (onlyRandom) {
					// updating progress
					selectedApps.get(currentReplayCount).status = getResources()
							.getString(R.string.random);
					adapter.notifyDataSetChanged();

					randomReplay = new RandomReplay();
					randomReplay.execute(this);
					return;
				}

				// Connect to VPN
				onVpnProfileSelected(null);
				Log.d("Replay", "VPN started");

				// Change screen status
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.vpn);
				adapter.notifyDataSetChanged();

				vpnConnected = new VPNConnected();
				vpnConnected.execute(this);
			}
		} catch (Exception ex) {
			ex.printStackTrace();
		}

	}

	@Override
	public void vpnConnectedCallBack() {
		Log.d("Replay", "Two replays finished");
	}

	/**
	 * From this point on, all the code related to VPN is taken from Meddle App.
	 */

	/**
	 * Wrote this to handle Pickle file Download from server. Should be used
	 * with FileDownload AsyncTask. FileDownload AsyncTask should call this
	 * callback which will start with Replay processing
	 */
	@Override
	public void fileExistsListener(Boolean success) {
		try {
			if (success) {
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.processing);
				adapter.notifyDataSetChanged();
				processCombinedApplication(
						selectedApps.get(currentReplayCount), "open");
			} else {
				// selectedApps.get(currentReplayCount).resultImg = "p";
				/*selectedApps.get(currentReplayCount++).status = getResources()
						.getString(R.string.error);
				adapter.notifyDataSetChanged();*/
				replayOngoing = false;

				// set progress bar to invisible
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						prgBar.setProgress(0);
						prgBar.setVisibility(View.GONE);
					}
				});
			}
		} catch (Exception e) {
			e.printStackTrace();
		}

	}

	@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if (keyCode == KeyEvent.KEYCODE_BACK) {
			if (!replayOngoing) {
				try {
					if (currentTask.equalsIgnoreCase("combined")
							&& queueCombined != null
							&& queueCombined.getStatus() == AsyncTask.Status.RUNNING)
						queueCombined.cancel(true);
				} catch (Exception e) {
					Log.d("ReplayActivity", "exception while press back key!");
					e.printStackTrace();
				}

				if (testVpn != null)
					testVpn.cancel(true);
				if (vpnConnected != null)
					vpnConnected.cancel(true);
				if (vpnDisconnected != null)
					vpnDisconnected.cancel(true);
				if (randomReplay != null)
					randomReplay.cancel(true);
				if (queueCombined != null)
					queueCombined.cancel(true);

				if (resultChannelThread != null)
					resultChannelThread.forceQuit = true;

				ReplayActivity.this.finish();
				ReplayActivity.this.overridePendingTransition(
						android.R.anim.slide_in_left,
						android.R.anim.slide_out_right);

				return super.onKeyDown(keyCode, event);
			} else {
				new AlertDialog.Builder(ReplayActivity.this,
						AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
						.setTitle("Replay is ongoing!")
						.setMessage("Do you want to stop the process?")
						.setPositiveButton("Yes",
								new DialogInterface.OnClickListener() {
									@Override
									public void onClick(DialogInterface dialog,
											int which) {
										if (testVpn != null)
											testVpn.cancel(true);
										if (vpnConnected != null)
											vpnConnected.cancel(true);
										if (vpnDisconnected != null)
											vpnDisconnected.cancel(true);
										if (randomReplay != null)
											randomReplay.cancel(true);
										if (queueCombined != null)
											queueCombined.cancel(true);

										disconnectVPN();
										if (resultChannelThread != null)
											resultChannelThread.forceQuit = true;
										ReplayActivity.this.finish();
										ReplayActivity.this
												.overridePendingTransition(
														android.R.anim.slide_in_left,
														android.R.anim.slide_out_right);
									}
								})
						.setNegativeButton("No",
								new DialogInterface.OnClickListener() {
									public void onClick(DialogInterface dialog,
											int which) {
										// do nothing
									}
								}).show();

				return true;
			}
		}

		return super.onKeyDown(keyCode, event);

	}

	// VPN Changes
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		getMenuInflater().inflate(R.menu.replay, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		// case R.id.log:
		// Intent logIntent = new Intent(this, LogActivity.class);
		// startActivity(logIntent);
		// return true;
			case android.R.id.home:
				if (!replayOngoing) {
					if (testVpn != null)
						testVpn.cancel(true);
					if (vpnConnected != null)
						vpnConnected.cancel(true);
					if (vpnDisconnected != null)
						vpnDisconnected.cancel(true);
					if (randomReplay != null)
						randomReplay.cancel(true);
					if (queueCombined != null)
						queueCombined.cancel(true);

					ReplayActivity.this.finish();
					ReplayActivity.this.overridePendingTransition(
							android.R.anim.slide_in_left,
							android.R.anim.slide_out_right);
				} else
					new AlertDialog.Builder(ReplayActivity.this,
							AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
							.setTitle("Replay is ongoing!")
							.setMessage("Do you want to stop the process?")
							.setPositiveButton("Yes",
									new DialogInterface.OnClickListener() {
										@Override
										public void onClick(
												DialogInterface dialog,
												int which) {
											if (testVpn != null)
												testVpn.cancel(true);
											if (vpnConnected != null)
												vpnConnected.cancel(true);
											if (vpnDisconnected != null)
												vpnDisconnected.cancel(true);
											if (randomReplay != null)
												randomReplay.cancel(true);
											if (queueCombined != null)
												queueCombined.cancel(true);

											disconnectVPN();
											if (resultChannelThread != null)
												resultChannelThread.forceQuit = true;
											ReplayActivity.this.finish();
											ReplayActivity.this
													.overridePendingTransition(
															android.R.anim.slide_in_left,
															android.R.anim.slide_out_right);
										}
									})
							.setNegativeButton("No",
									new DialogInterface.OnClickListener() {
										public void onClick(
												DialogInterface dialog,
												int which) {
											// do nothing
										}
									}).show();
				break;
			case R.id.start_replay:
				if (!networkAvailable) {
					Toast.makeText(
							context,
							"Network not available, please re-open this app after connecting to network.",
							Toast.LENGTH_LONG).show();
				} else if (!replayOngoing) {
					currentReplayCount = 0;
					processApplicationReplay();

				} else
					Toast.makeText(context,
							"Replay is ongoing! Please do not start again.",
							Toast.LENGTH_LONG).show();
				break;
			default:
				break;
		}

		return super.onOptionsItemSelected(item);

	}

	/**
	 * Class that loads or reloads the cached CA certificates.
	 */
	private class CertificateLoadTask extends
			AsyncTask<Boolean, Void, TrustedCertificateManager> {
		@Override
		protected void onPreExecute() {
			setProgressBarIndeterminateVisibility(true);
		}

		@Override
		protected TrustedCertificateManager doInBackground(Boolean... params) {
			Thread.currentThread().setName("CertificateLoadTask (AsyncTask)");
			if (params.length > 0 && params[0]) {
				/* force a reload of the certificates */
				return TrustedCertificateManager.getInstance().reload();
			}
			return TrustedCertificateManager.getInstance().load();
		}

		@Override
		protected void onPostExecute(TrustedCertificateManager result) {
			setProgressBarIndeterminateVisibility(false);
		}
	}

	/**
	 * Right now VPN profile is hardcoded in code
	 * 
	 * @param profile
	 */
	public void onVpnProfileSelected(VpnProfile profile) {
		Context context = this.getApplicationContext();
		VpnProfileDataSource mDataSource = new VpnProfileDataSource(context);
		mDataSource.open();
		profile = mDataSource.getAllVpnProfiles().get(0);

		// update gateway in the profile, using the current ip instead of url
		// this is not enabled because vpn security check won't allow this
		/*Log.w("onVpnProfileSelected", "old gateway: " + profile.getGateway());
		profile.setGateway("replay-s.meddle.mobi");
		Log.w("onVpnProfileSelected", "new gateway: " + profile.getGateway());
		mDataSource.updateVpnProfile(profile);*/

		Bundle profileInfo = new Bundle();
		profileInfo.putLong(VpnProfileDataSource.KEY_ID, profile.getId());
		prepareVpnService(profileInfo);

	}

	/**
	 * Prepare the VpnService. If this succeeds the current VPN profile is
	 * started.
	 * 
	 * @param profileInfo
	 *            a bundle containing the information about the profile to be
	 *            started
	 */
	protected void prepareVpnService(Bundle profileInfo) {
		Log.d("VPN", "Trying to start service --- 1");
		Intent intent = VpnService.prepare(this);

		/* store profile info until the user grants us permission */
		mProfileInfo = profileInfo;
		if (intent != null) {
			try {
				Log.d("VPN", "Trying to start service");
				startActivityForResult(intent, PREPARE_VPN_SERVICE);
			} catch (ActivityNotFoundException ex) {
				/*
				 * it seems some devices, even though they come with Android 4,
				 * don't have the VPN components built into the system image.
				 * com.android.vpndialogs/com.android.vpndialogs.ConfirmDialog
				 * will not be found then
				 */
				ex.printStackTrace();
				new VpnNotSupportedError().show(getFragmentManager(),
						"ErrorDialog");
			}
		} else { /* user already granted permission to use VpnService */
			onActivityResult(PREPARE_VPN_SERVICE, RESULT_OK, null);
		}
	}

	/**
	 * Trust permission menu
	 * 
	 * @modified by Sam Wilson
	 * @see android.app.Activity#onActivityResult(int, int,
	 *      android.content.Intent)
	 */
	@Override
	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		switch (requestCode) {
			case PREPARE_VPN_SERVICE:
				if (resultCode == RESULT_OK && mProfileInfo != null) {
					Context context = getApplicationContext();
					Intent intent = new Intent(context, CharonVpnService.class);
					intent.putExtras(mProfileInfo);
					intent.putExtra("action", "start");
					context.startService(intent);
				} else {
					// a alert dialog will pop up and the app will quite if user
					// click "Cancel" for trust permission
					AlertDialog.Builder alertDialog = new AlertDialog.Builder(
							this, AlertDialog.THEME_DEVICE_DEFAULT_LIGHT);
					alertDialog.setMessage(
							"Connecting VPN failed. Replay aborted.")
							.setNeutralButton("OK",
									new DialogInterface.OnClickListener() {

										@Override
										public void onClick(
												DialogInterface dialog,
												int which) {
											// exit this application
											if (resultChannelThread != null)
												resultChannelThread.forceQuit = true;
											ReplayActivity.this.finish();
										}
									});
					// show this dialog on the screen
					alertDialog.create().show();
				}
				break;
			default:
				super.onActivityResult(requestCode, resultCode, data);
		}
	}

	/**
	 * Class representing an error message which is displayed if VpnService is
	 * not supported on the current device.
	 */
	public static class VpnNotSupportedError extends DialogFragment {
		@Override
		public Dialog onCreateDialog(Bundle savedInstanceState) {
			return new AlertDialog.Builder(getActivity(),
					AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
					.setTitle("VPN Not supported")
					.setMessage(
							"Your device does not support VPN.\n"
									+ "Thank you for your time!\n\n"
									+ "Click below go back.")
					.setCancelable(false)
					.setPositiveButton(android.R.string.ok,
							new DialogInterface.OnClickListener() {
								@Override
								public void onClick(DialogInterface dialog,
										int id) {
									System.exit(0);
								}
							}).create();
		}
	}

	public void disconnectVPN() {
		/*
		 * as soon as the TUN device is created by calling establish() on the
		 * VpnService.Builder object the system binds to the service and keeps
		 * bound until the file descriptor of the TUN device is closed. thus
		 * calling stopService() here would not stop (destroy) the service yet,
		 * instead we call startService() with an empty Intent which shuts down
		 * the daemon (and closes the TUN device, if any)
		 */
		Context context = getApplicationContext();
		Intent intent = new Intent(context, CharonVpnService.class);
		intent.putExtra("action", "stop");
		context.startService(intent);
	}

	private String getPublicIP() {
		String publicIP = "127.0.0.1";

		if (server != null && server != "127.0.0.1") {
			String url = "http://" + server + "/WHATSMYIPMAN";
			Log.d("getPublicIP", "url: " + url);
			
			while (publicIP == "127.0.0.1") {
				try {
					HttpParams httpParameters = new BasicHttpParams();
					// Set the timeout in milliseconds until a connection is
					// established.
					// The default value is zero, that means the timeout is not
					// used.
					int timeoutConnection = 3000;
					HttpConnectionParams.setConnectionTimeout(httpParameters,
							timeoutConnection);
					// Set the default socket timeout (SO_TIMEOUT)
					// in milliseconds which is the timeout for waiting for
					// data.
					int timeoutSocket = 5000;
					HttpConnectionParams.setSoTimeout(httpParameters,
							timeoutSocket);

					HttpClient httpclient = new DefaultHttpClient(
							httpParameters);
					HttpGet httpget = new HttpGet(url);
					HttpResponse response;
					response = httpclient.execute(httpget);
					HttpEntity entity = response.getEntity();
					publicIP = EntityUtils.toString(entity).trim();

					if (publicIP.split("\\.").length != 4) {
						Log.e("getPublicIP", "wrong format of public IP: "
								+ publicIP);
						throw new Exception();
					} else
						Log.d("getPublicIP", "public IP: " + publicIP);

				} catch (Exception e) {
					Log.w("getPublicIP", "failed to get public IP!");
					e.printStackTrace();
					publicIP = "127.0.0.1";
					break;
				}
			}
		} else {
			Log.w("getPublicIP", "server ip is not available: " + server);
		}

		return publicIP;

	}

	class GetReplayServerAndMeddleIP extends AsyncTask<String, String, Boolean> {

		@Override
		protected Boolean doInBackground(String... params) {
			Thread.currentThread().setName(
					"GetReplayServerAndMeddleIP (AsyncTask)");
			// adrian: get IP from hostname
			try {
				server = InetAddress.getByName(
						(String) getIntent().getStringExtra("server"))
						.getHostAddress();
				String[] tmpServer = server.split("\\.");

				meddleIP = server;
				Log.d("GetReplayServerIP", "Server IP: " + server + " VPN IP: "
						+ meddleIP + " # fields: " + tmpServer.length);

				if (tmpServer.length != 4)
					throw new NullPointerException();

				// for testing exception handling
				// throw new UnknownHostException();
			} catch (UnknownHostException e) {
				Log.w("GetReplayServerIP", "get IP of replay server failed!");
				server = "127.0.0.1";
				meddleIP = "127.0.0.1";
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						Toast.makeText(
								ReplayActivity.this,
								"Failed to get IP address of replay server!. Try after some time.",
								Toast.LENGTH_LONG).show();
					}

				});
				if (resultChannelThread != null)
					resultChannelThread.forceQuit = true;
				ReplayActivity.this.finish();
			} catch (NullPointerException e) {
				Log.w("GetReplayServerIP", "not ipv4 address!");
				server = "172.0.0.1";
				meddleIP = "172.0.0.1";

				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						new AlertDialog.Builder(ReplayActivity.this,
								AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
								.setTitle("Error")
								.setMessage(
										"Sorry, your phone is using IPv6 address."
												+ "Currently not supported!\n\n"
												+ "Thank you!")
								.setPositiveButton("OK",
										new DialogInterface.OnClickListener() {
											@Override
											public void onClick(
													DialogInterface dialog,
													int which) {
												try {
													disconnectVPN();
													if (resultChannelThread != null)
														resultChannelThread.forceQuit = true;
													ReplayActivity.this
															.finish();
												} catch (Exception e) {
													// TODO Auto-generated catch
													// block
													e.printStackTrace();
												}
											}
										}).show();
					}
				});

			}
			return false;
		}

	}

	/**
	 * Check if VPN is connected and start the new replay. If not, display a
	 * message and fall back to random replay
	 * 
	 * @author Adrian
	 * 
	 */
	class VPNConnected extends AsyncTask<ReplayActivity, Void, Boolean> {

		@Override
		protected Boolean doInBackground(ReplayActivity... params) {
			Thread.currentThread().setName("VPNConnected (AsyncTask)");
			int i = 0;

			while (i < 10) {
				i++;
				try {

					// Log.d("VPNConnected", "about to get public IP");
					// String str = getPublicIP();
					// if (str.equalsIgnoreCase(meddleIP)) {
					if (CharonVpnService.getInstance() != null
							&& CharonVpnService.getInstance()
									.isFullyConnected()) {
						Log.d("VPNConnected", "Got it!");
						// Set flag indicating VPN connectivity status
						isVPNConnected = true;
						// set server ip to local ip
						server = Config.get("vpn_replay_ip");

						// Start the replay again for same app
						// adrian: start the combined thread
						if (currentTask.equalsIgnoreCase("combined")) {
							queueCombined.cancel(true);
							queueCombined = new QueueCombinedAsync(params[0],
									selectedApps.get(currentReplayCount), "vpn");
							Log.d("VPNConnected", "Starting combined replay");
							queueCombined.execute("");
						} else {
							Log.d("VPNConnected", "unknown replay type!");
							return false;
						}

						return true;
					}
					Thread.sleep(3000);
					Log.d("VPNConnected", "Not yet!");
				} catch (Exception e) {
					Log.d("VPNConnected", "failed to get VPN IP address");
					e.printStackTrace();
				}
			}

			ReplayActivity.this.runOnUiThread(new Runnable() {
				public void run() {
					Toast.makeText(
							ReplayActivity.this,
							"Cannot connect to VPN, fall back to random replay. "
									+ "If your are using Android 5.0, please try to reboot "
									+ "your phone later.", Toast.LENGTH_LONG)
							.show();
				}
			});

			randomReplay = new RandomReplay();
			randomReplay.execute(ReplayActivity.this);
			onlyRandom = true;

			return false;

		}

	}

	/**
	 * Startt this task first to test if vpn is working
	 * 
	 * @author Adrian
	 * 
	 */
	class TestVPN extends AsyncTask<ReplayActivity, Void, Boolean> {

		@Override
		protected Boolean doInBackground(ReplayActivity... params) {
			Thread.currentThread().setName("TestVPN (AsyncTask)");
			int i = 0;
			while (i < 5) {
				i++;
				try {
					Log.d("TestVPN", "about to get public IP");
					// String str = getPublicIP();
					// if (str.equalsIgnoreCase(meddleIP)) {
					if (CharonVpnService.getInstance() != null
							&& CharonVpnService.getInstance()
									.isFullyConnected()) {
						Log.d("TestVPN", "Got it!");
						isVPNConnected = true;
						// disconnect vpn and return
						disconnectVPN();

						try {
							processCombinedApplication(
									selectedApps.get(currentReplayCount),
									"open");
						} catch (Exception e) {
							// TODO Auto-generated catch
							// block
							e.printStackTrace();
						}

						return true;
					}
					Thread.sleep(3000);
					Log.d("TestVPN", "Not yet! ");
				} catch (Exception e) {
					Log.d("TestVPN", "failed to get VPN IP address");
					e.printStackTrace();
				}
			}

			onlyRandom = true;

			ReplayActivity.this.runOnUiThread(new Runnable() {
				public void run() {
					new AlertDialog.Builder(ReplayActivity.this,
							AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
							.setTitle("VPN Connection Test")
							.setMessage(
									"We detected that your device is unable to connect to "
											+ "the VPN we use for testing differentiation. "
											+ "If you are using Android "
											+ "5.0.x, and this is the first time you run "
											+ "this app, please try rebooting your phone.\n\n"
											+ "Click \"Ignore\" and try our alternative (less "
											+ "reliable) detection approach or click \"Go back\".")
							.setPositiveButton("Ignore",
									new DialogInterface.OnClickListener() {
										@Override
										public void onClick(
												DialogInterface dialog,
												int which) {
											try {
												disconnectVPN();
												processCombinedApplication(
														selectedApps
																.get(currentReplayCount),
														"open");
											} catch (Exception e) {
												// TODO Auto-generated catch
												// block
												e.printStackTrace();
											}
										}
									})
							.setNegativeButton("Go back",
									new DialogInterface.OnClickListener() {
										@Override
										public void onClick(
												DialogInterface dialog,
												int which) {
											ReplayActivity.this.finish();
										}
									}).show();
				}
			});

			return false;

		}

	}

	class VPNDisconnected extends AsyncTask<ReplayActivity, Void, Boolean> {

		@Override
		protected Boolean doInBackground(ReplayActivity... params) {
			Thread.currentThread().setName("VPNDisconnected (AsyncTask)");
			// String publicIP = Config.get("publicIP");
			int i = 0;
			try {
				Thread.sleep(5000);
			} catch (InterruptedException e1) {
				Log.d("DisconnectVPN", "sleep failed!");
			}

			while (i < 5) {
				try {
					i++;
					// String str = getPublicIP();
					// if (str.equalsIgnoreCase(publicIP)) {
					if (CharonVpnService.getInstance() != null
							&& !CharonVpnService.getInstance()
									.isFullyConnected()) {
						Log.d("DisconnectVPN", "Got it!");
						// Set flag indicating VPN connectivity status
						isVPNConnected = false;

						// Start the replay for the next app
						// adrian: start the combined thread
						if (currentReplayCount < selectedApps.size()) {
							// do nothing
						}
						if (currentTask.equalsIgnoreCase("combined")) {
							appData_combined = UnpickleDataStream
									.unpickleCombinedJSON(
											selectedApps
													.get(currentReplayCount)
													.getDataFile(), context);
							Log.d("DisconnectVPN", "loaded json!");
							if (queueCombined != null)
								queueCombined.cancel(true);
							queueCombined = new QueueCombinedAsync(params[0],
									selectedApps.get(currentReplayCount),
									"open");
							Log.d("DisconnectVPN", "Starting combined replay");
							queueCombined.execute("");
						} else {
							Log.d("DisconnectVPN", "unknown replay type!");
							return false;
						}

						return true;

					}
					Log.d("DisconnectVPN", "done");
				} catch (Exception e) {
					Log.d("DisconnectVPN", "failed to get VPN IP address");
					e.printStackTrace();
				}

				try {
					Thread.sleep(3000);
				} catch (InterruptedException e) {
					Log.d("DisconnectVPN", "sleep interrupted!");
				}
			}

			// show a dialogue to inform user
			ReplayActivity.this.runOnUiThread(new Runnable() {
				public void run() {
					new AlertDialog.Builder(ReplayActivity.this,
							AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
							.setTitle("Error")
							.setMessage(
									"Failed to disconnect VPN!\n"
											+ "Click \"OK\" to go back.")
							.setPositiveButton("OK",
									new DialogInterface.OnClickListener() {
										@Override
										public void onClick(
												DialogInterface dialog,
												int which) {
											queueCombined.cancel(true);
											disconnectVPN();
											if (resultChannelThread != null)
												resultChannelThread.forceQuit = true;
											ReplayActivity.this.finish();
										}
									}).show();
				}

			});

			return false;

		}

	}

	class RandomReplay extends AsyncTask<ReplayActivity, Void, Boolean> {

		@Override
		protected Boolean doInBackground(ReplayActivity... params) {
			Thread.currentThread().setName("RandomReplay (AsyncTask)");
			String server = Config.get("server");
			int i = 0;
			try {
				Thread.sleep(5000);
			} catch (InterruptedException e1) {
				Log.d("DisconnectVPN", "sleep failed!");
			}

			while (i < 5) {
				try {
					i++;
					// String str = getPublicIP();
					// if (!str.equalsIgnoreCase(server)) {
					if (CharonVpnService.getInstance() != null
							&& !CharonVpnService.getInstance()
									.isFullyConnected()) {
						Log.d("randomReplay", "Got it!");
						// Set flag indicating VPN connectivity status
						isVPNConnected = false;

						// Start the replay for the next app
						// adrian: start the combined thread
						if (currentTask.equalsIgnoreCase("combined")) {
							appData_combined = UnpickleDataStream
									.unpickleCombinedJSON(selectedAppsRandom
											.get(currentReplayCount)
											.getDataFile(), context);
							Log.d("randomReplay", "loaded json!");
							queueCombined.cancel(true);
							queueCombined = new QueueCombinedAsync(params[0],
									selectedApps.get(currentReplayCount),
									"random");
							Log.d("randomReplay", "Starting random replay");
							queueCombined.execute("");
						} else {
							Log.d("randomReplay", "unknown replay type!");
							return false;
						}

						return true;

					}
					// Log.d("randomReplay", "public IP: " + str);
				} catch (Exception e) {
					Log.d("randomReplay", "failed to get VPN IP address");
					e.printStackTrace();
				}

				try {
					Thread.sleep(3000);
				} catch (InterruptedException e) {
					Log.d("randomReplay", "sleep failed!");
				}
			}

			// show a dialogue to inform user
			ReplayActivity.this.runOnUiThread(new Runnable() {
				public void run() {
					new AlertDialog.Builder(ReplayActivity.this,
							AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
							.setTitle("Error")
							.setMessage(
									"Failed to disconnect VPN!\n"
											+ "Click \"OK\" to go back.")
							.setPositiveButton("OK",
									new DialogInterface.OnClickListener() {
										@Override
										public void onClick(
												DialogInterface dialog,
												int which) {
											queueCombined.cancel(true);
											disconnectVPN();
											if (resultChannelThread != null)
												resultChannelThread.forceQuit = true;
											ReplayActivity.this.finish();
										}
									}).show();
				}

			});

			return false;

		}

	}
}
