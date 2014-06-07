package com.stonybrook.replay.adapter;

import java.util.List;

import uk.co.senab.photoview.PhotoViewAttacher;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.rgolani.replay.R;
import com.stonybrook.replay.ReplayActivity;
import com.stonybrook.replay.bean.ApplicationBean;

public class ReplayListAdapter extends BaseExpandableListAdapter{
	/** The inflator used to inflate the XML layout */
	private LayoutInflater inflator;

	/** A list containing some sample data to show. */
	private List<ApplicationBean> dataList;
	
	ReplayActivity mainAct;
	public ReplayListAdapter(List<ApplicationBean> list, LayoutInflater inflator, ReplayActivity mainAct) {
		super();
		this.inflator = inflator;
		this.mainAct = mainAct;
		dataList = list;
	}
	
	
	@Override
	public Object getChild(int arg0, int arg1) {
		//Change this if you want to pass something specific to the child
		return dataList.get(arg0);	
	}

	@Override
	public long getChildId(int arg0, int arg1) {
		return arg0;
	}

	@Override
	public View getChildView(final int groupPosition, final int childPosition,
            boolean isLastChild, View convertView, ViewGroup parent) {
		final ApplicationBean app = (ApplicationBean) getChild(groupPosition, childPosition);
        LayoutInflater inflater = mainAct.getLayoutInflater();
 
        if (convertView == null) {
            convertView = inflater.inflate(R.layout.replay_view_app_child_item_info, null);
        }
 
        TextView item = (TextView) convertView.findViewById(R.id.appSize);
        item.setText(String.valueOf(app.getSize()) + " MB");
        
        ProgressBar progress = (ProgressBar)convertView.findViewById(R.id.appProgress);
        Button button = (Button)convertView.findViewById(R.id.appResultBtn);
        if(app.status.equalsIgnoreCase(mainAct.getResources().getString(R.string.finished)))
        {
        	progress.setVisibility(ProgressBar.INVISIBLE);
        	button.setVisibility(Button.VISIBLE);
        	button.setOnClickListener(new OnClickListener() {
				
				@Override
				public void onClick(View v) {
					AlertDialog.Builder builder = new AlertDialog.Builder(mainAct);
					builder.setTitle("Results of " + app.getName());
					View view = LayoutInflater.from(mainAct).inflate(R.layout.replay_result_layout, null);
					ImageView image = (ImageView)view.findViewById(R.id.resultDialogImg);
					image.setImageDrawable(mainAct.getResources().getDrawable(mainAct.getResources().getIdentifier(app.resultImg, "drawable", mainAct.getPackageName())));
					PhotoViewAttacher mAttacher = new PhotoViewAttacher(image);
					mAttacher.update();
					builder.setIcon(mainAct.getResources().getDrawable(mainAct.getResources().getIdentifier(app.getImage(), "drawable", mainAct.getPackageName())));
					builder.setView(view);
					builder.setPositiveButton(R.string.ok, new DialogInterface.OnClickListener() {
					  @Override
					  public void onClick(DialogInterface dialog, int id) {
					    // User clicked OK.  Start a new game.
					    dialog.dismiss();
					  }
					});
					
					builder.create().show();
					
				}
			});
        }
        else if(app.status.equalsIgnoreCase(mainAct.getResources().getString(R.string.processing)) || 
        		app.status.equalsIgnoreCase(mainAct.getResources().getString(R.string.vpn)))
        {
        	progress.setVisibility(ProgressBar.VISIBLE);
        	button.setVisibility(Button.INVISIBLE);
        }
        else if(app.status.equalsIgnoreCase(mainAct.getResources().getString(R.string.error)))
        {
        	progress.setVisibility(ProgressBar.INVISIBLE);
        	button.setVisibility(Button.INVISIBLE);
        }
        else
        {
        	progress.setVisibility(ProgressBar.INVISIBLE);
        	button.setVisibility(Button.INVISIBLE);
        }
               
   
        return convertView;
	}

	@Override
	public int getChildrenCount(int arg0) {
		return 1;
	}

	@Override
	public Object getGroup(int groupPosition) {
		return dataList.get(groupPosition);
	}

	@Override
	public int getGroupCount() {
		return dataList.size();
	}

	@Override
	public long getGroupId(int groupPosition) {
		return groupPosition;
	}

	@Override
	public View getGroupView(int groupPosition, boolean isExpanded, View convertView, ViewGroup parent) {
        if (convertView == null) {
            LayoutInflater infalInflater = (LayoutInflater) mainAct.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            convertView = infalInflater.inflate(R.layout.replay_view_app_item_info, null);
        }
        ApplicationBean app = (ApplicationBean) getGroup(groupPosition);

		TextView tv = (TextView) convertView.findViewById(R.id.appNameTextView);
		tv.setText(app.getName());
		tv = (TextView) convertView.findViewById(R.id.appStatusTextView);
		tv.setText(app.status);
		
		ImageView img = (ImageView)convertView.findViewById(R.id.appImageView);
		Log.d("img", app.getImage());
		img.setImageDrawable(mainAct.getResources().getDrawable(mainAct.getResources().getIdentifier(app.getImage(), "drawable", mainAct.getPackageName())));
		
		return convertView;
	}

	@Override
	public boolean hasStableIds() {
		// TODO Auto-generated method stub
		return true;
	}

	@Override
	public boolean isChildSelectable(int groupPosition, int childPosition) {
		// TODO Auto-generated method stub
		return false;
	}

}
