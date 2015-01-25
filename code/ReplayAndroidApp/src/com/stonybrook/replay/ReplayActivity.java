package com.stonybrook.replay;

import java.net.ConnectException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.HashMap;

import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.json.JSONException;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.DialogFragment;
import android.app.ProgressDialog;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.VpnService;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import com.stonybrook.android.data.VpnProfile;
import com.stonybrook.android.data.VpnProfileDataSource;
import com.stonybrook.android.logic.CharonVpnService;
import com.stonybrook.android.logic.TrustedCertificateManager;
import com.stonybrook.android.ui.LogActivity;
import com.stonybrook.replay.adapter.ImageReplayListAdapter;
import com.stonybrook.replay.bean.ApplicationBean;
import com.stonybrook.replay.bean.JitterBean;
import com.stonybrook.replay.bean.ServerInstance;
import com.stonybrook.replay.bean.SocketInstance;
import com.stonybrook.replay.bean.UDPReplayInfoBean;
import com.stonybrook.replay.bean.UpdateUIBean;
import com.stonybrook.replay.bean.combinedAppJSONInfoBean;
import com.stonybrook.replay.combined.CTCPClient;
import com.stonybrook.replay.combined.CUDPClient;
import com.stonybrook.replay.combined.CombinedNotifierThread;
import com.stonybrook.replay.combined.CombinedQueue;
import com.stonybrook.replay.combined.CombinedReceiverThread;
import com.stonybrook.replay.combined.CombinedSideChannel;
import com.stonybrook.replay.exception_handler.ExceptionHandler;
import com.stonybrook.replay.util.Config;
import com.stonybrook.replay.util.Mobilyzer;
import com.stonybrook.replay.util.RandomString;
import com.stonybrook.replay.util.ReplayCompleteListener;
import com.stonybrook.replay.util.UnpickleDataStream;

public class ReplayActivity extends Activity implements ReplayCompleteListener {

	Button backButton, replayButton;
	ArrayList<ApplicationBean> selectedApps = null;
	ListView appsListView = null;
	TextView selectedAppsMsgTextView = null;
	TextView selectedAppsSizeTextView = null;
	Context context = null;
	ProgressDialog progress = null;

	boolean replayOngoing = false;

	// adrian: for progress bar
	ProgressBar prgBar;
	UpdateUIBean updateUIBean;

	int currentReplayCount = 0;
	int currentIterationCount = 0;
	ProgressBar progressBar = null;
	ImageReplayListAdapter adapter = null;

	String server = null;
	String enableTiming = null;
	int iteration = 1;
	boolean doRandom = false;

	String GATE_WAY = Config.get("vpn_server");
	String meddleIP = null;

	// This is AsyncTasks for replay. Run in background.
	QueueCombinedAsync queueCombined = null;
	String currentTask = "none";

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

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		this.requestWindowFeature(Window.FEATURE_NO_TITLE);
		Thread.setDefaultUncaughtExceptionHandler(new ExceptionHandler(this));
		setContentView(R.layout.replay_main_layout_images);
		// keep the screen on
		getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

		// First check to see of Internet access is available
		if (!isNetworkAvailable()) {
			new AlertDialog.Builder(this)
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
		}

		// Extract data that was sent by previous activity. In our case, list of
		// apps, server and timing
		context = getApplicationContext();
		selectedApps = getIntent().getParcelableArrayListExtra("selectedApps");

		(new GetReplayServerAndMeddleIP()).execute("");

		enableTiming = (String) getIntent().getStringExtra("timing");
		iteration = (int) getIntent().getIntExtra("iteration", 1);
		doRandom = getIntent().getBooleanExtra("doRandom", false);
		Log.d("ReplayActivity", "iteration: " + String.valueOf(iteration)
				+ " doRandom: " + doRandom);

		// Create layout for this page
		adapter = new ImageReplayListAdapter(selectedApps, getLayoutInflater(),
				this);

		appsListView = (ListView) findViewById(R.id.appsListView);
		appsListView.setAdapter(adapter);

		// Register button listeners
		backButton = (Button) findViewById(R.id.backButton);
		backButton.setOnClickListener(backButtonListner);

