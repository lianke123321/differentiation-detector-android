package com.stonybrook.replay;

import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.support.v7.app.ActionBarActivity;
import android.support.v7.widget.Toolbar;
import android.view.View;
import android.view.View.OnClickListener;

import com.gc.materialdesign.views.Button;

public class EntranceActivity extends ActionBarActivity {

	Button historyButton, startButton;
	Toolbar toolbar;

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
			new AlertDialog.Builder(EntranceActivity.this,
					AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
					.setTitle("Not Supported Yet")
					.setMessage("This function is still under developing!")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								@Override
								public void onClick(DialogInterface dialog,
										int which) {
									// nothing
								}
							}).show();
		}

	};
}
