package com.stonybrook.replay.process;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.net.Socket;
import java.util.Queue;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;
import com.stonybrook.replay.util.UtilsManager;


/**
 *  This class handles a single request-response event.
    It sends a single request and receives the response for that
 * @author rajesh
 *
 */
public class SendRecv extends Thread {

	RequestSet q;
	Queue<String> waitList;
	Queue<String> sendList;
	Connections connections;

	public SendRecv(RequestSet q, Queue<String> waitList,
			Queue<String> sendList, Connections connections) {
		super();
		this.q = q;
		this.waitList = waitList;
		this.sendList = sendList;
		this.connections = connections;
	}

	@Override
	public void run() {
 		Socket socket = null;
 		DataOutputStream dataOutputStream = null ;
 		DataInputStream dataInputStream = null;
		try {
			//Get Socket pait for CSPait
			socket = connections.getSocket(q.getc_s_pair());
			
			//Get Input/Output stream for socket
			dataOutputStream = new DataOutputStream(socket.getOutputStream());
			dataInputStream = new DataInputStream(socket.getInputStream());

			Log.d("Send","Sending payload for pair " + q.getc_s_pair());
			//MainActivity.logText( "Sending payload for pair " + q.getc_s_pair());
			
			dataOutputStream.write(UtilsManager.serialize(q.getPayload())); //Data type for payload
			//dataOutputStream.writeChars(q.getPayload().toString()); 
			
			
			sendList.remove(q.getc_s_pair());
			//waitList.remove(q.getc_s_pair());
			
			//Notify waiting Queue thread to start processing next packet 
			
			if(q.getResponse_len() == 0)
			{
				Log.d("Response", "\tNo response " + q.getc_s_pair() + "\t" + q.getPayload().toString().length() );
				waitList.remove(q.getc_s_pair());
				//MainActivity.logText(  "\tNo response " + q.getc_s_pair() + "\t" + q.getPayload().toString().length() );
				synchronized (waitList) {
					waitList.notify();
				}
				
			}
			else
			{
				Log.d("Response", "\tWaiting for response for pair " +  q.getc_s_pair() + " of " + q.getResponse_len() + " bytes"  );
				//MainActivity.logText( "\tWaiting for response for pair " +  q.getc_s_pair() + " of " + q.getResponse_len() + " bytes"  );
				synchronized (waitList) {
					waitList.notify();
				}
				long bufferLen = 0;
				byte[] buffer = new byte[q.getResponse_len()];
				int totalRead = 0;

				while (totalRead < q.getResponse_len()) {
				    int bytesRead = dataInputStream.read(buffer, totalRead, q.getResponse_len() - totalRead);
				    
				    //Log.d("Response", "Total read : " + totalRead + " of " + q.getResponse_len());
				    if (bytesRead < 0) {
				        // Change behaviour if this isn't an error condition
				        throw new IOException("Data stream ended prematurely");
				    }
				    totalRead += bytesRead;
				}
				Log.w("Response", "\tReceived " + q.getResponse_len() + " bytes" );
				//MainActivity.logText(  "\tReceived " + q.getResponse_len() + " bytes" );
				waitList.remove(q.getc_s_pair());
				synchronized (waitList) {
					waitList.notify();
				}
				
			}
			
		} catch (Exception e) {
			e.printStackTrace();
		}
		finally
		{
			/*try {
				if (dataInputStream != null )
					dataInputStream.close();
				
				if (dataOutputStream != null )
					dataOutputStream.close();
			} catch (IOException e) {
				e.printStackTrace();
			}*/
			
		}
	}
	
	
}