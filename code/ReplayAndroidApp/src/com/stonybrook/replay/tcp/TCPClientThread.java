package com.stonybrook.replay.tcp;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.Channels;
import java.nio.channels.ReadableByteChannel;
import java.nio.channels.SocketChannel;
import java.util.concurrent.Semaphore;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;
import com.stonybrook.replay.util.UtilsManager;

public class TCPClientThread implements Runnable {

	private TCPClient client = null;
	private RequestSet RS = null;
	private TCPQueue queue = null;
	private Semaphore sema = null;
	long timeOrigin = 0;

	public TCPClientThread(TCPClient client, RequestSet RS, TCPQueue tcpQueue, Semaphore sema, long timeOrigin) {
		this.client = client;
		this.RS = RS;
		this.queue = tcpQueue;
		this.sema = sema;
		this.timeOrigin = timeOrigin;
	}

	/**
	 Steps:
        1- Send out the payload
        2- Set send_event to notify you are done sending
        3- Receive response (if any)
        4- Set self.event to notify you are done receiving
	 */
	@Override
	public void run() {
		DataOutputStream dataOutputStream = null;
		DataInputStream dataInputStream = null;
		try {

			if (client.socket == null || !client.socket.isConnected())
				client.createSocket();

			// Get Input/Output stream for socket
			dataOutputStream = new DataOutputStream(client.socket.getOutputStream());
			dataInputStream = new DataInputStream(client.socket.getInputStream());

			Log.d("Replay", "Sending payload for pair " + RS.getc_s_pair() + " " + RS.getResponse_len());

			
			dataOutputStream.write(UtilsManager.serialize(RS.getPayload())); //Data type for payload

			synchronized (queue) {
				queue.notifyAll();
			}

			// Notify waiting Queue thread to start processing next packet
			if (RS.getResponse_len() > 0) {
				Log.d("Response", "Waiting for response for pair " + RS.getc_s_pair() + " of " + RS.getResponse_len() + " bytes");

				int totalRead = 0;

				Log.d(String.valueOf(RS.getResponse_len()), "start " + String.valueOf(System.currentTimeMillis() - timeOrigin));
				
				int bufferSize = 1024*1024;
				if(RS.getResponse_len() < bufferSize)
					bufferSize = RS.getResponse_len();
				
				byte[] buffer = new byte[bufferSize];
				while (totalRead < RS.getResponse_len()) {
					int bytesRead = dataInputStream.read(buffer, 0, Math.min(RS.getResponse_len() - totalRead, bufferSize));
					if (bytesRead < 0) {
						throw new IOException("Data stream ended prematurely");
					}
					totalRead += bytesRead;
				}
				Log.d(String.valueOf(RS.getResponse_len()), "end " + String.valueOf(System.currentTimeMillis() - timeOrigin));
			}

			
		} catch (Exception e) {
			e.printStackTrace();
		} finally {
			sema.release();
			synchronized (queue) {
				--queue.threads;
			}

		}

	}

}
