package com.stonybrook.replay.bean;

/**
 * @author rajesh RequestSet class for packet details
 */
public class RequestSet {
	public String c_s_pair;
	public int response_len;
	public byte[] payload;
	public double timestamp;
	// adrian: for udp
	public boolean end;
	
	// private int response_hash;

	public String getc_s_pair() {
		return c_s_pair;
	}

	public void setc_s_pair(String c_s_pair) {
		this.c_s_pair = c_s_pair;
	}

	public int getResponse_len() {
		return response_len;
	}

	public void setResponse_len(int response_len) {
		this.response_len = response_len;
	}

	public byte[] getPayload() {
		return payload;
	}

	public void setPayload(byte[] payload) {
		this.payload = payload;
	}

	public double getTimestamp() {
		return timestamp;
	}

	public void setTimestamp(double timestamp) {
		this.timestamp = timestamp;
	}
	
	public boolean getEnd() {
		return end;
	}
	
	public void setEnd(boolean end) {
		this.end = end;
	}

	@Override
	public String toString() {
		return "RequestSet [c_s_pair=" + c_s_pair + ", response_len="
				+ response_len + " , timestamp=" + timestamp + "]";
	}

}