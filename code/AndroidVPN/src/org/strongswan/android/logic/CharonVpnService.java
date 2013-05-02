/*
 * Copyright (C) 2012 Tobias Brunner
 * Copyright (C) 2012 Giuliano Grassi
 * Copyright (C) 2012 Ralf Sager
 * Hochschule fuer Technik Rapperswil
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 */

package org.strongswan.android.logic;

import java.io.File;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketAddress;
import java.security.PrivateKey;
import java.security.cert.CertificateEncodingException;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;

import org.strongswan.android.data.VpnProfile;
import org.strongswan.android.data.VpnProfileDataSource;
import org.strongswan.android.logic.VpnStateService.ErrorState;
import org.strongswan.android.logic.VpnStateService.State;
import org.strongswan.android.ui.MainActivity;

import android.app.PendingIntent;
import android.app.Service;
import android.content.ActivityNotFoundException;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.net.ConnectivityManager;
import android.net.VpnService;
import android.os.Bundle;
import android.os.IBinder;
import android.os.ParcelFileDescriptor;
import android.security.KeyChain;
import android.security.KeyChainException;
import android.util.Log;

public class CharonVpnService extends VpnService implements Runnable
{
	private static final String TAG = CharonVpnService.class.getSimpleName();
	public static final String LOG_FILE = "charon.log";

	private Timer timer;
	private String mLogFile;
	private VpnProfileDataSource mDataSource;
	private Thread mConnectionHandler;
	private VpnProfile mCurrentProfile;
	private volatile String mCurrentCertificateAlias;
	private volatile String mCurrentUserCertificateAlias;
	private VpnProfile mNextProfile;
	private volatile boolean mProfileUpdated;
	private volatile boolean mTerminate;
	private volatile boolean mIsDisconnecting;
	private VpnStateService mService;
	private final Object mServiceLock = new Object();
	private final ServiceConnection mServiceConnection = new ServiceConnection() {
		@Override
		public void onServiceDisconnected(ComponentName name)
		{	/* since the service is local this is theoretically only called when the process is terminated */
			synchronized (mServiceLock)
			{
				mService = null;
			}
		}

		@Override
		public void onServiceConnected(ComponentName name, IBinder service)
		{
			synchronized (mServiceLock)
			{
				mService = ((VpnStateService.LocalBinder)service).getService();
			}
			/* we are now ready to start the handler thread */
			mConnectionHandler.start();
		}
	};
	private CharonVpnService syncObject;
	
