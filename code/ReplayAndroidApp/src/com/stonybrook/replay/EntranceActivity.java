package com.stonybrook.replay;

import java.util.Iterator;
import java.util.Locale;

import org.json.JSONArray;
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
		setContentView(R.layout.activity_entrance);

		toolbar = (Toolbar) findViewById(R.id.entrance_bar);
		setSupportActionBar(toolbar);

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
			// EntranceActivity.this.finish();
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
			// Set<String> results = settings.getStringSet("lastResult", null);
			try {
				JSONObject resultsWithDate = new JSONObject(settings.getString(
						"lastResult", "{}"));

				String finalResult = "";

				// if (results != null && !results.isEmpty()) {
				if (resultsWithDate.length() > 0) {
					Log.d("EntranceActivity",
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
								Log.w("EntranceActivity",
										"diff has abnormal value");
							}
						}
					}

					// display processed results
					tv.setText(finalResult);
				} else {
					Log.d("EntranceActivity", "No result available");
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
		}

	};
}
