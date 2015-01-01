package com.stonybrook.replay.combined;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.math.BigInteger;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketException;
import java.util.ArrayList;
import java.util.Queue;

import com.stonybrook.replay.bean.SocketInstance;

import android.util.Log;

public final class CombinedNotifierThread implements Runnable{

	private int senderCount = 0;
	private int objLen = 10;
	private int bufSize = 4096;
	ArrayList<String> closeQ = new ArrayList<String>();
	Socket socket = null;
	DataOutputStream dataOutputStream = null;
	DataInputStream dataInputStream = null;
	
	public CombinedNotifierThread(int senderCount, Socket socket) {
		super();
		this.senderCount = senderCount;
		this.socket = socket;
		
		if (!this.socket.isConnected()) {
			Log.d("Notifier", "socket not connected!");
			return;
		}
		
		try {
			dataOutputStream = new DataOutputStream(this.socket.getOutputStream());
			dataInputStream = new DataInputStream(this.socket.getInputStream());
		} catch (SocketException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	@Override
	public void run() {
		while (senderCount > 0) {
			byte[] data;
			try {
				data = receiveObject(objLen);
				String[] Notf = new String(data).split(";");
				if (Notf[0].equalsIgnoreCase("DONE")) {
					senderCount -= 1;
					closeQ.add(Notf[1]);
				} else {
					Log.d("Notifier", "received unknown message!");
					break;
				}
			} catch (Exception e) {
				Log.d("Notifier", "receive data error!");
				e.printStackTrace();
			}
			Log.d("Notifier", "current senderCount: " + senderCount);
		}
	}
	
	public byte[] receiveObject(int objLen) throws Exception{
		byte[] recvObjSizeBytes = receiveKbytes(objLen);
		//Log.d("Obj", new String(recvObjSizeBytes));
		int recvObjSize = (new BigInteger(new String(recvObjSizeBytes))).intValue();
		//Log.d("Obj", String.valueOf(recvObjSize));
		return receiveKbytes(recvObjSize);
	}
	
	public byte[] receiveKbytes(int k) throws Exception{
    	int totalRead = 0;
    	byte[] b = new byte[k];
		while (totalRead < k) {
			int bytesRead = dataInputStream.read(b, totalRead, Math.min(k - totalRead, bufSize));
			if (bytesRead < 0) {
				throw new IOException("Data stream ended prematurely");
			}
			/*if (k - totalRead < bytesRead)
				bytesRead = k - totalRead;*/
			totalRead += bytesRead;
		}
		return b;
    }

}
