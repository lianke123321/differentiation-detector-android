package com.stonybrook.replay;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.os.Bundle;
import android.text.Html;
import android.view.Menu;
import android.view.View;
import android.view.Window;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import com.rgolani.replay.R;

public class ConsentFormActivity extends Activity {

	// @@@ this is consent form
	public static final String STATUS = "MyPrefsFile";
	Button agreeButton, disagreeButton;

	SharedPreferences settings;

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

			Intent intent = new Intent();
			intent.setClass(ConsentFormActivity.this, MainActivity.class);
			startActivity(intent);
			ConsentFormActivity.this.finish();
		}
	};

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
			.setNegativeButton("Exit", new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int which) { 
					ConsentFormActivity.this.finish();
				}
			})
			.show();
		}
	};
}
