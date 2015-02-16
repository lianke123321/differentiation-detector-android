package com.stonybrook.replay.bean;

public class UpdateUIBean {
	
	private int progress;
	
	public UpdateUIBean() {
		super();
		this.progress = 0;
	}

	public synchronized int getProgress() {
		return progress;
	}

	public synchronized void setProgress(int progress) {
		this.progress = progress;
	}
	
}
