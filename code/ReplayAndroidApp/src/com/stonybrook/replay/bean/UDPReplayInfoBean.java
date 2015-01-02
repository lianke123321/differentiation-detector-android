package com.stonybrook.replay.bean;

import java.net.DatagramSocket;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.Queue;

public class UDPReplayInfoBean {
	
	private ArrayList<DatagramSocket> udpSocketList = new ArrayList<DatagramSocket>();
	private int senderCount = 0;
	private Queue<String> closeQ = new LinkedList<String>();
	
	public synchronized Queue<String> getCloseQ() {
		return closeQ;
	}

	public synchronized void setCloseQ(Queue<String> closeQ) {
		this.closeQ = closeQ;
	}

	public synchronized ArrayList<DatagramSocket> getUdpSocketList() {
		return udpSocketList;
	}
	
	public synchronized void setUdpSocketList(ArrayList<DatagramSocket> udpSocketList) {
		this.udpSocketList = udpSocketList;
	}
	
	public synchronized int getSenderCount() {
		return senderCount;
	}
	
	public synchronized void setSenderCount(int senderCount) {
		this.senderCount = senderCount;
	}
	
	public synchronized void decrement() {
		senderCount -= 1;
	}
	
	public synchronized void addSocket(DatagramSocket socket) {
		udpSocketList.add(socket);
	}
	
	public synchronized void offerCloseQ (String str) {
		closeQ.offer(str);
	}
	
	public synchronized String pollCloseQ() {
		return closeQ.poll();
	}
	
}
