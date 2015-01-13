package com.stonybrook.replay.combined;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.math.BigInteger;
import java.net.Socket;
import java.net.SocketException;

import android.util.Log;

import com.stonybrook.replay.bean.UDPReplayInfoBean;

public final class CombinedNotifierThread implements Runnable {

	// private int senderCount = 0;
	UDPReplayInfoBean udpReplayInfoBean = null;
	private int objLen = 10;
	private int bufSize = 4096;
	// ArrayList<String> closeQ = new ArrayList<String>();
	Socket socket = null;
	DataOutputStream dataOutputStream = null;
	DataInputStream dataInputStream = null;
	// changes of Arash
	public boolean doneSending;
	private int inProcess = 0;
	private int total = 0;

	public CombinedNotifierThread(UDPReplayInfoBean udpReplayInfoBean,
			Socket socket) {
		super();
		// this.senderCount = senderCount;
		this.udpReplayInfoBean = udpReplayInfoBean;
		this.socket = socket;
		this.doneSending = false;

		if (!this.socket.isConnected()) {
			Log.d("Notifier", "socket not connected!");
			return;
		}

		try {
			dataOutputStream = new DataOutputStream(
					this.socket.getOutputStream());
			dataInputStream = new DataInputStream(this.socket.getInputStream());
		} catch (SocketException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	@Override
	public void run() {
		while (true) {
			byte[] data;

			try {
				if (dataInputStream.available() > 0) {
					data = receiveObject(objLen);
					String[] Notf = new String(data).split(";");
					if (Notf[0].equalsIgnoreCase("STARTED")) {
						inProcess += 1;
						total += 1;
						// udpReplayInfoBean.decrement();
						// udpReplayInfoBean.offerCloseQ(Notf[1]);
						// Log.d("Notifier", "Notf[1] " + Notf[1]);
						// closeQ.add(Notf[1]);
					} else if (Notf[0].equalsIgnoreCase("DONE")) {
						inProcess -= 1;
					} else {
						Log.d("Notifier", "WTF???");
						break;
					}
				}
			} catch (Exception e) {
				Log.d("Notifier", "receive data error!");
				e.printStackTrace();
			}

			if (doneSending) {
				if (inProcess == 0) {
					Log.d("Notifier",
							"Done notifier! total: " + total
									+ " udpSenderCount: "
									+ udpReplayInfoBean.getSenderCount());
					break;
				}
			}
		}

		Log.d("Notifier", "received all packets!");

	}

	public byte[] receiveObject(int objLen) throws Exception {
		byte[] recvObjSizeBytes = receiveKbytes(objLen);
		// Log.d("Obj", new String(recvObjSizeBytes));
		int recvObjSize = (new BigInteger(new String(recvObjSizeBytes)))
				.intValue();
		// Log.d("Obj", String.valueOf(recvObjSize));
		return receiveKbytes(recvObjSize);
	}

	public byte[] receiveKbytes(int k) throws Exception {
		int totalRead = 0;
		byte[] b = new byte[k];
		while (totalRead < k) {
			int bytesRead = dataInputStream.read(b, totalRead,
					Math.min(k - totalRead, bufSize));
			if (bytesRead < 0) {
				throw new IOException("Data stream ended prematurely");
			}
			/*
			 * if (k - totalRead < bytesRead) bytesRead = k - totalRead;
			 */
			totalRead += bytesRead;
		}
		return b;
	}

}
