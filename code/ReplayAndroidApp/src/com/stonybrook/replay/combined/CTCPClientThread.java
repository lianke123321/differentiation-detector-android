package com.stonybrook.replay.combined;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.util.concurrent.Semaphore;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;
// @@@ Adrian add this

public class CTCPClientThread implements Runnable {

	private CTCPClient client = null;
	private RequestSet RS = null;
	private CombinedQueue queue = null;
	private Semaphore sema = null;
	long timeOrigin = 0;
	
	int bufSize = 4096;

	public CTCPClientThread(CTCPClient client, RequestSet RS, CombinedQueue queue,
			Semaphore sema, long timeOrigin) {
		this.client = client;
		this.RS = RS;
		this.queue = queue;
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

			if (client.socket == null)
				client.createSocket();
			
			/*if (!client.socket.isConnected())
				Log.w("TCPClientThread", "socket not connected!");*/
			
			// Get Input/Output stream for socket
			dataOutputStream = new DataOutputStream(client.socket.getOutputStream());
			dataInputStream = new DataInputStream(client.socket.getInputStream());

			Log.d("Sending", "payload " + RS.getPayload().length +
					" bytes, expecting " + RS.getResponse_len() + " bytes ");
			
			dataOutputStream.write(RS.getPayload()); //Data type for payload
			
			Log.d("Sended", "payload " + RS.getPayload().length +
					" bytes, expecting " + RS.getResponse_len() + " bytes ");

			// Notify waiting Queue thread to start processing next packet
			if (RS.getResponse_len() > 0) {
				Log.d("Response", "Waiting for response of " + RS.getResponse_len() + " bytes");

				int totalRead = 0;

				Log.d("Receiving", String.valueOf(RS.getResponse_len()) + " bytes" + " start at time " +
						String.valueOf(System.currentTimeMillis() - timeOrigin));
				
				//if(RS.getResponse_len() < bufferSize)
				//	bufferSize = RS.getResponse_len();
				
				byte[] buffer = new byte[RS.getResponse_len()];
				while (totalRead < buffer.length) {
					// @@@ offset is wrong?
					int bytesRead = dataInputStream.read(buffer, totalRead,
							Math.min(buffer.length - totalRead, bufSize));
					//Log.d("Payload " + RS.getResponse_len(), String.valueOf(buffer));
					//int bytesRead = dataInputStream.read(buffer);
					//Log.d("Received " + RS.getResponse_len(), String.valueOf(bytesRead));
					if (bytesRead < 0) {
						throw new IOException("Data stream ended prematurely");
					}
					totalRead += bytesRead;
				}
				// adrian: manually free buffer
				buffer = null;
				
				Log.d("Finished", String.valueOf(RS.getResponse_len()) + " bytes");
			} else {
				Log.d("Receiving", "skipped");
			}
			
		} catch (Exception e) {
			Log.d("TCPClientThread", "something bad happened!");
			e.printStackTrace();
		} finally {
			sema.release();
			synchronized (queue) {
				--queue.threads;
			}
			synchronized (queue) {
				queue.notifyAll();
			}

		}

	}

}
