package com.stonybrook.replay;

import android.app.Activity;
import android.os.Bundle;
import android.view.Menu;
import android.view.Window;
import android.widget.TextView;

public class CrashActivity extends Activity {

	TextView ErrorMsgTextView = null;
	private String error;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		this.requestWindowFeature(Window.FEATURE_NO_TITLE);
		setContentView(R.layout.activity_crash);
		this.error = getIntent().getStringExtra("error");
		/*this.ErrorMsgTextView = (TextView) findViewById(R.id.report);

		//SpannableString spanString = new SpannableString(error);

		this.ErrorMsgTextView.setText(error);
		this.ErrorMsgTextView
				.setTextColor(getResources().getColor(R.color.red));*/
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.crash, menu);
		return true;
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