	private ConnectivityManager connectivityManger;
	private BroadcastReceiver mConnReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
        	if (syncObject==null || mService==null) return;
        	synchronized (syncObject){
        		if (mService.getState() != State.CONNECTED && 
						mService.getState() != State.CONNECTING)
					connectToDefaultProfile();
	            
	        }
        }
	};
	
	

	/**
	 * as defined in charonservice.h
	 */
	static final int STATE_CHILD_SA_UP = 1;
	static final int STATE_CHILD_SA_DOWN = 2;
	static final int STATE_AUTH_ERROR = 3;
	static final int STATE_PEER_AUTH_ERROR = 4;
	static final int STATE_LOOKUP_ERROR = 5;
	static final int STATE_UNREACHABLE_ERROR = 6;
	static final int STATE_GENERIC_ERROR = 7;

	@Override
	public int onStartCommand(Intent intent, int flags, int startId)
	{
		if (intent != null)
		{
			Bundle bundle = intent.getExtras();
			VpnProfile profile = null;
			if (bundle != null)
			{
				profile = mDataSource.getVpnProfile(bundle.getLong(VpnProfileDataSource.KEY_ID));
				if (profile != null)
				{
					String password = bundle.getString(VpnProfileDataSource.KEY_PASSWORD);
					profile.setPassword(password);
				}
			}
			setNextProfile(profile);
		}
		return START_NOT_STICKY;
	}

	@Override
	public void onCreate()
	{
		mLogFile = getFilesDir().getAbsolutePath() + File.separator + LOG_FILE;

		mDataSource = new VpnProfileDataSource(this);
		mDataSource.open();
		/* use a separate thread as main thread for charon */
		mConnectionHandler = new Thread(this);
		/* the thread is started when the service is bound */
		bindService(new Intent(this, VpnStateService.class),
					mServiceConnection, Service.BIND_AUTO_CREATE);
		/* check if we need to start a connection after being offline */
		registerReceiver(mConnReceiver, 
	            new IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION));
	}

	@Override
	public void onRevoke()
	{	/* the system revoked the rights grated with the initial prepare() call.
		 * called when the user clicks disconnect in the system's VPN dialog */
		setNextProfile(null);
	}

	@Override
	public void onDestroy()
	{
		mTerminate = true;
		setNextProfile(null);
		try
		{
			mConnectionHandler.join();
		}
		catch (InterruptedException e)
		{
			e.printStackTrace();
		}
		if (mService != null)
		{
			unbindService(mServiceConnection);
		}
		mDataSource.close();
	}

	/**
	 * Set the profile that is to be initiated next. Notify the handler thread.
	 *
	 * @param profile the profile to initiate
	 */
	private void setNextProfile(VpnProfile profile)
	{
		if (syncObject==null) return;
		synchronized (syncObject)
		{
			this.mNextProfile = profile;
			mProfileUpdated = true;
			notifyAll();
		}
	}

	@Override
	public void run()
	{
		syncObject = this;
		final Thread thisThread = Thread.currentThread();
		timer = new Timer();
		timer.scheduleAtFixedRate(new TimerTask(){

			@Override
			public void run() {
//				if (mCurrentProfile != null && !mCurrentProfile.isAutoReconnect()) return;
				synchronized (syncObject)
				{
					if (mService==null) return;
					Log.i(TAG, "periodic restart check");
					if (mService.getState() != State.CONNECTED && 
							mService.getState() != State.CONNECTING)
						connectToDefaultProfile();
					


					
//					if ((mConnectStartTime != -1 && 
//							mConnectStartTime < System.currentTimeMillis()-30*1000) || 
//							mLastError != ErrorState.NO_ERROR || mService.getState()!=State.CONNECTED){
//						Log.i(TAG, "restarting connection due to 30 seconds of no connection");
//						//					TrustedCertificateManager.getInstance().reload();
//						//					if (getLocalIPv4Address()!=null)
//						//						deinitializeCharon();
//						restartConnection();
//						thisThread.interrupt();
//					}
				}

			}}, 5000, 60*1000);
		timer.scheduleAtFixedRate(new TimerTask(){

			@Override
			public void run() {
		try{
		    SocketAddress sockaddr = new InetSocketAddress("www.google.com", 80);

            // Create an unbound socket
            Socket sock = new Socket();

            // This method will block no more than timeoutMs.
            // If the timeout occurs, SocketTimeoutException is thrown.
            int timeoutMs = 5000;   // 5 seconds
            sock.connect(sockaddr, timeoutMs);
            Log.i(TAG, "Google is reachable");
            sock.close();
            
		}             
		catch(Exception e){
			Log.i(TAG, "Google not reachable! Restarting...");
			connectToDefaultProfile();
		}
			}}, 5000, 15*60*1000);
		
		while (true)
		{
			synchronized (this)
			{
				try
				{
					while (!mProfileUpdated)
					{
						wait();
					}

					mProfileUpdated = false;
					stopCurrentConnection();
					if (mNextProfile == null)
					{
						setProfile(null);
						setState(State.DISABLED);
						if (mTerminate)
						{
							break;
						}
					}
					else
					{
						mCurrentProfile = mNextProfile;
						mNextProfile = null;

						/* store this in a separate (volatile) variable to avoid
						 * a possible deadlock during deinitialization */
						mCurrentCertificateAlias = mCurrentProfile.getCertificateAlias();
						mCurrentUserCertificateAlias = mCurrentProfile.getUserCertificateAlias();

						setProfile(mCurrentProfile);
						setError(ErrorState.NO_ERROR);
						setState(State.CONNECTING);
						mIsDisconnecting = false;

						BuilderAdapter builder = new BuilderAdapter(mCurrentProfile.getName());
						initializeCharon(builder, mLogFile);
						Log.i(TAG, "charon started");

						initiate(mCurrentProfile.getVpnType().getIdentifier(),
								 mCurrentProfile.getGateway(), mCurrentProfile.getUsername(),
								 mCurrentProfile.getPassword());
					}
				}
				catch (InterruptedException ex)
				{
					stopCurrentConnection();
					setState(State.DISABLED);
				}
			}
		}
	}

	/**
	 * Stop any existing connection by deinitializing charon.
	 */
	private void stopCurrentConnection()
	{
		synchronized (this)
		{
			if (mCurrentProfile != null)
			{
				setState(State.DISCONNECTING);
				mIsDisconnecting = true;
				deinitializeCharon();
				Log.i(TAG, "charon stopped");
				boolean isAutoRec = mCurrentProfile.isAutoReconnectClicked();
				Log.e("CHARONVPNSERVICE", "autoconnect " + isAutoRec);
				if (!isAutoRec){
					// user don't want the auto reconnect
					timer.cancel();
				}
				mCurrentProfile = null;
			}
		}
	}

	/**
	 * Update the VPN profile on the state service. Called by the handler thread.
	 *
	 * @param profile currently active VPN profile
	 */
	private void setProfile(VpnProfile profile)
	{
		synchronized (mServiceLock)
		{
			if (mService != null)
			{
				mService.setProfile(profile);
			}
		}
	}

	/**
	 * Update the current VPN state on the state service. Called by the handler
	 * thread and any of charon's threads.
	 *
	 * @param state current state
	 */
	private void setState(State state)
	{
		synchronized (mServiceLock)
		{
			if (mService != null)
			{
				mService.setState(state);
			}
		}
	}

	/**
	 * Set an error on the state service. Called by the handler thread and any
	 * of charon's threads.
	 *
	 * @param error error state
	 */
	private void setError(ErrorState error)
	{
		synchronized (mServiceLock)
		{
			if (mService != null)
			{
				mService.setError(error);
			}
		}
	}

	/**
	 * Set an error on the state service and disconnect the current connection.
	 * This is not done by calling stopCurrentConnection() above, but instead
	 * is done asynchronously via state service.
	 *
	 * @param error error state
	 */
	private void setErrorDisconnect(ErrorState error)
	{
		synchronized (mServiceLock)
		{
			if (mService != null)
			{
				mService.setError(error);
				if (!mIsDisconnecting)
				{
					mService.disconnect();
				}
			}
		}
	}

	/**
	 * Updates the state of the current connection.
	 * Called via JNI by different threads (but not concurrently).
	 *
	 * @param status new state
	 */
	public void updateStatus(int status)
	{
		switch (status)
		{
			case STATE_CHILD_SA_DOWN:
				/* we ignore this as we use closeaction=restart */
				break;
			case STATE_CHILD_SA_UP:
				setState(State.CONNECTED);
				break;
			case STATE_AUTH_ERROR:
				setErrorDisconnect(ErrorState.AUTH_FAILED);
				break;
			case STATE_PEER_AUTH_ERROR:
				setErrorDisconnect(ErrorState.PEER_AUTH_FAILED);
				break;
			case STATE_LOOKUP_ERROR:
				setErrorDisconnect(ErrorState.LOOKUP_FAILED);
				break;
			case STATE_UNREACHABLE_ERROR:
				setErrorDisconnect(ErrorState.UNREACHABLE);
				break;
			case STATE_GENERIC_ERROR:
				setErrorDisconnect(ErrorState.GENERIC_ERROR);
				break;
			default:
				Log.e(TAG, "Unknown status code received");
				break;
		}
	}

	/**
	 * Function called via JNI to generate a list of DER encoded CA certificates
	 * as byte array.
	 *
	 * @param hash optional alias (only hash part), if given matching certificates are returned
	 * @return a list of DER encoded CA certificates
	 */
	private byte[][] getTrustedCertificates(String hash)
	{
		ArrayList<byte[]> certs = new ArrayList<byte[]>();
		TrustedCertificateManager certman = TrustedCertificateManager.getInstance();
		try
		{
			if (hash != null)
			{
				String alias = "user:" + hash + ".0";
				X509Certificate cert = certman.getCACertificateFromAlias(alias);
				if (cert == null)
				{
					alias = "system:" + hash + ".0";
					cert = certman.getCACertificateFromAlias(alias);
				}
				if (cert == null)
				{
					return null;
				}
				certs.add(cert.getEncoded());
			}
			else
			{
				String alias = this.mCurrentCertificateAlias;
				if (alias != null)
				{
					X509Certificate cert = certman.getCACertificateFromAlias(alias);
					if (cert == null)
					{
						return null;
					}
					certs.add(cert.getEncoded());
				}
				else
				{
					for (X509Certificate cert : certman.getAllCACertificates().values())
					{
						certs.add(cert.getEncoded());
					}
				}
			}
		}
		catch (CertificateEncodingException e)
		{
			e.printStackTrace();
			return null;
		}
		return certs.toArray(new byte[certs.size()][]);
	}

	/**
	 * Function called via JNI to get a list containing the DER encoded certificates
	 * of the user selected certificate chain (beginning with the user certificate).
	 *
	 * Since this method is called from a thread of charon's thread pool we are safe
	 * to call methods on KeyChain directly.
	 *
	 * @return list containing the certificates (first element is the user certificate)
	 * @throws InterruptedException
	 * @throws KeyChainException
	 * @throws CertificateEncodingException
	 */
	private byte[][] getUserCertificate() throws KeyChainException, InterruptedException, CertificateEncodingException
	{
		ArrayList<byte[]> encodings = new ArrayList<byte[]>();
		X509Certificate[] chain = KeyChain.getCertificateChain(getApplicationContext(), mCurrentUserCertificateAlias);
		if (chain == null || chain.length == 0)
		{
			return null;
		}
		for (X509Certificate cert : chain)
		{
			encodings.add(cert.getEncoded());
		}
		return encodings.toArray(new byte[encodings.size()][]);
	}

	/**
	 * Function called via JNI to get the private key the user selected.
	 *
	 * Since this method is called from a thread of charon's thread pool we are safe
	 * to call methods on KeyChain directly.
	 *
	 * @return the private key
	 * @throws InterruptedException
	 * @throws KeyChainException
	 * @throws CertificateEncodingException
	 */
	private PrivateKey getUserKey() throws KeyChainException, InterruptedException
	{
		return KeyChain.getPrivateKey(getApplicationContext(), mCurrentUserCertificateAlias);

	}

	/**
	 * Initialization of charon, provided by libandroidbridge.so
	 *
	 * @param builder BuilderAdapter for this connection
	 * @param logfile absolute path to the logfile
	 */
	public native void initializeCharon(BuilderAdapter builder, String logfile);

	/**
	 * Deinitialize charon, provided by libandroidbridge.so
	 */
	public native void deinitializeCharon();

	/**
	 * Initiate VPN, provided by libandroidbridge.so
	 */
	public native void initiate(String type, String gateway, String username, String password);

	/**
	 * Adapter for VpnService.Builder which is used to access it safely via JNI.
	 * There is a corresponding C object to access it from native code.
	 */
	public class BuilderAdapter
	{
		private final String mName;
		private VpnService.Builder mBuilder;

		public BuilderAdapter(String name)
		{
			mName = name;
			mBuilder = createBuilder(name);
		}

		private VpnService.Builder createBuilder(String name)
		{
			VpnService.Builder builder = new CharonVpnService.Builder();
			builder.setSession(mName);

			/* even though the option displayed in the system dialog says "Configure"
			 * we just use our main Activity */
			Context context = getApplicationContext();
			Intent intent = new Intent(context, MainActivity.class);
			PendingIntent pending = PendingIntent.getActivity(context, 0, intent,
															  PendingIntent.FLAG_UPDATE_CURRENT);
			builder.setConfigureIntent(pending);
			return builder;
		}

		public synchronized boolean addAddress(String address, int prefixLength)
		{
			try
			{
				mBuilder.addAddress(address, prefixLength);
			}
			catch (IllegalArgumentException ex)
			{
				return false;
			}
			return true;
		}

		public synchronized boolean addDnsServer(String address)
		{
			try
			{
				mBuilder.addDnsServer(address);
			}
			catch (IllegalArgumentException ex)
			{
				return false;
			}
			return true;
		}

		public synchronized boolean addRoute(String address, int prefixLength)
		{
			try
			{
				mBuilder.addRoute(address, prefixLength);
			}
			catch (IllegalArgumentException ex)
			{
				return false;
			}
			return true;
		}

		public synchronized boolean addSearchDomain(String domain)
		{
			try
			{
				mBuilder.addSearchDomain(domain);
			}
			catch (IllegalArgumentException ex)
			{
				return false;
			}
			return true;
		}

		public synchronized boolean setMtu(int mtu)
		{
			try
			{
				mBuilder.setMtu(mtu);
			}
			catch (IllegalArgumentException ex)
			{
				return false;
			}
			return true;
		}

		public synchronized int establish()
		{
			ParcelFileDescriptor fd;
			try
			{
				fd = mBuilder.establish();
			}
			catch (Exception ex)
			{
				ex.printStackTrace();
				return -1;
			}
			if (fd == null)
			{
				return -1;
			}
			/* now that the TUN device is created we don't need the current
			 * builder anymore, but we might need another when reestablishing */
			mBuilder = createBuilder(mName);
			return fd.detachFd();
		}
	}
	
	private void connectToDefaultProfile(){
		Context context = getApplicationContext();
		Log.i(TAG, "preparing service");
		Intent intent2 = VpnService.prepare(context);
		if (intent2 != null)
		{
			try
			{
				Intent newIntent = new Intent(context, MainActivity.class);
				newIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				context.startActivity(newIntent);
			}
			catch (ActivityNotFoundException ex)
			{
				/* it seems some devices, even though they come with Android 4,
				 * don't have the VPN components built into the system image.
				 * com.android.vpndialogs/com.android.vpndialogs.ConfirmDialog
				 * will not be found then */
//				showVpnNotSupportedError();
			}
		}

		/* cached list of profiles used as backend for the ListView */
		List<VpnProfile> mVpnProfiles = mDataSource.getAllVpnProfiles();
		if (mVpnProfiles.size() > 0){
			VpnProfile profile = mVpnProfiles.get(0);
			setNextProfile(profile);
		}
	}


	/*
	 * The libraries are extracted to /data/data/org.strongswan.android/...
	 * during installation.
	 */
	static
	{
		System.loadLibrary("crypto");
		System.loadLibrary("strongswan");
		System.loadLibrary("hydra");
		System.loadLibrary("charon");
		System.loadLibrary("ipsec");
		System.loadLibrary("androidbridge");
	}
}
