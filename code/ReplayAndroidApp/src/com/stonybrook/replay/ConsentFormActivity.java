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
import android.os.AsyncTask;
import android.os.Bundle;
import android.security.KeyChain;
import android.text.Html;
import android.util.Base64;
import android.util.Log;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.Window;
import android.widget.Button;
import android.widget.TextView;

import com.stonybrook.android.data.TrustedCertificateEntry;
import com.stonybrook.android.data.VpnProfile;
import com.stonybrook.android.data.VpnProfileDataSource;
import com.stonybrook.android.data.VpnType;

public class ConsentFormActivity extends Activity {

	// @@@ this is consent form
	public static final String STATUS = "ConsentFormPrefsFile";
	Button agreeButton, disagreeButton;

	SharedPreferences settings;

	String gateway = "replay.meddle.mobi";

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		this.requestWindowFeature(Window.FEATURE_NO_TITLE);

		// Get "userAgreed" value. If the value doesn't exist yet false is
		// returned
		settings = getSharedPreferences(STATUS, Context.MODE_PRIVATE);
		boolean userAgreed = settings.getBoolean("userAgreed", false);
		if (userAgreed) {
			Intent intent = new Intent();
			intent.setClass(ConsentFormActivity.this, MainActivity.class);
			startActivity(intent);
			ConsentFormActivity.this.finish();
		}

		setContentView(R.layout.consent_form_layout);

		// Settings of click listeners of buttons on Main Screen
		agreeButton = (Button) findViewById(R.id.agreeBtn);
		agreeButton.setOnClickListener(agreeButtonClick);

		disagreeButton = (Button) findViewById(R.id.disagreeBtn);
		disagreeButton.setOnClickListener(disagreeButtonClick);

		// Set consent form content as HTML
		TextView consentText = (TextView) findViewById(R.id.consentForm);
		consentText.setText(Html.fromHtml(getResources().getString(
				R.string.consent_form)));

		// Set consent agree form content as HTML
		TextView consentAgreeText = (TextView) findViewById(R.id.consentFormCondition);
		consentAgreeText.setText(Html.fromHtml(getResources().getString(
				R.string.consent_form_condition)));
	}

	@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if ((keyCode == KeyEvent.KEYCODE_BACK)) {
			SharedPreferences settings = getSharedPreferences(
					ConsentFormActivity.STATUS, 0);
			Editor editor = settings.edit();
			editor.putBoolean("userAgreed", false);
			editor.commit();
			
			finish();
		}
		return super.onKeyDown(keyCode, event);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.main, menu);
		return true;
	}

	OnClickListener agreeButtonClick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			SharedPreferences settings = getSharedPreferences(
					ConsentFormActivity.STATUS, 0);
			Editor editor = settings.edit();
			editor.putBoolean("userAgreed", true);
			editor.commit();

			/*
			 * Intent intent = new Intent();
			 * intent.setClass(ConsentFormActivity.this, MainActivity.class);
			 * startActivity(intent); ConsentFormActivity.this.finish();
			 */

			new AlertDialog.Builder(ConsentFormActivity.this)
					.setTitle("PLEASE READ ME!!!")
					.setMessage(
							"We are going to install a certificate that allows our tests to run."
									+ "When asked for a password,\n\nLEAVE THE PASSWORD FIELD EMPTY\n\n"
									+ "and click \"OK\".\n\n"
									+ "After installing, please click \"Allow\" to allow our app to use it.")
					.setPositiveButton("Do not click me without reading the instruction!",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int which) {
									Log.d("ConsentForm",
											"proceed to install credential");
									// download credentials
									downloadAndInstallVpnCreds();
								}
							}).show();

		}

	};
	private TrustedCertificateEntry mUserCertEntry;
	private VpnProfile mProfile;
	private VpnProfileDataSource mDataSource;

	/**
	 * Gets VPN credentials and stores them in the VPN datastore
	 */
	private void downloadAndInstallVpnCreds() {

		// get reference to database for storing credentials
		Context context = this.getApplicationContext();
		mDataSource = new VpnProfileDataSource(context);
		mDataSource.open();

		// create VPN proile, fill it up and save it in the database
		mProfile = new VpnProfile();
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
			mUserCertEntry = new TrustedCertificateEntry(
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

	@Override
	protected void onActivityResult(int requestCode, int resultCode, Intent data) {

		// TODO check request code...
		String name = "Meddle Replay Server";

		// We want to use certs to avoid passwords
		VpnType mVpnType = VpnType.IKEV2_CERT;
		// TODO update the gateway used
		mProfile.setName(name.isEmpty() ? gateway : name);
		mProfile.setGateway(gateway);
		mProfile.setVpnType(mVpnType);

		if (mVpnType.getRequiresCertificate()) {
			mProfile.setUserCertificateAlias(mUserCertEntry.getAlias());
		}
		String certAlias = null;
		// String certAlias = mCheckAuto.isChecked() ? null :
		// mCertEntry.getAlias();
		mProfile.setCertificateAlias(certAlias);
		mProfile.setAutoReconnect(false);
		mDataSource.insertProfile(mProfile);

		Intent intent = new Intent();
		intent.setClass(ConsentFormActivity.this, MainActivity.class);
		startActivity(intent);
		ConsentFormActivity.this.finish();

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

	OnClickListener disagreeButtonClick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			SharedPreferences settings = getSharedPreferences(
					ConsentFormActivity.STATUS, 0);
			Editor editor = settings.edit();
			editor.putBoolean("userAgreed", false);
			editor.commit();
			new AlertDialog.Builder(ConsentFormActivity.this)
					.setTitle("Thank you!")
					.setMessage("Thank you for your support!")
					.setNegativeButton("Exit",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int which) {
									ConsentFormActivity.this.finish();
								}
							}).show();
		}
	};

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