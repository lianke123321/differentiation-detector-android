
package com.stonybrook.replay;

import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.security.cert.X509Certificate;
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
import org.json.JSONObject;

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
import android.security.KeyChain;
import android.security.KeyChainAliasCallback;
import android.security.KeyChainException;
import android.util.Log;
import android.util.Pair;
import android.util.SparseArray;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.Window;
import android.widget.Button;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import com.rgolani.replay.R;
import com.stonybrook.android.data.VpnProfile;
import com.stonybrook.android.data.VpnProfileDataSource;
import com.stonybrook.android.logic.CharonVpnService;
import com.stonybrook.android.logic.TrustedCertificateManager;
import com.stonybrook.android.ui.LogActivity;
import com.stonybrook.replay.adapter.ImageReplayListAdapter;
import com.stonybrook.replay.bean.ApplicationBean;
import com.stonybrook.replay.bean.SocketInstance;
import com.stonybrook.replay.bean.TCPAppJSONInfoBean;
import com.stonybrook.replay.bean.UDPAppJSONInfoBean;
import com.stonybrook.replay.constant.ReplayConstants;
import com.stonybrook.replay.exception_handler.ExceptionHandler;
import com.stonybrook.replay.tcp.OldTCPSideChannel;
import com.stonybrook.replay.tcp.TCPClient;
import com.stonybrook.replay.tcp.TCPQueue;
import com.stonybrook.replay.udp.ClientThread;
import com.stonybrook.replay.udp.UDPClient;
import com.stonybrook.replay.udp.UDPQueue;
import com.stonybrook.replay.udp.UDPSideChannel;
import com.stonybrook.replay.util.Config;
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
	// ProgressDialog progressWait = null;
	int currentReplayCount = 0;
	ProgressBar progressBar = null;
	ImageReplayListAdapter adapter = null;

	String server = null;
	String enableTiming = null;

	/**
	 * These two are AsyncTasks for TCP and UDP. Both run in background. At a time, only one of them should be running.
	 */
	QueueTCPAsync queueTCP = null;
	QueueUDPAsync queueUDP = null;
	String currentTask = "none";

	// VPN Changes
	private Bundle mProfileInfo;
	/**
	 * We can provide email account here on which VPN logs can be received
	 */
	public static final String CONTACT_EMAIL = "demo@gmail.com";
	private static final int PREPARE_VPN_SERVICE = 0;
	boolean isKeyChainInitialized = false;
	boolean isVPNConnected = false;
	
	//Objects to store data for apps
	TCPAppJSONInfoBean appData_tcp = null;
	UDPAppJSONInfoBean appData_udp = null;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		this.requestWindowFeature(Window.FEATURE_NO_TITLE);
		Thread.setDefaultUncaughtExceptionHandler(new ExceptionHandler(this));
		setContentView(R.layout.replay_main_layout_images);
		
		/*
		 * First check to see of Internet access is available
		 * TODO : Identify if connection is WiFi or Cellular
		 */
		if (!isNetworkAvailable()) {
			new AlertDialog.Builder(this).setTitle("Network Error").setMessage("No Internet connection available. Try After connecting to Intenet.").setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int which) {
					ReplayActivity.this.finish();
				}
			}).show();
		}

		//Extract data that was sent by previous activity. In our case, list of apps, server and timing
		context = getApplicationContext();
		selectedApps = getIntent().getParcelableArrayListExtra("selectedApps");

		server = (String) getIntent().getStringExtra("server");
		enableTiming = (String) getIntent().getStringExtra("timing");

		//Create layout for this page
		adapter = new ImageReplayListAdapter(selectedApps, getLayoutInflater(), this);

		appsListView = (ListView) findViewById(R.id.appsListView);
		appsListView.setAdapter(adapter);

		//Register button listeners
		backButton = (Button) findViewById(R.id.backButton);
		backButton.setOnClickListener(backButtonListner);

		replayButton = (Button) findViewById(R.id.replayButton);
		replayButton.setOnClickListener(replayButtonListener);
		currentReplayCount = 0;
		
		updateSelectedTextViews(selectedApps);


		Log.d("Replay", "Loading VPN certificates");
		new CertificateLoadTask().executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR, false);
		
	}
	
	/**
	 * This Method checks the network Availability. For this NetworkInfo class is used and this should also provide type of connectivity i.e. Wi-Fi, Cellular .. 
	 * @return
	 */
	private boolean isNetworkAvailable() {
	    ConnectivityManager connectivityManager 
	          = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
	    NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
	    return activeNetworkInfo != null && activeNetworkInfo.isConnected();
	}
	
	/**
	 * This method is entry point for any application replay
	 * Here, first server reachability is checked and according to type of app (TCP or UDP) request is forwarded to methos
	 */
	void processApplicationReplay() {
		try {
			/**
			 * Read configuration file and long it into Config object. Configuration file is located in assets/configuration.properties. 
			 */
			Config.readConfigFile(ReplayConstants.CONFIG_FILE, context);

			Config.set("timing", enableTiming);
			Config.set("server", server);

			//Check server reachability
			boolean isAvailable = (new ServerReachable()).execute(server).get();
			Log.d("Replay", "Server availability " + String.valueOf(isAvailable));
			
			if (isAvailable) {
				//If server is available. Change status from to processing
				selectedApps.get(currentReplayCount).status = getResources().getString(R.string.processing);
				adapter.notifyDataSetChanged();
				
				//Forward request to respective method with required data
				if (selectedApps.get(currentReplayCount).getType().equalsIgnoreCase("tcp"))
					processTCPApplication(selectedApps.get(currentReplayCount));
				else
					processUDPApplication(selectedApps.get(currentReplayCount));
			} else {
				Toast.makeText(ReplayActivity.this, "Server Not Available. Try after some time.", Toast.LENGTH_LONG).show();
			}
			

		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}
	/**
	 * This method processes Replay for TCP application.
	 * 1) Parse pickle file
	 * 2) Start AsyncTask for TCP with the parsed pickle data
	 * TODO: Remove the parameter to AsyncTask as it is no longer required
	 * @param applicationBean
	 * @throws Exception
	 */
	private void processTCPApplication(ApplicationBean applicationBean) throws Exception {

		currentTask = "tcp";
		appData_tcp = UnpickleDataStream.unpickleTCP(applicationBean.getDataFile(), context);
		queueTCP = new QueueTCPAsync(this, "open");
		queueTCP.execute("");

	}

	/**
	 * This method processes Replay for UDP application.
	 * 1) Parse pickle file
	 * 2) Start AsyncTask for UDP with the parsed pickle data
	 * TODO: Remove the parameter to AsyncTask as it is no longer required
	 * @param applicationBean
	 * @throws Exception
	 */
	private void processUDPApplication(ApplicationBean applicationBean) throws Exception {

		currentTask = "udp";
		appData_udp = UnpickleDataStream.unpickleUDP(applicationBean.getDataFile(), context);
		queueUDP = new QueueUDPAsync(this, "open");
		queueUDP.execute("");
	}

	void updateSelectedTextViews(ArrayList<ApplicationBean> list) {
		selectedAppsMsgTextView = (TextView) findViewById(R.id.selectedAppsMsgTextView);
		selectedAppsSizeTextView = (TextView) findViewById(R.id.selectedAppsSizeTextView);

		selectedAppsMsgTextView.setText(String.valueOf(list.size()) + " applications selected.");
		double totalSize = 0.0;

		for (int i = 0; i < list.size(); i++)
			totalSize += list.get(i).getSize();

		DecimalFormat df = new DecimalFormat("#.##");
		selectedAppsSizeTextView.setText(df.format(totalSize).toString() + " MB");

	}

	/**
	 * This is method is called when user presses the back button. This will take then back to main screen.
	 */
	OnClickListener backButtonListner = new OnClickListener() {

		@Override
		public void onClick(View v) {
			ReplayActivity.this.finish();
			ReplayActivity.this.overridePendingTransition(android.R.anim.slide_in_left, android.R.anim.slide_out_right);
		}
	};

	/**
	 * This method is called when user clicks on Replay Button.
	 */
	OnClickListener replayButtonListener = new OnClickListener() {

		@Override
		public void onClick(View v) {

			processApplicationReplay();
		}
	};

	/**
	 * Simple check to see if server is reachable. No port listen checks are being done here.
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
	 * Right now pickle files are stored in Assets folder which increases the apk file size. 
	 * I wrote this to get files from Server. For testing purpose I wrote small Server. This can be later integrated in to python Server. 
	 * TODO: this need more work and testing. Try integrating this with main code and see what happens.
	 * @author rajesh
	 *
	 */
	private class FileDownload extends AsyncTask<Void, Void, Void> {

    	String serverName = null;
    	int portNo;
    	String appName;
    	ReplayCompleteListener listener;
    	
    	/**
    	 * @param serverName
    	 * @param portNo
    	 * @param appName
    	 */
    	public FileDownload(ReplayCompleteListener listener, String serverName, int portNo, String appName) {
    		this.serverName = serverName;
    		this.portNo = portNo;
    		this.appName = appName;
    		this.listener = listener;
		}
    	
    	boolean success = true;
    	
    	@Override
		protected void onPostExecute(Void result) {
			this.listener.fileExistsListener(success);
		}
    	
    	/**
    	 * Actual work will be done here. Check if file exists. If it does then return otherwise
    	 * Create socket and download file from server and save it to internal storage.
    	 */
        @Override
        protected Void doInBackground(Void...params) {
        	try
            {
        		Socket client = null;
        		PrintWriter writer;
        		BufferedReader reader;
        		int bytesRead;
        		int currentTot = 0;
        		File file = null;
        		FileOutputStream fos = null;
        		BufferedOutputStream bos = null;
        		try {

        			//Check to see whether file exists
        			file = new File(context.getFilesDir(), appName+".pcap_client_pickle");
        			if(file.exists())
        			{
        				Log.d("Replay", "File " + file.getName() + " exists!!!");
        				return null;
        			}
        			//If not download
        			client = new Socket();
        			client.connect(new InetSocketAddress(serverName, portNo));
        			reader = new BufferedReader(new InputStreamReader(client.getInputStream()));
        			writer = new PrintWriter(client.getOutputStream(), true);

        			writer.println(appName);

        			long fileLen = Long.parseLong(reader.readLine());
        			Log.d("Replay", "File size is " + fileLen);
        			
        			Log.d("Replay", "context directory path is " + context.getFilesDir());
        			
        			byte[] bytearray = new byte[(int)fileLen];
        			InputStream is = client.getInputStream();
        			
        			fos = new FileOutputStream(file);
        			bos = new BufferedOutputStream(fos);
        			bytesRead = is.read(bytearray, 0, bytearray.length);
        			currentTot = bytesRead;
        			
        			while (currentTot < fileLen && bytesRead > 0) {
        				bytesRead = is.read(bytearray, currentTot, (bytearray.length - currentTot));
        				if (bytesRead >= 0)
        					currentTot += bytesRead;
        			} 
        			//Put this code in finally
        			bos.write(bytearray, 0, currentTot);
        			bos.flush();
        			
        			
        		} catch (Exception ex) {
        			ex.printStackTrace();
        		}
        		finally
        		{
        			if (bos != null) bos.close();
        			try {
        				if(client!=null) client.close();
        			} catch (IOException e) {
        				e.printStackTrace();
        			}
        		}
            }
            catch(Exception ex)
            {
            	success = false;
            	ex.printStackTrace();
            }
            return null;
        }
    }
	
	/**
	 * This asyncTask processes the UDP Replay.
	 * TODO: Python client for UDP was changed heavily in last couple of weeks of Semester. This code does not have those changes implemented.
	 * Need to implement those changes.
	 * Note : First go through TCP then come to UDP.
	 * @author rajesh
	 *
	 */
	class QueueUDPAsync extends AsyncTask<String, String, String> {

		HashMap<String, ClientThread> CSPairMapping = null;
		UDPAppJSONInfoBean appData = null;
		long timeStarted = 0;
		//This is Lister which will be called when this method finishes. More information about this is provided in ReplayCompleteListener file.
		private ReplayCompleteListener listener;
		boolean success = true;
		//This simply identifies whether we are in open or VPN
		public String channel = null;

		public QueueUDPAsync(ReplayCompleteListener listener, String channel) {
			this.listener = listener;
			this.channel = channel;
		}

		@Override
		protected void onPostExecute(String result) {
			Log.d("Replay", "Replay lasted for " + (System.currentTimeMillis() - this.timeStarted));
			
			//Callback according to type of Replay with status of Replay
			if (channel.equalsIgnoreCase("open"))
				listener.openFinishCompleteCallback(success);
			else
				listener.vpnFinishCompleteCallback(success);

		}

		protected void onProgressUpdate(String... a) {
			Log.d("UDPReplay", "You are in progress update ... " + a[0]);
		}

		@Override
		protected String doInBackground(String... String) {
			this.appData = appData_udp;
			this.timeStarted = System.currentTimeMillis();
			SparseArray<Integer> NATMap = new SparseArray<Integer>();
			SparseArray<ClientThread> PortMap = new SparseArray<ClientThread>();
			this.CSPairMapping = new HashMap<String, ClientThread>();
			ArrayList<ClientThread> clients = new ArrayList<ClientThread>();

			try {
				/*
				 * Here we are checking if we are on VPN channel. If we are on VPN, wait for 5 sec for VPN to connect.
				 * TODO: This is very bad. Remove this and try finding out some other way whether VPN is connected. One way can be to get IP that's visible outside.
				 * If it's of Meddle server then we are connected to VPN. Implemented this in VPNConnected AsyncTask but never got chance to integrate it. 
				 */
				if (this.channel.equalsIgnoreCase("vpn"))
					Thread.sleep(5000);
				Log.d("VPNUDP", this.channel);
				int sideChannelPort = Integer.valueOf(Config.get("udp_sidechannel_port"));
				String randomID = null;
				SocketInstance socketInstance = new SocketInstance(Config.get("server"), sideChannelPort, null);
				UDPSideChannel sideChannel = null;

				SparseArray<Integer> serverPortsMap = null;
				
				/**
				 * Ask for port mapping from server. For some reason, port map info parsing was throwing error. so, I put while loop to do this untill
				 * port mapping is parsed successfully.
				 */
				
				boolean s = false;
				while (!s) {
					try {
						randomID = new RandomString(10).nextString();
						sideChannel = new UDPSideChannel(socketInstance, randomID);
						sideChannel.declareID();
						serverPortsMap = sideChannel.receivePortMappingNonBlock();
						s = true;
					} catch (JSONException ex) {
						ex.printStackTrace();
					}
				}
				
				/**
				 * Create clients from CSPairs
				 */

				for (String key : appData.getCsPairs().keySet()) {
					int destPort = Integer.valueOf(key.substring(key.lastIndexOf('.') + 1, key.length()));
					if (serverPortsMap.size() != 0)
						destPort = serverPortsMap.get(destPort);
					UDPClient c = new UDPClient(key, Config.get("server"), destPort);
					Pair<Integer, Integer> NATMapping = c.identify(sideChannel, randomID, appData.getReplayName());
					NATMap.put(NATMapping.first, NATMapping.second);

					ClientThread client = new ClientThread(c);
					Thread cThread = new Thread(client);
					cThread.start();

					PortMap.put(c.getPort(), client);
					CSPairMapping.put(key, client);
					clients.add(client);
				}


				UDPQueue queue = new UDPQueue(appData.getQ(), CSPairMapping, Boolean.valueOf(Config.get("timing")));
				Thread queueThread = new Thread(queue);

				queueThread.start();

				sideChannel.waitForFinish(PortMap, NATMap);
				sideChannel.terminate(clients);
			} catch (Exception ex) {
				success = false;
				ex.printStackTrace();
			}
			return null;
		}

	}

	/**
	 * This is TCP AsyncTask. Here replay will be performed in background. From this point, I have tried to keep code similar to  Python Client for easy future changes.
	 * @author rajesh
	 *
	 */
	class QueueTCPAsync extends AsyncTask<String, String, String> {

		TCPAppJSONInfoBean appData = null;
		long timeStarted = 0;
		//This is Listener which will be called when this method finishes. More information about this is provided in ReplayCompleteListener file.
		private ReplayCompleteListener listener;
		boolean success = true;
		//This simply identifies whether we are in open or VPN
		public String channel = null;

		public QueueTCPAsync(ReplayCompleteListener listener, String channel) {
			this.listener = listener;
			this.channel = channel;
		}

		@Override
		protected void onPostExecute(String result) {
			Log.d("Replay", "TCP Replay lasted for " + (System.currentTimeMillis() - this.timeStarted));
			
			//Callback according to type of Replay with status of Replay
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
			this.appData = appData_tcp;
			this.timeStarted = System.currentTimeMillis();
			HashMap<String, TCPClient> CSPairMapping = new HashMap<String, TCPClient>();

			try {
				/*
				 * Here we are checking if we are on VPN channel. If we are on VPN, wait for 5 sec for VPN to connect.
				 * TODO: This is very bad. Remove this and try finding out some other way whether VPN is connected. One way can be to get IP that's visible outside.
				 * If it's of Meddle server then we are connected to VPN. Implemented this in VPNConnected AsyncTask but never got chance to integrate it. 
				 */
				if (this.channel.equalsIgnoreCase("vpn"))
				{
					Thread.sleep(5000);
				}
				
				int sideChannelPort = Integer.valueOf(Config.get("tcp_sidechannel_port"));
				String randomID = null;
				SocketInstance socketInstance = new SocketInstance(Config.get("server"), sideChannelPort, null);
				Log.d("Server", Config.get("server"));
				
				//OldTCPSiceChannel is being used as TCPSideChannel is for gevent branch.
				OldTCPSideChannel sideChannel = null;
				HashMap<Integer, Integer> serverPortsMap = null; 
				
				/**
				 * Ask for port mapping from server. For some reason, port map info parsing was throwing error. so, I put while loop to do this untill
				 * port mapping is parsed successfully.
				 */
			
				boolean s = false;
				while (!s) {
					try {
						randomID = new RandomString(10).nextString();
						sideChannel = new OldTCPSideChannel(socketInstance, randomID);
						sideChannel.declareID(appData.getReplayName());
						serverPortsMap = sideChannel.receivePortMappingNonBlock();
						s = true;
					} catch (JSONException ex) {
						ex.printStackTrace();
					}
				}
				
				/**
				 * Create clients from CSPairs
				 */
				for (String key : appData.getCsPairs()) {
					int destPort = Integer.valueOf(key.substring(key.lastIndexOf('.') + 1, key.length()));
					if (serverPortsMap.size() != 0)
						destPort = serverPortsMap.get(destPort);
					TCPClient c = new TCPClient(key, Config.get("server"), destPort, randomID, appData.getReplayName());
					CSPairMapping.put(key, c);
				}

				Log.d("Replay", String.valueOf(CSPairMapping.size()));
				
				//Running the Queue
				TCPQueue queue = new TCPQueue(appData.getQ());
				queue.run(CSPairMapping, Boolean.valueOf(Config.get("timing")));
				

			} catch (JSONException ex) {
				Log.d("Replay", "Error parsing JSON");
				ex.printStackTrace();
			} catch (Exception ex) {
				success = false;
				ex.printStackTrace();

			}
			return null;
		}

	}

	/**
	 * This method is called when replay over VPN is finished
	 */
	@Override
	public void vpnFinishCompleteCallback(Boolean success) {
		try {

			/**
			 * If there was error. Display message and stop processing further.
			 * TODO: If there are other apps which are waiting for replay then start processing those. should be easy.
			 */
			
			if (!success) {
				Toast.makeText(context, "Error while processing...", 1).show();
				return;
			}

			/**
			 * Change status on screen.
			 * Here currentReplayCount stores number of applications selected by user. ++ makes processing of next application in list when processApplicationReplay() is called.
			 */
			selectedApps.get(currentReplayCount).resultImg = "p";
			selectedApps.get(currentReplayCount++).status = getResources().getString(R.string.finished);
			adapter.notifyDataSetChanged();

			//If there are more apps that require processing then start with those.
			if (selectedApps.size() != currentReplayCount) {
				processApplicationReplay();
			} else {
				// progressWait.setMessage("Finishing Analysis...");
				// Thread.sleep(10000);
				// progressWait.dismiss();
			}
			
			
		} catch (Exception ex) {
			ex.printStackTrace();
		}
		finally
		{
			//Disconnect VPN. Does not matter whether replay was successful or not
			disconnectVPN(); 
		}
	}

	/**
	 * Called when Replay is finished over Open channel.
	 * Connects to VPN and starts replay for same App again
	 */
	@Override
	public void openFinishCompleteCallback(Boolean success) {
		try {
			
			/*if (success) {
			selectedApps.get(currentReplayCount).resultImg = "p";
			selectedApps.get(currentReplayCount++).status = getResources().getString(R.string.finished);
			adapter.notifyDataSetChanged();
			}*/
			
			/**
			 * If Replay on Open was successful then schedule on VPN
			 * TODO: If there are other apps which are waiting for replay then start processing those. should be easy.
			 */
			if (success) {
				
				//Connect to VPN
				
				onVpnProfileSelected(null);
				Log.d("Replay", "VPN started");
			
				//Set flag indicating VPN connectivity status
				isVPNConnected = true;
				
				//Change screen status
				selectedApps.get(currentReplayCount).status = getResources().getString(R.string.vpn);
				adapter.notifyDataSetChanged();

				//Start the replay again for same app
				if (currentTask.equalsIgnoreCase("tcp")) {
					queueTCP.cancel(true);
					queueTCP = new QueueTCPAsync(this, "vpn");
					queueTCP.execute("");
				} else {
					queueUDP.cancel(true);
					queueUDP = new QueueUDPAsync(this, "vpn");
					queueUDP.execute("");
				}

			}
			else
			{
				//Update status on screen and stop processing
				selectedApps.get(currentReplayCount).resultImg = "p";
				selectedApps.get(currentReplayCount++).status = getResources().getString(R.string.error);
				adapter.notifyDataSetChanged();
			}
		} catch (Exception ex) {
			ex.printStackTrace();
		}

	}

	/**
	 * From this point on, all the code related to VPN is taken from Meddle App. 
	 */
	
	/**
	 * Wrote this to handle Pickle file Download from server. Should be used with FileDownload AsyncTask.
	 * FileDownload AsyncTask should call this callback which will start with Replay processing
	 */
	@Override
	public void fileExistsListener(Boolean success) {
		try {
			if (success) {
				selectedApps.get(currentReplayCount).status = getResources()
						.getString(R.string.processing);
				adapter.notifyDataSetChanged();
				if (selectedApps.get(currentReplayCount).getType()
						.equalsIgnoreCase("tcp"))
					processTCPApplication(selectedApps.get(currentReplayCount));
				else
					processUDPApplication(selectedApps.get(currentReplayCount));
			}
			else
			{
				selectedApps.get(currentReplayCount).resultImg = "p";
				selectedApps.get(currentReplayCount++).status = getResources().getString(R.string.error);
				adapter.notifyDataSetChanged();
			}
		} catch (Exception e) {
			e.printStackTrace();
		}

	}
	
	@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if (keyCode == KeyEvent.KEYCODE_BACK) {
			try {
				if (currentTask.equalsIgnoreCase("tcp") && queueTCP != null && queueTCP.getStatus() == AsyncTask.Status.RUNNING)
					queueTCP.cancel(true);
				else if (currentTask.equalsIgnoreCase("udp") && queueUDP != null && queueUDP.getStatus() == AsyncTask.Status.RUNNING)
					queueUDP.cancel(true);
			} catch (Exception e) {
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
	private class CertificateLoadTask extends AsyncTask<Boolean, Void, TrustedCertificateManager> {
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
	 * TODO: Think how do we want user to create connection. May be dialog can be create in which user can add the credentials and certificates. 
	 * Note : Connection to VPN requires installations of certificate on Android device 
	 * @param profile
	 */
	public void onVpnProfileSelected(VpnProfile profile) {
		Bundle profileInfo = new Bundle();
		profileInfo.putLong(VpnProfileDataSource.KEY_ID, 1);
		//TODO: Move this to settings Pop-up which should be pretty straight forward
		profileInfo.putString(VpnProfileDataSource.KEY_USERNAME, "rajesh");
		profileInfo.putString(VpnProfileDataSource.KEY_PASSWORD, "rajesh");
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
				new VpnNotSupportedError().show(getFragmentManager(), "ErrorDialog");
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
				Intent intent = new Intent(this, CharonVpnService.class);
				intent.putExtras(mProfileInfo);
				intent.putExtra("action", "start");
				this.startService(intent);
			} else {
				// a alert dialog will pop up and the app will quite if user
				// click "Cancel" for trust permission
				AlertDialog.Builder alertDialog = new AlertDialog.Builder(this);
				alertDialog.setMessage("Meddle is closing now").setNeutralButton("OK", new DialogInterface.OnClickListener() {

					@Override
					public void onClick(DialogInterface dialog, int which) {
						// exit this application
						System.exit(0);
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
			return new AlertDialog.Builder(getActivity()).setTitle("VPN Not supported").setMessage("Your device does not support VPN").setCancelable(false).setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
				@Override
				public void onClick(DialogInterface dialog, int id) {
					dialog.dismiss();
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

	private class SelectUserCertOnClickListener implements KeyChainAliasCallback {
		@Override
		public void alias(final String alias) {
			if (alias != null) {
				try {
					final X509Certificate[] chain = KeyChain.getCertificateChain(ReplayActivity.this, alias);

				} catch (KeyChainException e) {
					e.printStackTrace();
				} catch (InterruptedException e) {
					e.printStackTrace();
				}
			}
		}
	}

	/**
	 * This task can be used to identify whether VPN is connected. For this i am asking external service to return the IP address which is visible outside
	 * and if the IP address is same as meddle server than VPN is connected otherwise not. 
	 * TODO: This is very rough idea of code. Needs more thinking
	 * @author rajesh
	 *
	 */
	class VPNConnected extends AsyncTask<String, String, Boolean> {

		@Override
		protected Boolean doInBackground(String... ipArr) {
			   String ip = null;
			   try {
				   int i = 15;
				   while(i > 0)
				   { 
					i--;
			        HttpClient httpclient = new DefaultHttpClient();		        
			        HttpGet httpget = new HttpGet("http://ip2country.sourceforge.net/ip2c.php?format=JSON");
			        HttpResponse response;
			        response = httpclient.execute(httpget);
			        HttpEntity entity = response.getEntity();
			        entity.getContentLength();
			        String str = EntityUtils.toString(entity);
			        JSONObject json_data = new JSONObject(str);
			        ip = json_data.getString("ip");
			        
			        if(ip.equalsIgnoreCase(ipArr[0]))
			        {
			        	return true;
			        }
			        Thread.sleep(1000);
			        Log.d("IP", ip);
				   }
			    }
			    catch (Exception e){ e.printStackTrace(); }

			  return false;

		}

	}
	
}
