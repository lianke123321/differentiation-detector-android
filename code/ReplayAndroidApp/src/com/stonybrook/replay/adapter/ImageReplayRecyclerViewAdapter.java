package com.stonybrook.replay.adapter;

import java.util.List;

import android.graphics.Color;
import android.graphics.Typeface;
import android.support.v7.widget.RecyclerView;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import com.stonybrook.replay.R;
import com.stonybrook.replay.ReplayActivity;
import com.stonybrook.replay.bean.ApplicationBean;

public class ImageReplayRecyclerViewAdapter extends
		RecyclerView.Adapter<ImageReplayRecyclerViewAdapter.ViewHolder> {

	/** The inflater used to inflate the XML layout */
	// private LayoutInflater inflator;

	/** A list containing some sample data to show. */
	List<ApplicationBean> dataList;
	ReplayActivity mainAct;
	int replay_iteration;

	public static class ViewHolder extends RecyclerView.ViewHolder {
		// each data item is just a string in this case
		public TextView tvAppSize;
		public TextView tvAppTime;
		public TextView tvAppStatus;
		public TextView tvSlower;
		public TextView tvPercent;
		public ImageView img;

		public ViewHolder(View view) {
			super(view);
			tvSlower = (TextView) view.findViewById(R.id.slowerTextView);
			tvPercent = (TextView) view.findViewById(R.id.percentTextView);
			tvAppSize = (TextView) view.findViewById(R.id.appSize);
			tvAppTime = (TextView) view.findViewById(R.id.appTime);
			tvAppStatus = (TextView) view.findViewById(R.id.appStatusTextView);
			img = (ImageView) view.findViewById(R.id.appImageView);
		}
	}

	// Provide a suitable constructor (depends on the kind of dataset)
	public ImageReplayRecyclerViewAdapter(List<ApplicationBean> list,
			ReplayActivity mainAct, int iteration, boolean doRandom) {
		this.mainAct = mainAct;
		this.dataList = list;
		// for each iteration there are two or three replays
		this.replay_iteration = doRandom? iteration * 3 : iteration * 2;
	}

	@Override
	public int getItemCount() {
		return dataList.size();
	}

	@Override
	public void onBindViewHolder(ViewHolder holder, int position) {
		final ApplicationBean app = (ApplicationBean) dataList.get(position);

		holder.tvAppSize.setText(String.valueOf(app.getSize()) + " MB (x"
				+ replay_iteration + ")");
		holder.tvAppTime
				.setText(app.getTime() + " (x" + replay_iteration + ")");
		holder.tvAppStatus.setText(app.status);

		// here we set different color for different results
		// TODO: These strings are hard-coded. Change it
		if (app.status.trim().equalsIgnoreCase("Inconclusive Result")) {
			// yellow and normal
			holder.tvAppStatus.setTypeface(null, Typeface.NORMAL);
			holder.tvAppStatus.setTextColor(Color.parseColor("#DAA520"));

			holder.tvSlower.setVisibility(View.GONE);
			holder.tvPercent.setVisibility(View.GONE);
		} else if (app.status.trim().equalsIgnoreCase("No Differentiation")) {
			// green and normal
			holder.tvAppStatus.setTypeface(null, Typeface.NORMAL);
			holder.tvAppStatus.setTextColor(Color.parseColor("#228B22"));
			
			holder.tvSlower.setVisibility(View.GONE);
			holder.tvPercent.setVisibility(View.GONE);
		} else if (app.status.trim().equalsIgnoreCase(
				"Differentiation Detected")) {
			// red and bold
			holder.tvAppStatus.setTypeface(null, Typeface.BOLD);
			holder.tvAppStatus.setTextColor(Color.parseColor("#B22222"));
			
			holder.tvSlower.setVisibility(View.VISIBLE);
			holder.tvPercent.setVisibility(View.VISIBLE);
		} else if (app.status.trim().equalsIgnoreCase(
				"Traffic Manipulation Detected (Type 1)")) {
			holder.tvAppStatus.setTypeface(null, Typeface.BOLD);
			holder.tvAppStatus.setTextColor(Color.parseColor("#B22222"));
			
			holder.tvSlower.setVisibility(View.GONE);
			holder.tvPercent.setVisibility(View.GONE);
		} else {
			holder.tvAppStatus.setTypeface(null, Typeface.NORMAL);
			holder.tvAppStatus.setTextColor(Color.parseColor("#4682B4"));
			
			holder.tvSlower.setVisibility(View.GONE);
			holder.tvPercent.setVisibility(View.GONE);
		}

		double rate = app.rate;
		holder.tvPercent
				.setText(String.valueOf((int) Math.abs(app.rate * 100)) + "%");
		if (rate < 0) {
			holder.tvSlower.setText("faster");
		} else {
			holder.tvSlower.setText("slower");
		}

		Log.d("img", app.getImage());
		holder.img.setImageDrawable(mainAct.getResources().getDrawable(
				mainAct.getResources().getIdentifier(app.getImage(),
						"drawable", mainAct.getPackageName())));
	}

	@Override
	public ImageReplayRecyclerViewAdapter.ViewHolder onCreateViewHolder(
			ViewGroup parent, int viewType) {
		// View view =
		// inflator.from(parent.getContext()).inflate(R.layout.replay_main_layout_images,
		// null);
		View view = LayoutInflater.from(parent.getContext()).inflate(
				R.layout.replay_view_app_item_info_image, parent, false);
		//view.setBackgroundResource(R.drawable.listitem);
		ViewHolder vh = new ViewHolder(view);
		//Log.d("Adapter", "created holder");
		return vh;
	}
}
