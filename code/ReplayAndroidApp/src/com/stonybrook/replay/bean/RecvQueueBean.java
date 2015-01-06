package com.stonybrook.replay.bean;

public class RecvQueueBean {
	public volatile int queue;
	public volatile int current;

	public RecvQueueBean() {
		super();
		this.queue = 0;
		this.current = 0;
	}
	
	
}
