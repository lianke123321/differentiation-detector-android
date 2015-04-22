package com.stonybrook.replay;

import android.os.Bundle;
import android.support.v7.app.ActionBarActivity;
import android.support.v7.widget.Toolbar;
import android.widget.TextView;

public class CrashActivity extends ActionBarActivity {

	TextView ErrorMsgTextView = null;
	private String error;
	Toolbar toolbar;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_crash);
		toolbar = (Toolbar) findViewById(R.id.crash_bar);
		setSupportActionBar(toolbar);
		getSupportActionBar().setTitle(getResources().getString(R.string.errMsgTitle));
		
		this.error = getIntent().getStringExtra("error");
		/*this.ErrorMsgTextView = (TextView) findViewById(R.id.report);

		//SpannableString spanString = new SpannableString(error);

		this.ErrorMsgTextView.setText(error);
		this.ErrorMsgTextView
				.setTextColor(getResources().getColor(R.color.red));*/
	}
	
	/*@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if (keyCode == KeyEvent.KEYCODE_BACK) {
			CrashActivity.this.moveTaskToBack(true);
			CrashActivity.this.finish();
			android.os.Process.killProcess(android.os.Process.myPid());
			System.exit(0);
		}

		return super.onKeyDown(keyCode, event);

	}*/

}
