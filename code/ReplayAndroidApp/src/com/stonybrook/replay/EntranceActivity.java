package com.stonybrook.replay;

import java.util.Iterator;
import java.util.Set;

import org.json.JSONException;
import org.json.JSONObject;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.support.v7.app.ActionBarActivity;
import android.support.v7.widget.Toolbar;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.gc.materialdesign.views.Button;

public class EntranceActivity extends ActionBarActivity {

	Button historyButton, startButton;
	Toolbar toolbar;

	// for retrieving history result
	private SharedPreferences settings;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		// this.requestWindowFeature(Window.FEATURE_NO_TITLE);
		setContentView(R.layout.activity_entrance);

		toolbar = (Toolbar) findViewById(R.id.entrance_bar);
		setSupportActionBar(toolbar);
		toolbar.setTitleTextColor(0xFFFFFFFF);

		historyButton = (Button) findViewById(R.id.historyButton);
		historyButton.setOnClickListener(historyButtOnClick);
		startButton = (Button) findViewById(R.id.startButton);
		startButton.setOnClickListener(startButtOnClick);

		settings = getSharedPreferences(ReplayActivity.STATUS,
				Context.MODE_PRIVATE);
	}

	OnClickListener startButtOnClick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			Intent intent = new Intent();
			intent.setClass(EntranceActivity.this, MainActivity.class);
			startActivity(intent);
			EntranceActivity.this.overridePendingTransition(
					R.anim.slide_in_right, R.anim.slide_out_left);
			EntranceActivity.this.finish();
		}

	};

	OnClickListener historyButtOnClick = new OnClickListener() {

		@Override
		public void onClick(View v) {
			// Creating dialog to display to use
			AlertDialog.Builder builder = new AlertDialog.Builder(
					EntranceActivity.this,
					AlertDialog.THEME_DEVICE_DEFAULT_LIGHT);
			builder.setTitle("Previous Results");

			View view = LayoutInflater.from(EntranceActivity.this).inflate(
					R.layout.history_layout,
					(RelativeLayout) findViewById(R.layout.activity_entrance));
			builder.setView(view);
			TextView tv = (TextView) view.findViewById(R.id.historyTextview);

			// get results
			Set<String> results = settings.getStringSet("lastResult", null);
			String finalResult = "";
			if (results != null && !results.isEmpty()) {
				Log.d("EntranceActivity",
						"Retrieve results succeeded! results: "
								+ results.toString());
				Iterator<String> it = results.iterator();
				while (it.hasNext()) {
					try {
						JSONObject response = new JSONObject(it.next());
						String replayName = response.getString("replayName");
						int diff = response.getInt("diff");
						double rate = response.getDouble("rate");

						if (diff == -1) {
							finalResult += (replayName + ":\n    no differentiation\n\n");
						} else if (diff == 0) {
							finalResult += (replayName + ":\n    inconclusive result\n\n");
						} else if (diff == 1) {
							String speed = rate < 0 ? "faster" : "slower";
							String processedRate = String.valueOf((int) Math
									.abs(rate * 100)) + "% ";
							finalResult += (replayName
									+ ":\n    differentiation detected, "
									+ processedRate + speed + "\n\n");
						} else {

						}
					} catch (JSONException e) {
						Log.e("EntranceActivity", "parsing json error");
						e.printStackTrace();
					}
				}

				// Set elements of dialog
				tv.setText(finalResult);
			} else {
				Log.d("EntranceActivity", "No result available");
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
		}

	};
}
