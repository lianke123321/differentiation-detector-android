package com.stonybrook.replay.adapter;

import java.util.List;

import android.graphics.Color;
import android.graphics.Typeface;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import com.stonybrook.replay.R;
import com.stonybrook.replay.ReplayActivity;
import com.stonybrook.replay.bean.ApplicationBean;

public class ImageReplayListAdapter extends BaseAdapter {
	/** The inflator used to inflate the XML layout */
	private LayoutInflater inflator;

	/** A list containing some sample data to show. */
	private List<ApplicationBean> dataList;

	ReplayActivity mainAct;

	public ImageReplayListAdapter(List<ApplicationBean> list,
			LayoutInflater inflator, ReplayActivity mainAct) {
		super();
		this.inflator = inflator;
		this.mainAct = mainAct;
		dataList = list;
	}

	@Override
	public int getCount() {
		return dataList.size();
	}

	@Override
	public Object getItem(int position) {
		return dataList.get(position);
	}

	@Override
	public long getItemId(int position) {
		return position;
	}

	@Override
	public View getView(int position, View view, ViewGroup viewGroup) {
		// We only create the view if its needed
		if (view == null) {
			view = inflator.inflate(R.layout.replay_view_app_item_info_image,
					null);
			// Set the click listener for the checkbox
			// view.findViewById(R.id.isSelectedCheckBox).setOnClickListener(this);
		}
		final ApplicationBean app = (ApplicationBean) getItem(position);

		TextView tv;/*
					 * = (TextView) view.findViewById(R.id.appNameTextView);
					 * tv.setText(app.getName());
					 */
		TextView tv1 = (TextView) view.findViewById(R.id.slowerTextView);
		TextView tv2 = (TextView) view.findViewById(R.id.percentTextView);

		tv = (TextView) view.findViewById(R.id.appSize);
		tv.setText(String.valueOf(app.getSize()) + " MB");

		tv = (TextView) view.findViewById(R.id.appTime);
		tv.setText(String.valueOf(app.getTime()));

		tv = (TextView) view.findViewById(R.id.appStatusTextView);
		tv.setText(app.status);
		
		// here we set different color for different results
		// TODO: These strings are hard-coded. Change it
		if (app.status.trim().equalsIgnoreCase("Inconclusive Result")) {
			// yellow and normal
			tv.setTypeface(null, Typeface.NORMAL);
			tv.setTextColor(Color.parseColor("#DAA520"));
			
			tv1.setVisibility(View.GONE);
			tv2.setVisibility(View.GONE);
		} else if (app.status.trim().equalsIgnoreCase("No Differentiation")) {
			// green and normal
			tv.setTypeface(null, Typeface.NORMAL);
			tv.setTextColor(Color.parseColor("#228B22"));
		} else if (app.status.trim().equalsIgnoreCase("Differentiation Detected")) {
			// red and bold
			tv.setTypeface(null, Typeface.BOLD);
			tv.setTextColor(Color.parseColor("#B22222"));
			tv1.setVisibility(View.VISIBLE);
			tv2.setVisibility(View.VISIBLE);
		} else if (app.status.trim().equalsIgnoreCase("IP Flipping Detected")) {
			tv.setTypeface(null, Typeface.BOLD);
			tv.setTextColor(Color.parseColor("#B22222"));
		} else {
			tv.setTypeface(null, Typeface.NORMAL);
			tv.setTextColor(Color.parseColor("#4682B4"));
		}
				
		double rate = app.rate;
		tv2.setText(String.valueOf((int)Math.abs(app.rate * 100)) + "%");
		if (rate < 0) {
			tv1.setText("faster");
		} else {
			tv1.setText("slower");
		}
		

		/*ProgressBar progress = (ProgressBar) view
				.findViewById(R.id.appProgress);
		ImageButton button = (ImageButton) view.findViewById(R.id.appResultBtn);

		if (app.status.equalsIgnoreCase(mainAct.getResources().getString(
				R.string.finish_vpn))) {
			progress.setVisibility(ProgressBar.GONE);
			progress.setProgress(0);
			button.setVisibility(Button.VISIBLE);

			button.setOnClickListener(new OnClickListener() {

				@Override
				public void onClick(View v) {
					AlertDialog.Builder builder = new AlertDialog.Builder(
							mainAct);
					builder.setTitle("Results of " + app.getName());
					View view = LayoutInflater.from(mainAct).inflate(
							R.layout.replay_result_layout, null);
					ImageView image = (ImageView) view
							.findViewById(R.id.resultDialogImg);

					*//**
					 * Not sure about the license of PhotoViewAttacher TODO :
					 * look into the license of this and decide whether to use
					 * it or not.
					 *//*

					image.setImageDrawable(mainAct.getResources().getDrawable(
							mainAct.getResources().getIdentifier(app.resultImg,
									"drawable", mainAct.getPackageName())));
					PhotoViewAttacher mAttacher = new PhotoViewAttacher(image);
					mAttacher.update();
					// builder.setIcon(mainAct.getResources().getDrawable(mainAct.getResources().getIdentifier(app.getImage(),
					// "drawable", mainAct.getPackageName())));
					builder.setView(view);
					builder.setPositiveButton(R.string.ok,
							new DialogInterface.OnClickListener() {
								@Override
								public void onClick(DialogInterface dialog,
										int id) {
									// User clicked OK. Start a new game.
									dialog.dismiss();
								}
							});

					builder.create().show();

				}
			});
		} else if (app.status.equalsIgnoreCase(mainAct.getResources()
				.getString(R.string.processing))
				|| app.status.equalsIgnoreCase(mainAct.getResources()
						.getString(R.string.vpn))) {
			progress.setVisibility(ProgressBar.VISIBLE);
			button.setVisibility(Button.GONE);
		} else {
			progress.setVisibility(ProgressBar.INVISIBLE);
			progress.setProgress(0);
			button.setVisibility(Button.GONE);
		}*/

		ImageView img = (ImageView) view.findViewById(R.id.appImageView);

		Log.d("img", app.getImage());

		img.setImageDrawable(mainAct.getResources().getDrawable(
				mainAct.getResources().getIdentifier(app.getImage(),
						"drawable", mainAct.getPackageName())));

		return view;
	}

}
