package mobi.meddle.diffdetector.bean;

import java.util.ArrayList;


public class JitterBean {
	
	public ArrayList<String> sentJitter;
	public ArrayList<byte[]> sentPayload;
	public ArrayList<String> rcvdJitter;
	public ArrayList<byte[]> rcvdPayload;
	
	public JitterBean() {
		super();
		this.sentJitter = new ArrayList<String>();
		this.sentPayload = new ArrayList<byte[]>();
		this.rcvdJitter = new ArrayList<String>();
		this.rcvdPayload = new ArrayList<byte[]>();
	}
	
}
