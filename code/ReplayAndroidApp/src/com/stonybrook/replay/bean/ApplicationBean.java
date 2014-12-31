package com.stonybrook.replay.bean;

import android.os.Parcel;
import android.os.Parcelable;

public class ApplicationBean implements Parcelable {
	public String name = null;
	public String configfile = null;
	private String dataFile = null;
	private double size;
	private boolean isSelected = false;
	private String image = null;
	java.util.Queue<RequestSet> queue = null;
	public boolean isProgressStarted = false;
	public String status = "Pending";
	public String resultImg = null;
	public String time = null;
	
	public String getTime() {
		return time;
	}

	public void setTime(String time) {
		this.time = time;
	}

	private String type = null;
	
	public String getType() {
		return type;
	}

	public void setType(String type) {
		this.type = type;
	}

	public String getImage() {
		return image;
	}

	public void setImage(String image) {
		this.image = image;
	}

	public java.util.Queue<RequestSet> getQueue() {
		return queue;
	}

	public void setQueue(java.util.Queue<RequestSet> queue) {
		this.queue = queue;
	}

	public ApplicationBean() {
	}
	
	public String getName() {
		return name;
	}

	public String getConfigfile() {
		return configfile;
	}

	public void setConfigfile(String configfile) {
		this.configfile = configfile;
	}

	public String getDataFile() {
		return dataFile;
	}

	public void setDataFile(String dataFile) {
		this.dataFile = dataFile;
	}

	public double getSize() {
		return size;
	}

	public void setSize(double size) {
		this.size = size;
	}

	public void setName(String name) {
		this.name = name;
	}

	public boolean isSelected() {
		return isSelected;
	}

	public void setSelected(boolean isSelected) {
		this.isSelected = isSelected;
	}

	@Override
	public int describeContents() {
		// TODO Auto-generated method stub
		return 0;
	}

	@Override
	public void writeToParcel(Parcel dest, int flags) {
		dest.writeString(name);
		dest.writeString(configfile);
		dest.writeString(dataFile);
		dest.writeDouble(size);
		dest.writeBooleanArray(new boolean[] { isSelected });
		dest.writeString(image);
		dest.writeString(type);
		dest.writeString(time);
	}

	public static final Parcelable.Creator<ApplicationBean> CREATOR = new Parcelable.Creator<ApplicationBean>() {
		public ApplicationBean createFromParcel(Parcel in) {
			return new ApplicationBean(in);
		}

		public ApplicationBean[] newArray(int size) {
			return new ApplicationBean[size];
		}
	};
	
	  private ApplicationBean(Parcel in) {
	         name = in.readString();
	         configfile = in.readString();
	         dataFile = in.readString();
	         size = in.readDouble();
	         boolean[] arr = new boolean[1];
	         in.readBooleanArray(arr);
	         isSelected = arr[0];
	         image = in.readString();
	         type = in.readString();
	         time = in.readString();
	     }

}
