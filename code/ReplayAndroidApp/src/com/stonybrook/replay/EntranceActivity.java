package com.stonybrook.replay;

import android.os.Bundle;
import android.support.v7.app.ActionBarActivity;
import android.support.v7.widget.Toolbar;

import com.gc.materialdesign.views.ButtonRectangle;

public class EntranceActivity extends ActionBarActivity {

	ButtonRectangle historyButton, intoReplayButton;
	Toolbar toolbar;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
//		this.requestWindowFeature(Window.FEATURE_NO_TITLE);
		setContentView(R.layout.activity_entrance);
		
		toolbar = (Toolbar) findViewById(R.id.app_bar);
		setSupportActionBar(toolbar);
		toolbar.setTitleTextColor(0xFFFFFFFF);
	}

}
