package com.stonybrook.replay.bean;

import java.util.ArrayList;
import java.util.HashMap;

public class UDPAppJSONInfoBean {
	
	private ArrayList<RequestSet> Q = null;
	// adrian: csPairs not needed in udp, change to clientPorts
	private ArrayList<Integer> clientPorts = null;
	private String replayName = null;
	private ApplicationBean appBean = null;

	public UDPAppJSONInfoBean() {
		Q = new ArrayList<RequestSet>();
		clientPorts = new ArrayList<Integer>();
		replayName = null;
		appBean = new ApplicationBean();
	}
	
	public ArrayList<RequestSet> getQ() {
		return Q;
	}
	
	public void setQ(ArrayList<RequestSet> q) {
		Q = q;
	}
	
	public ArrayList<Integer> getClientPorts() {
		return clientPorts;
	}
	
	public void setClientPorts(ArrayList<Integer> clientPorts) {
		this.clientPorts = clientPorts;
	}
	
	public String getReplayName() {
		return replayName;
	}
	
	public void setReplayName(String replayName) {
		this.replayName = replayName;
	}
	
	public ApplicationBean getAppBean() {
		return appBean;
	}
	
	public void setAppBean(ApplicationBean appBean) {
		this.appBean = appBean;
	}
		
}
