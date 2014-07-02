package com.stonybrook.replay;

import java.util.ArrayList;
import java.util.HashMap;

import uk.co.senab.photoview.PhotoViewAttacher;

import com.rgolani.replay.R;
import com.stonybrook.replay.adapter.CheckBoxListAdapter;
import com.stonybrook.replay.adapter.ImageCheckBoxListAdapter;
import com.stonybrook.replay.bean.ApplicationBean;
import com.stonybrook.replay.constant.ReplayConstants;
import com.stonybrook.replay.exception_handler.ExceptionHandler;
import com.stonybrook.replay.parser.JSONParser;
import com.stonybrook.replay.util.UnpickleDataStream;

import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Bundle;
import android.os.StrictMode;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.ListActivity;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.View;
import android.view.View.OnTouchListener;
import android.view.Window;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.Spinner;
import android.widget.Toast;

public class MainActivity extends Activity {

	//GridView on Main Screen
	GridView appList;
	Button nextButton, settingsButton;
	public HashMap<String, ApplicationBean> appsHashMap = null;
	Context context;

	public ArrayList<ApplicationBean> selectedApps = new ArrayList<ApplicationBean>();

	String server = null;
	String enableTiming = null;

	// Remove this
	// @SuppressLint("NewApi")
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		this.requestWindowFeature(Window.FEATURE_NO_TITLE);
		
		//Register with Global Exception hanndler
		Thread.setDefaultUncaughtExceptionHandler(new ExceptionHandler(this));
		
		setContentView(R.layout.activity_main_image);

		// In Android, Network cannot be done on Main thread. But Initially for testing purposes this hack was placed which allowed network usage on main thread
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
			if(!isNetworkAvailable())
			{
				new AlertDialog.Builder(this)
			    .setTitle("Network Error")
			    .setMessage("No Internet connection available. Try After connecting to Intenet.")
			    .setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
			        public void onClick(DialogInterface dialog, int which) { 
			        	MainActivity.this.finish();
			        }
			     })
			    .show();
			}
			context = MainActivity.this.getApplicationContext();

			//This method parses JSON file which contains details for different Applications and returns HashMap of ApplicationBean type 
			appsHashMap = JSONParser.parseAppJSON(context);
			
			//Main screen checkbox Adapter. This is populated from HashMap retrieved from above method
			ImageCheckBoxListAdapter adapter = new ImageCheckBoxListAdapter(appsHashMap, getLayoutInflater(), this);

			appList = (GridView) findViewById(R.id.appsListView);
			appList.setAdapter(adapter);

			//Settings of click listeners of buttons on Main Screen
			nextButton = (Button) findViewById(R.id.nextButton);
			nextButton.setOnClickListener(nextButtonClick);

			settingsButton = (Button) findViewById(R.id.settingsButton);
			settingsButton.setOnClickListener(settingsButtonclick);
		} catch (Exception ex) {
			Log.d(ReplayConstants.LOG_APPNAME, "Exception while parsing JSON file " + ReplayConstants.APPS_FILENAME);
			ex.printStackTrace();
		}
	}

	
	/**
	 * This method is executed when user clicks on settings button on main screen. Comments are added inline.
	 */
	OnClickListener settingsButtonclick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			//Creating dialog to display to use
			AlertDialog.Builder builder = new AlertDialog.Builder(MainActivity.this);
			builder.setTitle("Settings");
			
			/**
			 * Select which layout to use. For this dialog, settings_layout.xml is used.
			 * TODO: Layout needs some tweaking such that it can be made presentable to user
			 */
			View view = LayoutInflater.from(MainActivity.this).inflate(R.layout.settings_layout, null);
			builder.setView(view);
			
			//Set elements of dialog
			final Spinner spinnerTiming = (Spinner)view.findViewById(R.id.settings_timing);
			final Spinner spinnerServer = (Spinner)view.findViewById(R.id.settings_server);
			
			final EditText txtServer = (EditText)view.findViewById(R.id.settings_server_txt);
			
			/**
			 * This will be called when user presses OK button on the dialog. This will save user preferences.
			 * TODO: Here, user preference saving scope is only session based i.e. If user closes the application then all the saved preferences lost.
			 * Store this preferences globally. For this Shared preferences can be used which should be easy to do.
			 */
			builder.setPositiveButton(R.string.ok, new DialogInterface.OnClickListener() {
				@Override
				public void onClick(DialogInterface dialog, int id) {
					server = (String)spinnerServer.getSelectedItem();
					enableTiming = (String)spinnerTiming.getSelectedItem();
					if(!txtServer.getText().toString().trim().isEmpty())
						server = txtServer.getText().toString().trim();
					dialog.dismiss();
				}
			});

			/**
			 * Close dialog on click of close button.
			 */
			builder.setNegativeButton(R.string.cancel, new DialogInterface.OnClickListener() {
				@Override
				public void onClick(DialogInterface dialog, int id) {
					dialog.dismiss();
				}
			});

			//Create Dialog from DialogBuilder and display it to user
			builder.create().show();
		}
	};

	/**
	 * This method will be called when user clicks on the next button on main screen. This method redirects user to ReplayActivity page 
	 * which display users apps selected on main page.
	 */
	OnClickListener nextButtonClick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			
			//Check to see if user has selected at least one app from the list.
			if(selectedApps.size() == 0)
			{
				Toast.makeText(MainActivity.this, "Please select at least one application", 1).show();
				return;
			}
			
			//Create Intent for ReplayActivity and make data of selected apps by user available to ReplayActivity
			Intent intent = new Intent(MainActivity.this, ReplayActivity.class);
			intent.putParcelableArrayListExtra("selectedApps", selectedApps);

			//If user did not select anything from settings dialog then use default preferences and make this available to next activity i.e. ReplayActivity
			if(server == null)
				server = getResources().getStringArray(R.array.server)[0];
			
			if(enableTiming == null)
				enableTiming = getResources().getStringArray(R.array.timing)[0];
			
			intent.putExtra("server", server);
			intent.putExtra("timing", enableTiming);
			
			//Start ReplayActivity with slideIn animation.
			startActivity(intent);
			MainActivity.this.overridePendingTransition(R.anim.slide_in_right, R.anim.slide_out_left);
		}
	};

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.main, menu);
		return true;
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
	
}