		replayButton = (Button) findViewById(R.id.replayButton);
		replayButton.setOnClickListener(replayButtonListener);
		currentReplayCount = 0;

		updateSelectedTextViews(selectedApps);

		// adrian: for progress bar
		prgBar = (ProgressBar) findViewById(R.id.prgBar);
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

		Toast.makeText(context, "Please click \"Start\" to start the replay!",
				Toast.LENGTH_LONG).show();

	}

	@Override
	protected void onStop() {
		// TODO Auto-generated method stub
		super.onStop();
		if (queueCombined != null) {
			queueCombined.cancel(true);
			if (queueCombined.channel.equalsIgnoreCase("vpn"))
				disconnectVPN();
		}
		this.finish();
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
	 * This method is entry point for any application replay Here, first server
	 * reachability is checked and according to type of app (TCP or UDP) request
	 * is forwarded to methos
	 */
	void processApplicationReplay() {

		// update progress
		selectedApps.get(currentReplayCount).status = getResources().getString(
				R.string.start_replay);
		adapter.notifyDataSetChanged();

		replayOngoing = true;

		try {
			/**
			 * Read configuration file and long it into Config object.
			 * Configuration file is located in assets/configuration.properties.
			 */
			// Config.readConfigFile(ReplayConstants.CONFIG_FILE, context);

			Config.set("timing", enableTiming);

			// make sure server is initialized!
			while (server == null) {
				Thread.sleep(1000);
			}
			Config.set("server", server);

			// adrian: added cause arash's code
			Config.set("extraString", "MoblieApp");
			Config.set("jitter", "true");
			Config.set("sendMobileStats", "true");
			// adrian: set result
			Config.set("result", "false");
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

			Log.d("Replay", "public IP: " + Config.get("publicIP"));
			// Check server reachability
			boolean isAvailable = (new ServerReachable()).execute(server).get();
			Log.d("Replay",
					"Server availability " + String.valueOf(isAvailable));

			if (isAvailable) {
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

				// adrian: start combined method
				processCombinedApplication(
						selectedApps.get(currentReplayCount), "open");
			} else {
				Toast.makeText(ReplayActivity.this,
						"Server Not Available. Try after some time.",
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

		appData_combined = UnpickleDataStream.unpickleCombinedJSON(
				applicationBean.getDataFile(), context);
		Log.d("Parsing", applicationBean.getDataFile());
		queueCombined = new QueueCombinedAsync(this, applicationBean, env);

		queueCombined.execute("");

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
				+ " applications selected.");
		double totalSize = 0.0;

		for (int i = 0; i < list.size(); i++)
			totalSize += list.get(i).getSize();

		DecimalFormat df = new DecimalFormat("#.##");
		selectedAppsSizeTextView.setText(df.format(totalSize).toString()
				+ " MB");

	}

	/**
	 * This is method is called when user presses the back button. This will
	 * take then back to main screen.
	 */
	OnClickListener backButtonListner = new OnClickListener() {

		@Override
		public void onClick(View v) {
			if (!replayOngoing) {
				ReplayActivity.this.finish();
				ReplayActivity.this.overridePendingTransition(
						android.R.anim.slide_in_left,
						android.R.anim.slide_out_right);
			} else
				new AlertDialog.Builder(ReplayActivity.this)
						.setTitle("Replay is ongoing!")
						.setMessage("Do you want to stop the process?")
						.setPositiveButton("Yes",
								new DialogInterface.OnClickListener() {
									@Override
									public void onClick(DialogInterface dialog,
											int which) {
										queueCombined.cancel(true);
										disconnectVPN();
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
		}
	};

	/**
	 * This method is called when user clicks on Replay Button.
	 */
	OnClickListener replayButtonListener = new OnClickListener() {

		@Override
		public void onClick(View v) {
			if (!replayOngoing) {
				currentReplayCount = 0;
				processApplicationReplay();
			} else
				Toast.makeText(context,
						"Replay is ongoing! Please do not start again.",
						Toast.LENGTH_LONG).show();
		}
	};

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
			else
				listener.vpnFinishCompleteCallback(success);

		}

		protected void onProgressUpdate(String... a) {
			Log.d("Replay", "You are in progress update ... " + a[0]);
		}

		@Override
		protected String doInBackground(String... str) {

			if (channel.equalsIgnoreCase("open") && currentIterationCount == 0) {
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						Toast.makeText(ReplayActivity.this,
								"First iteration of current replay!",
								Toast.LENGTH_LONG).show();
					}
				});
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
				applicationBean.status = getResources().getString(
						R.string.create_side_channel);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

				int sideChannelPort = Integer.valueOf(Config
						.get("combined_sidechannel_port"));
				String randomID = new RandomString(10).nextString();
				SocketInstance socketInstance = new SocketInstance(
						Config.get("server"), sideChannelPort, null);
				Log.d("Server", Config.get("server"));

				CombinedSideChannel sideChannel = new CombinedSideChannel(
						socketInstance, randomID);
				// adrian: new format of serverPortsMap
				HashMap<String, HashMap<String, HashMap<String, ServerInstance>>> serverPortsMap = null;
				UDPReplayInfoBean udpReplayInfoBean = new UDPReplayInfoBean();

				// adrian: for jitter
				JitterBean jitterBean = new JitterBean();

				// adrian: new declareID() function
				sideChannel.declareID(appData.getReplayName(),
						Config.get("extraString"));

				// adrian: update progress
				applicationBean.status = getResources().getString(
						R.string.ask4permission);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

				String[] permission = sideChannel.ask4Permission();
				Log.d("Replay", "permission[0]: " + permission[0]
						+ " permission[1]: " + permission[1]);
				if (permission[0].trim().equalsIgnoreCase("0")) {
					if (permission[1].trim().equalsIgnoreCase("1")) {
						ReplayActivity.this.runOnUiThread(new Runnable() {
							public void run() {
								new AlertDialog.Builder(ReplayActivity.this)
										.setTitle("Error")
										.setMessage(
												"No such replay on server!\n"
														+ "Click \"OK\" to go back.")
										.setPositiveButton(
												"OK",
												new DialogInterface.OnClickListener() {
													@Override
													public void onClick(
															DialogInterface dialog,
															int which) {
														queueCombined
																.cancel(true);
														disconnectVPN();
														ReplayActivity.this
																.finish();
													}
												}).show();
							}

						});
						Thread.sleep(30000);
						throw new Exception();
					} else if (permission[1].trim().equalsIgnoreCase("2")) {
						ReplayActivity.this.runOnUiThread(new Runnable() {
							public void run() {
								new AlertDialog.Builder(ReplayActivity.this)
										.setTitle("Error")
										.setMessage(
												"No permission: another client with same IP address is running. "
														+ "Wait for it to finish!\n"
														+ "Click \"OK\" to go back.")
										.setPositiveButton(
												"OK",
												new DialogInterface.OnClickListener() {
													@Override
													public void onClick(
															DialogInterface dialog,
															int which) {
														queueCombined
																.cancel(true);
														disconnectVPN();
														ReplayActivity.this
																.finish();
													}
												}).show();
							}

						});
						Thread.sleep(30000);
						throw new Exception();
					} else {
						ReplayActivity.this.runOnUiThread(new Runnable() {
							public void run() {
								new AlertDialog.Builder(ReplayActivity.this)
										.setTitle("Error")
										.setMessage(
												"Unknown error!\n"
														+ "Click \"OK\" to go back.")
										.setPositiveButton(
												"OK",
												new DialogInterface.OnClickListener() {
													@Override
													public void onClick(
															DialogInterface dialog,
															int which) {
														queueCombined
																.cancel(true);
														disconnectVPN();
														ReplayActivity.this
																.finish();
													}
												}).show();
							}
						});
						Thread.sleep(30000);
						throw new Exception();
					}
				} else {
					Log.d("Replay", "Permission granted.");
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
				applicationBean.status = getResources().getString(
						R.string.receive_server_port_mapping);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

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
				applicationBean.status = getResources().getString(
						R.string.create_tcp_client);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

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
							appData.getReplayName());
					CSPairMapping.put(csp, c);
				}
				Log.d("Replay", "created clients from CSPairs");

				/**
				 * adrian: create clients from udpClientPorts
				 */

				// adrian: update progress
				applicationBean.status = getResources().getString(
						R.string.create_udp_client);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

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
				applicationBean.status = getResources().getString(
						R.string.run_notf);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

				CombinedNotifierThread notifier = sideChannel
						.notifierCreater(udpReplayInfoBean);
				Thread notfThread = new Thread(notifier);
				notfThread.start();
				threadList.add(notfThread);

				// adrian: starting receiver thread

				// adrian: update progress
				applicationBean.status = getResources().getString(
						R.string.run_receiver);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

				CombinedReceiverThread receiver = new CombinedReceiverThread(
						udpReplayInfoBean, jitterBean);
				Thread rThread = new Thread(receiver);
				rThread.start();
				threadList.add(rThread);

				// adrian: starting UI updating thread
				Thread UIUpdateThread = new Thread(new Runnable() {
					@Override
					public void run() {

						while (updateUIBean.getProgress() < 100) {
							ReplayActivity.this.runOnUiThread(new Runnable() {
								@Override
								public void run() {
									// set progress bar to visible
									if (prgBar.getVisibility() == View.GONE)
										prgBar.setVisibility(View.VISIBLE);
									prgBar.setProgress(updateUIBean
											.getProgress());
								}
							});
							try {
								Thread.sleep(500);
							} catch (InterruptedException e) {
								Log.d("UpdateUI", "try to sleep failed!");
								e.printStackTrace();
							}
						}

						// make progress bar to be 100%
						ReplayActivity.this.runOnUiThread(new Runnable() {
							@Override
							public void run() {
								// set progress bar to visible
								if (prgBar.getVisibility() == View.GONE)
									prgBar.setVisibility(View.VISIBLE);
								prgBar.setProgress(100);
							}
						});

						Log.d("UpdateUI", "completed!");
					}
				});

				UIUpdateThread.start();
				threadList.add(UIUpdateThread);

				// Running the Queue (Sender)

				// adrian: update progress
				applicationBean.status = getResources().getString(
						R.string.run_sender);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

				CombinedQueue queue = new CombinedQueue(appData.getQ(),
						jitterBean);
				this.timeStarted = System.nanoTime();
				queue.run(updateUIBean, CSPairMapping, udpPortMapping,
						udpReplayInfoBean, serverPortsMap.get("udp"),
						Boolean.valueOf(Config.get("timing")), server);

				// if sender aborted, throw exception here
				if (queue.ABORT == true) {
					Log.d("Replay", "replay aborted! Throw exception!");
					throw new Exception();
				}

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
				applicationBean.status = getResources().getString(
						R.string.send_done);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

				sideChannel.sendDone(duration);
				Log.d("Replay", "replay finished using time " + duration + " s");

				// Sending jitter

				// adrian: update progress
				applicationBean.status = getResources().getString(
						R.string.send_jitter);
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						adapter.notifyDataSetChanged();
					}
				});

				sideChannel.sendJitter(randomID, Config.get("jitter"),
						jitterBean);

				// Getting result
				sideChannel.getResult(Config.get("result"));

				// closing side channel socket
				sideChannel.closeSideChannelSocket();

				// set progress bar to invisible
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						prgBar.setVisibility(View.GONE);
						prgBar.setProgress(0);
					}
				});

			} catch (ConnectException ce) {
				Log.d("Replay", "Server unavailable!");
				ce.printStackTrace();
				success = false;
				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						Toast.makeText(
								context,
								"Sorry, our server is currently not running. "
										+ "Please try another time.",
								Toast.LENGTH_LONG).show();
					}
				});
			} catch (JSONException ex) {
				Log.d("Replay", "Error parsing JSON");
				ex.printStackTrace();
			} catch (Exception ex) {
				success = false;
				Log.d("Replay", "bad things happened, quiting process");
				ex.printStackTrace();
			}
			Log.d("Replay", "queueCombined finished execution!");
			return null;
		}
	}

	// here i kept the old version, (all on open)->(all over vpn)
	/*@Override
	public void vpnFinishCompleteCallback(Boolean success) {
		try {
			// If there was error. Display message and stop processing further.
			if (!success) {
				Toast.makeText(context, "Error while processing...",
						Toast.LENGTH_LONG).show();
				return;
			}

	selectedApps.get(currentReplayCount).resultImg = "p";
	selectedApps.get(currentReplayCount).status = getResources()
		.getString(R.string.finish_vpn);
	adapter.notifyDataSetChanged();

	if (selectedApps.size() != (currentReplayCount + 1)) {
	appData_combined = UnpickleDataStream.unpickleCombinedJSON(
			selectedApps.get(++currentReplayCount).getDataFile(),
			context);
	queueCombined.cancel(true);
	queueCombined = new QueueCombinedAsync(this,
			selectedApps.get(currentReplayCount), "vpn");
	Log.d("Replay", "Starting combined replay");
	queueCombined.execute("");
	} else {
	Log.d("Replay", "finished all replays!");
	disconnectVPN();
	}

	} catch (Exception ex) {
	ex.printStackTrace();
	} finally {
	}

	}*/

	/**
	 * This method is called when replay over VPN is finished
	 */
	@Override
	public void vpnFinishCompleteCallback(Boolean success) {
		try {
			// If there was error. Display message and stop processing further.
			if (!success) {
				// Update status on screen and stop processing
				selectedApps.get(currentReplayCount).resultImg = "p";
				selectedApps.get(currentReplayCount++).status = getResources()
						.getString(R.string.error);
				adapter.notifyDataSetChanged();

				replayOngoing = false;

				new AlertDialog.Builder(ReplayActivity.this)
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
										queueCombined.cancel(true);
										disconnectVPN();
										ReplayActivity.this.finish();
										ReplayActivity.this
												.overridePendingTransition(
														android.R.anim.slide_in_left,
														android.R.anim.slide_out_right);
									}
								}).show();

				return;
			}

			// updating progress
			selectedApps.get(currentReplayCount).status = getResources()
					.getString(R.string.disconnect_vpn);
			adapter.notifyDataSetChanged();

			disconnectVPN();
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

				(new VPNDisconnected()).execute(this);
				return;
			}

			/**
			 * Change status on screen. Here currentReplayCount stores number of
			 * applications selected by user. ++ makes processing of next
			 * application in list when processApplicationReplay() is called.
			 */

			selectedApps.get(currentReplayCount).resultImg = "p";
			selectedApps.get(currentReplayCount).status = getResources()
					.getString(R.string.finish_vpn);
			adapter.notifyDataSetChanged();

			// initialize this for the next application
			currentIterationCount = 0;

			// If there are more apps that require processing then start with
			// those.
			if (selectedApps.size() != (currentReplayCount + 1)) {
				// (new StartNextApp()).execute(this);
				// processCombinedApplication(selectedApps.get(++currentReplayCount),
				// "vpn");
				currentReplayCount++;
				(new VPNDisconnected()).execute(this);
			} else {
				// progressWait.setMessage("Finishing Analysis...");
				// Thread.sleep(10000);
				// progressWait.dismiss();
				currentReplayCount = 0;
				Log.d("Replay", "finished all replays!");
				replayOngoing = false;

				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						new AlertDialog.Builder(ReplayActivity.this)
								.setTitle("Replay finished!")
								.setMessage(
										"Replay of all applications you have chosen is done!\n"
												+ "We truly appreciate your support and contribution "
												+ "to this research!\n\n"
												+ "Thank you and have a nice day :-)")
								.setPositiveButton("Go back",
										new DialogInterface.OnClickListener() {

											@Override
											public void onClick(
													DialogInterface dialog,
													int which) {
												ReplayActivity.this.finish();
												ReplayActivity.this
														.overridePendingTransition(
																android.R.anim.slide_in_left,
																android.R.anim.slide_out_right);
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

	// here i kept the old version, (all on open)->(all over vpn)
	/*@Override
	public void openFinishCompleteCallback(Boolean success) {
		try {
			// If Replay on Open was successful then schedule on VPN
			if (success) {
				// Change screen status
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.finish_open);
				adapter.notifyDataSetChanged();

				if (selectedApps.size() != (currentReplayCount + 1)) {
					appData_combined = UnpickleDataStream.unpickleCombinedJSON(
							selectedApps.get(++currentReplayCount)
									.getDataFile(), context);
					queueCombined.cancel(true);
					queueCombined = new QueueCombinedAsync(this,
							selectedApps.get(currentReplayCount), "open");
					Log.d("Replay", "Starting combined replay");
					queueCombined.execute("");
				} else {
					currentReplayCount = 0;
					// Connect to VPN
					onVpnProfileSelected(null);
					Log.d("Replay", "VPN started");

					// Change screen status
					selectedApps.get(currentReplayCount).status = getResources()
							.getString(R.string.vpn);
					adapter.notifyDataSetChanged();

					appData_combined = UnpickleDataStream.unpickleCombinedJSON(
							selectedApps.get(currentReplayCount).getDataFile(),
							context);
					(new VPNConnected()).execute(this);
				}

			} else {
				selectedApps.get(currentReplayCount).resultImg = "p";
				selectedApps.get(currentReplayCount++).status = getResources()
						.getString(R.string.error);
				adapter.notifyDataSetChanged();
			}
		} catch (Exception ex) {
			ex.printStackTrace();
		}

	}*/

	/**
	 * Called when Replay is finished over Open channel. Connects to VPN and
	 * starts replay for same App again
	 */
	@Override
	public void openFinishCompleteCallback(Boolean success) {
		try {
			// If Replay on Open was successful then schedule on VPN
			if (success) {
				// Change screen status
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.finish_open);
				adapter.notifyDataSetChanged();

				// Connect to VPN
				onVpnProfileSelected(null);
				Log.d("Replay", "VPN started");

				// Change screen status
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.vpn);
				adapter.notifyDataSetChanged();

				(new VPNConnected()).execute(this);

			} else {
				// Update status on screen and stop processing
				selectedApps.get(currentReplayCount).resultImg = "p";
				selectedApps.get(currentReplayCount++).status = getResources()
						.getString(R.string.error);
				adapter.notifyDataSetChanged();
				replayOngoing = false;

				new AlertDialog.Builder(ReplayActivity.this)
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
										queueCombined.cancel(true);
										disconnectVPN();
										ReplayActivity.this.finish();
										ReplayActivity.this
												.overridePendingTransition(
														android.R.anim.slide_in_left,
														android.R.anim.slide_out_right);
									}
								}).show();
				return;
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
				selectedApps.get(currentReplayCount).resultImg = "p";
				selectedApps.get(currentReplayCount++).status = getResources()
						.getString(R.string.error);
				adapter.notifyDataSetChanged();
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
					else {
						Log.d("fileExistsListener", "unknown replay type!");
					}
				} catch (Exception e) {
					Log.d("ReplayActivity", "exception while press back key!");
					e.printStackTrace();
				}

				ReplayActivity.this.finish();
				ReplayActivity.this.overridePendingTransition(
						android.R.anim.slide_in_left,
						android.R.anim.slide_out_right);

				return super.onKeyDown(keyCode, event);
			} else {
				new AlertDialog.Builder(ReplayActivity.this)
						.setTitle("Replay is ongoing!")
						.setMessage("Do you want to stop the process?")
						.setPositiveButton("Yes",
								new DialogInterface.OnClickListener() {
									@Override
									public void onClick(DialogInterface dialog,
											int which) {
										queueCombined.cancel(true);
										disconnectVPN();
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
		case R.id.log:
			Intent logIntent = new Intent(this, LogActivity.class);
			startActivity(logIntent);
			return true;
		default:
			return super.onOptionsItemSelected(item);
		}
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
				AlertDialog.Builder alertDialog = new AlertDialog.Builder(this);
				alertDialog
						.setMessage("Connecting VPN failed. Replay aborted.")
						.setNeutralButton("OK",
								new DialogInterface.OnClickListener() {

									@Override
									public void onClick(DialogInterface dialog,
											int which) {
										// exit this application
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
			return new AlertDialog.Builder(getActivity())
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
		String publicIP = null;
		while (publicIP == null) {
			try {
				HttpClient httpclient = new DefaultHttpClient();
				HttpGet httpget = new HttpGet("http://myexternalip.com/raw");
				HttpResponse response;
				response = httpclient.execute(httpget);
				HttpEntity entity = response.getEntity();
				publicIP = EntityUtils.toString(entity).trim();
			} catch (Exception e) {
				Log.w("getPublicIP", "failed to get public IP!");
				e.printStackTrace();
			}
		}

		return publicIP;

	}

	class GetReplayServerAndMeddleIP extends AsyncTask<String, String, Boolean> {

		@Override
		protected Boolean doInBackground(String... params) {
			// adrian: get IP from hostname
			try {
				server = InetAddress.getByName(
						(String) getIntent().getStringExtra("server"))
						.getHostAddress();
				meddleIP = InetAddress.getByName(GATE_WAY).getHostAddress();
				Log.d("GetReplayServerIP", "Server IP: " + server + " VPN IP: "
						+ meddleIP);
				// for testing exception handling
				// throw new UnknownHostException();
			} catch (UnknownHostException e) {
				Log.w("GetReplayServerIP", "get IP of replay server failed!");

				ReplayActivity.this.runOnUiThread(new Runnable() {
					public void run() {
						Toast.makeText(
								ReplayActivity.this,
								"Failed to get IP address of replay server!. Try after some time.",
								Toast.LENGTH_LONG).show();
					}

				});

				ReplayActivity.this.finish();
			}
			return false;
		}

	}

	// adrian: implemented and working
	class VPNConnected extends AsyncTask<ReplayActivity, Void, Boolean> {

		@Override
		protected Boolean doInBackground(ReplayActivity... params) {

			int i = 0;
			while (i < 5) {
				i++;
				try {
					Log.d("VPNConnected", "about to get public IP");
					String str = getPublicIP();
					if (str.equalsIgnoreCase(meddleIP)) {
						Log.d("VPNConnected", "Got it!");
						// Set flag indicating VPN connectivity status
						isVPNConnected = true;

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
					Log.d("VPNConnected", "Not yet! PublicIP is: " + str);
				} catch (Exception e) {
					Log.d("VPNConnected", "failed to get VPN IP address");
					e.printStackTrace();
				}
			}

			// show a dialogue to inform user
			ReplayActivity.this.runOnUiThread(new Runnable() {
				public void run() {
					new AlertDialog.Builder(ReplayActivity.this)
							.setTitle("Error")
							.setMessage(
									"Cannot connect to VPN!\n"
											+ "Please try rebooting your phone.\n\n"
											+ "Click \"OK\" to go back.")
							.setPositiveButton("OK",
									new DialogInterface.OnClickListener() {
										@Override
										public void onClick(
												DialogInterface dialog,
												int which) {
											queueCombined.cancel(true);
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
			String publicIP = Config.get("publicIP");
			int i = 0;
			try {
				Thread.sleep(5000);
			} catch (InterruptedException e1) {
				Log.d("DisconnectVPN", "sleep failed!");
				e1.printStackTrace();
			}

			while (i < 5) {
				try {
					i++;
					String str = getPublicIP();
					if (str.equalsIgnoreCase(publicIP)) {
						Log.d("DisconnectVPN", "Got it!");
						// Set flag indicating VPN connectivity status
						isVPNConnected = false;

						// Start the replay for the next app
						// adrian: start the combined thread
						if (currentTask.equalsIgnoreCase("combined")) {
							appData_combined = UnpickleDataStream
									.unpickleCombinedJSON(
											selectedApps
													.get(currentReplayCount)
													.getDataFile(), context);
							Log.d("DisconnectVPN", "loaded json!");
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
				} catch (Exception e) {
					Log.d("DisconnectVPN", "failed to get VPN IP address");
					e.printStackTrace();
				}

				try {
					Thread.sleep(3000);
				} catch (InterruptedException e) {
					Log.d("DisconnectVPN", "sleep failed!");
				}
			}

			// show a dialogue to inform user
			ReplayActivity.this.runOnUiThread(new Runnable() {
				public void run() {
					new AlertDialog.Builder(ReplayActivity.this)
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
											ReplayActivity.this.finish();
										}
									}).show();
				}

			});

			return false;

		}

	}
}
