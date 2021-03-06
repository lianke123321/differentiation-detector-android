/*
 * Copyright (C) 2012 Tobias Brunner
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

package com.stonybrook.android.ui;

import android.app.Activity;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;

import mobi.meddle.diffdetector.R;

public class LogActivity extends Activity
{
	@Override
	public void onCreate(Bundle savedInstanceState)
	{
		super.onCreate(savedInstanceState);
		setContentView(R.layout.log_activity);

		getActionBar().setDisplayHomeAsUpEnabled(true);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu)
	{
		//getMenuInflater().inflate(R.menu.log, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item)
	{
		switch (item.getItemId())
		{
			case android.R.id.home:
				finish();
				return true;
			/*case R.id.menu_send_log:
				File logfile = new File(getFilesDir(), CharonVpnService.LOG_FILE);
				if (!logfile.exists() || logfile.length() == 0)
				{
					Toast.makeText(this, getString(R.string.empty_log), Toast.LENGTH_SHORT).show();
					return true;
				}

				String version = "";
				try
				{
					version = getPackageManager().getPackageInfo(getPackageName(), 0).versionName;
				}
				catch (NameNotFoundException e)
				{
					e.printStackTrace();
				}

				Intent intent = new Intent(Intent.ACTION_SEND);
				intent.putExtra(Intent.EXTRA_EMAIL, new String[] { MainActivity.CONTACT_EMAIL });
				intent.putExtra(Intent.EXTRA_SUBJECT, String.format(getString(R.string.log_mail_subject), version));
				intent.setType("text/plain");
				intent.putExtra(Intent.EXTRA_STREAM, LogContentProvider.createContentUri());
				startActivity(Intent.createChooser(intent, getString(R.string.send_log)));
				return true;*/
		}
		return super.onOptionsItemSelected(item);
	}
}
