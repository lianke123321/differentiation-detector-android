package com.stonybrook.replay.bean;

import java.util.ArrayList;


public class JitterBean {
	
	public ArrayList<String[]> sentJitter;
	public ArrayList<String[]> rcvdJitter;
	
	public JitterBean() {
		super();
		this.sentJitter = new ArrayList<String[]>();
		this.rcvdJitter = new ArrayList<String[]>();
	}
	
}
