package com.stonybrook.replay.adapter;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.CheckBox;
import android.widget.ImageView;
import android.widget.TextView;

import com.stonybrook.replay.MainActivity;
import com.stonybrook.replay.R;
import com.stonybrook.replay.bean.ApplicationBean;
import com.stonybrook.replay.constant.ReplayConstants;

public class ImageCheckBoxListAdapter extends BaseAdapter implements
		OnClickListener {

	/** The inflator used to inflate the XML layout */
	private LayoutInflater inflator;

	/** A list containing some sample data to show. */
	private List<ApplicationBean> dataList;
	private List<ApplicationBean> randomDataList;

	MainActivity mainAct;

	public ImageCheckBoxListAdapter(HashMap<String, ApplicationBean> apps,
			HashMap<String, ApplicationBean> random, LayoutInflater inflator,
			MainActivity mainAct) {
		super();
		this.inflator = inflator;
		this.mainAct = mainAct;
		dataList = new ArrayList<ApplicationBean>();
		randomDataList = new ArrayList<ApplicationBean>();

		for (String s : apps.keySet()) {
			// make sure dataList and randomDataList have the same order
			dataList.add(apps.get(s));
			randomDataList.add(random.get(s + "_random"));
		}

	}

	@Override
	public int getCount() {
		return dataList.size();
	}

	@Override
	public Object getItem(int position) {
		return dataList.get(position);
	}

	public Object getRandomItem(int position) {
		return randomDataList.get(position);
	}

	@Override
	public long getItemId(int position) {
		return position;
	}

	@Override
	public View getView(int position, View view, ViewGroup viewGroup) {
		// We only create the view if its needed
		if (view == null) {
			view = inflator.inflate(R.layout.main_view_app_item_info_image,
					null);
			// Set the click listener for the checkbox
			// view.findViewById(R.id.isSelectedCheckBox).setOnClickListener(this);
			view.setOnClickListener(this);
		}

		ApplicationBean app[] = new ApplicationBean[2];
		// app[0] is normal json, app[1] is random json
		app[0] = (ApplicationBean) getItem(position);
		app[1] = (ApplicationBean) getRandomItem(position);

		Log.d("Item", "app name: " + app[0].name + ", random app name: "
				+ app[1].name);
		// Set the example text and the state of the checkbox
		// com.gc.materialdesign.views.CheckBox cb =
		// (com.gc.materialdesign.views.CheckBox)
		// view.findViewById(R.id.isSelectedCheckBox);
		CheckBox cb = (CheckBox) view.findViewById(R.id.isSelectedCheckBox);
		cb.setChecked(app[0].isSelected());
		if (app[0].isSelected() && !mainAct.selectedApps.contains(app[0])) {
			mainAct.selectedApps.add(app[0]);
			mainAct.selectedAppsRandom.add(app[1]);
		}
		// We tag the data object to retrieve it on the click listener.
		view.setTag(app);

		ImageView img = (ImageView) view.findViewById(R.id.appImageView);
		img.setImageDrawable(mainAct.getResources().getDrawable(
				mainAct.getResources().getIdentifier(app[0].getImage(),
						"drawable", mainAct.getPackageName())));
		img.setTag(app);

		TextView text = (TextView) view.findViewById(R.id.appNameTextView);
		text.setText(mainAct.getResources().getString(
				mainAct.getResources().getIdentifier(app[0].getName(),
						"string", mainAct.getPackageName())));

		return view;
	}

	/** Will be called when a checkbox has been clicked. */
	public void onClick(View view) {
		ApplicationBean[] bundle = (ApplicationBean[]) view.getTag();
		ApplicationBean data = bundle[0];
		ApplicationBean dataRandom = bundle[1];
		// data.setSelected(((CheckBox) view).isChecked());
		// com.gc.materialdesign.views.CheckBox c =
		// (com.gc.materialdesign.views.CheckBox)
		// view.findViewById(R.id.isSelectedCheckBox);
		CheckBox c = (CheckBox) view.findViewById(R.id.isSelectedCheckBox);
		if (mainAct.selectedApps.contains(data)) {
			c.setChecked(false);
			mainAct.selectedApps.remove(data);
			mainAct.selectedAppsRandom.remove(dataRandom);
		} else {
			c.setChecked(true);
			mainAct.selectedApps.add(data);
			mainAct.selectedAppsRandom.add(dataRandom);
		}

		Log.d(ReplayConstants.LOG_APPNAME,
				String.valueOf(mainAct.selectedApps.size()));
	}
}
