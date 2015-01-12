package com.stonybrook.replay.tcp;

import java.io.BufferedInputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.concurrent.Callable;
import java.util.concurrent.Semaphore;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;
import com.stonybrook.replay.util.UtilsManager;

// @@@ This class is for debugging purpose. Blocking call, not used now.
public class CallableTCPClientThread implements Callable<Void> {

	private TCPClient client = null;
	private RequestSet RS = null;
	private CallableTCPQueue queue = null;
	private Semaphore sema = null;
	long timeOrigin = 0;

	public CallableTCPClientThread(TCPClient client, RequestSet RS, CallableTCPQueue callableTCPQueue, Semaphore sema, long timeOrigin) {
		this.client = client;
		this.RS = RS;
		this.queue = callableTCPQueue;
		this.sema = sema;
		this.timeOrigin = timeOrigin;
	}


	@Override
	public Void call() throws Exception {
		DataOutputStream dataOutputStream = null;
		DataInputStream dataInputStream = null;
		try {

			if (client.socket == null || !client.socket.isConnected())
				client.createSocket();

			// Get Input/Output stream for socket
			dataOutputStream = new DataOutputStream(client.socket.getOutputStream());
			dataInputStream = new DataInputStream(new BufferedInputStream(client.socket.getInputStream(), 4*1024*1024));

			Log.d("Send", "Sending payload for pair " + RS.getc_s_pair() + " " + RS.getResponse_len());

			//Log.d("Size", String.valueOf(UtilsManager.serialize(RS.getPayload()).length));
			Log.d("Size", String.valueOf(ByteBuffer.wrap(UtilsManager.serialize(RS.getPayload())).array().length));
			//client.sc.write(ByteBuffer.wrap(UtilsManager.serialize(RS.getPayload()))); // Data
																				// type
																				// for
																				// payload
			 dataOutputStream.write(UtilsManager.serialize(RS.getPayload())); //Data type for payload
			// dataOutputStream.writeChars(String.valueOf(RS.getPayload()));
			// Log.d("Size",
			// String.valueOf(String.valueOf(RS.getPayload()).length()));

			/*
			 * synchronized (client) { client.notifyAll(); }
			 */

			synchronized (queue) {
				queue.notifyAll();
			}

			// Notify waiting Queue thread to start processing next packet
			if (RS.getResponse_len() > 0) {
				Log.d("Response", "Waiting for response for pair " + RS.getc_s_pair() + " of " + RS.getResponse_len() + " bytes");

				int totalRead = 0;

				Log.d(String.valueOf(RS.getResponse_len()), "start " + String.valueOf(System.nanoTime() - timeOrigin));
				
				//ByteBuffer lenBuf = ByteBuffer.allocateDirect(RS.getResponse_len());
				//ByteBuffer lenBuf = ByteBuffer.allocateDirect(4*1024*1024);
				//SocketChannel.open();
				/*int bytesRead = 0;
				int count = 0;
				while (totalRead < RS.getResponse_len()) {
					bytesRead = client.sc.read(lenBuf);
				//	Log.d("Response", "Total read : " + totalRead + " of " + RS.getResponse_len() + " count " + bytesRead);
					if (bytesRead < 0) {
						break;
					}
					totalRead += lenBuf.position();
					lenBuf.rewind();
				}
				*/
				/*int count = 0;
				while (totalRead < RS.getResponse_len()) {
					int bytesRead = dataInputStream.read(buffer, 0, 8192);
					
					//Log.d("Response", "Total read : " + totalRead + " of " + RS.getResponse_len() + " count " + count++);
					if (bytesRead < 0) {
						throw new IOException("Data stream ended prematurely");
					}
					totalRead += bytesRead;
				}*/
				
				// while (totalRead != RS.getResponse_len()) {
				// int bytesRead = dataInputStream.read(buffer, totalRead,
				// RS.getResponse_len() - totalRead);
				// dataInputStream.readFully(buffer, totalRead, RS.getResponse_len());
				// Log.d("Response", "Total read : " + totalRead + " of " +
				// RS.getResponse_len());
				// if (bytesRead < 0) {
				// throw new IOException("Data stream ended prematurely");
				// }
				// totalRead += bytesRead;
				// }
				byte[] buffer = new byte[4*1024*1024];
				while (totalRead < RS.getResponse_len()) {
					int bytesRead = dataInputStream.read(buffer, totalRead, RS.getResponse_len() - totalRead);
					//dataInputStream.readFully(buffer, totalRead, RS.getResponse_len());
					//Log.d("Response", "Total read : " + totalRead + " of " + RS.getResponse_len());
					if (bytesRead < 0) {
						throw new IOException("Data stream ended prematurely");
					}
					totalRead += bytesRead;
				}
				Log.d(String.valueOf(RS.getResponse_len()), "end " + String.valueOf(System.nanoTime() - timeOrigin));
			}

			//Log.d("Test1", "After");
			/*
			 * synchronized (this) { client.flag.set(false); }
			 */

		} catch (Exception e) {
			e.printStackTrace();
			throw e;
		} finally {
			sema.release();
			synchronized (queue) {
				--queue.threads;
			}
			/*
			 * try { if (dataInputStream != null ) dataInputStream.close();
			 * 
			 * if (dataOutputStream != null ) dataOutputStream.close(); } catch
			 * (IOException e) { e.printStackTrace(); }
			 */

		}
		return null;
		
	}

}
