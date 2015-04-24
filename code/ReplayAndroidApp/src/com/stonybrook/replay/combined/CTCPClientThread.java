package com.stonybrook.replay.combined;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.net.SocketException;
import java.net.SocketTimeoutException;
import java.util.concurrent.Semaphore;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;

// @@@ Adrian add this

public class CTCPClientThread implements Runnable {

	private CTCPClient client = null;
	private RequestSet RS = null;
	private CombinedQueue queue = null;
	private Semaphore sendSema = null;
	private Semaphore recvSema = null;
	long timeOrigin = 0;

	int bufSize = 4096;

	public CTCPClientThread(CTCPClient client, RequestSet RS,
			CombinedQueue queue, Semaphore sendSema, Semaphore recvSema,
			long timeOrigin) {
		this.client = client;
		this.RS = RS;
		this.queue = queue;
		this.sendSema = sendSema;
		this.recvSema = recvSema;
		this.timeOrigin = timeOrigin;
	}

	/**
	 * Steps: 1- Send out the payload 2- Set send_event to notify you are done
	 * sending 3- Receive response (if any) 4- Set self.event to notify you are
	 * done receiving
	 */
	@Override
	public void run() {
		Thread.currentThread().setName("CTCPClientThread (Thread)");
		try {

			if (client.socket == null)
				client.createSocket();

			/*if (!client.socket.isConnected())
				Log.w("TCPClientThread", "socket not connected!");*/

			// Get Input/Output stream for socket
			DataOutputStream dataOutputStream = new DataOutputStream(
					client.socket.getOutputStream());

			/*Log.d("Sending", "payload " + RS.getPayload().length +
					" bytes, expecting " + RS.getResponse_len() + " bytes ");*/

			// handle GET payload
			String tmp = new String(RS.getPayload(), "UTF-8");
			/*Log.d("Sending", "length of string: " + tmp.length()
					+ " length of payload: " + RS.getPayload().length);*/
			/*if (tmp.length() >= 20)
				Log.d("Sending", "First 20 bytes: " + tmp.substring(0, 20));
			else
				Log.d("Sending", "Short content: " + tmp);*/
			if (client.addHeader && tmp.length() >= 3
					&& tmp.substring(0, 3).trim().equalsIgnoreCase("GET")) {
				// add modified fields
				String[] parts = tmp.split("\r\n", 2);
				tmp = parts[0]
						+ String.format("\r\nX-rr: %s;%s;%s\r\n",
								client.publicIP, client.replayName,
								client.CSPair) + parts[1];
				Log.d("Sending", "Special GET!");
				dataOutputStream.write(tmp.getBytes());
			} else {
				// send payload directly
				dataOutputStream.write(RS.getPayload());
			}

			/*Log.d("Sent", "payload " + RS.getPayload().length +
					" bytes, expecting " + RS.getResponse_len() + " bytes ");*/

			sendSema.release();

			// Notify waiting Queue thread to start processing next packet
			if (RS.getResponse_len() > 0) {
				DataInputStream dataInputStream = new DataInputStream(
						client.socket.getInputStream());

				int totalRead = 0;

				/*Log.d("Receiving", String.valueOf(RS.getResponse_len()) + " bytes"
						+ " start at time " +
						String.valueOf((System.nanoTime() - timeOrigin) / 1000000000));*/

				byte[] buffer = new byte[RS.getResponse_len()];
				while (totalRead < buffer.length) {
					// @@@ offset is wrong?
					int bytesRead = dataInputStream.read(buffer, totalRead,
							Math.min(buffer.length - totalRead, bufSize));
					/*Log.i("Receiving", "Read " + bytesRead + " bytes out of "
							+ buffer.length);*/

					// Log.d("Payload " + RS.getResponse_len(),
					// String.valueOf(buffer));
					// int bytesRead = dataInputStream.read(buffer);
					// Log.d("Received " + RS.getResponse_len(),
					// String.valueOf(bytesRead));
					if (bytesRead < 0) {
						Log.e("Receiving", "Not enough bytes! totalRead: "
								+ totalRead + " expected: " + buffer.length);

						String data = new String(buffer, "UTF-8");

						if (data.length() >= 12
								&& data.substring(0, 12).trim()
										.equalsIgnoreCase("WhoTheFAreU?")) {
							Log.e("TCPClientThread", "IP flipping detected");
							throw new SocketException(
									"Traffic Manipulation Detected (Type 1)");
						} else
							throw new SocketException(
									"Traffic Manipulation Detected (Type 2)");
						// String data = new String(buffer, "UTF-8");
						// Log.w("Receiving", data);
					}
					totalRead += bytesRead;
				}

				String data = new String(buffer, "UTF-8");
				if (data.length() >= 12
						&& data.substring(0, 12).trim()
								.equalsIgnoreCase("WhoTheFAreU?")) {
					Log.e("TCPClientThread", data);
					throw new SocketException(
							"Traffic Manipulation Detected (Type 1)");
				}
				/*else
					Log.d("Receiving", "content for " + buffer.length + "\n" + data);*/

				// adrian: increase current pointer
				/*synchronized (recvQueueBean) {
					recvQueueBean.current ++;
					recvQueueBean.notifyAll();
				}*/

				// adrian: manually free buffer
				buffer = null;

				Log.d("Finished",
						"receiving " + String.valueOf(RS.getResponse_len())
								+ " bytes");
			} else {
				Log.d("Receiving", "skipped");
			}

		} catch (SocketTimeoutException e) {
			Log.w("TCPClientThread", "Socket time out!");

			synchronized (queue) {
				queue.ABORT = true;
				// make sure that this is not caused by other issues
				if (queue.abort_reason == null)
					queue.abort_reason = "Replay Aborted: socket timeout";
			}
		} catch (Exception e) {
			Log.e("TCPClientThread", "something bad happened!");
			// abort replay if bad things happened!
			synchronized (queue) {
				queue.ABORT = true;
				queue.abort_reason = "Replay Aborted: " + e.getMessage();
			}
			e.printStackTrace();
		} finally {
			recvSema.release();
			synchronized (queue) {
				--queue.threads;
			}

		}

	}
}
