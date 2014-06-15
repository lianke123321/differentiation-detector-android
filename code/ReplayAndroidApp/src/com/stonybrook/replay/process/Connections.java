package com.stonybrook.replay.process;

import java.io.DataOutputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.HashMap;

import com.stonybrook.replay.util.Config;
import com.stonybrook.replay.util.InstanceManager;

import android.util.Log;

/**
 * This class handles connections to servers. 
 * It basically holds a dictionary which maps c_s_pairs to connections.
 * @author rajesh
 *
 */
public class Connections {

	HashMap<String, Socket> _connections;
	Config config = null;

	public Connections() {
		_connections = new HashMap<String, Socket>();
		config = new Config();
	}
	
	public void setSocket(String csPair, Socket socket)
	{
		_connections.put(csPair, socket);
	}
	
	public void removeSocket(String csPair)
	{
		_connections.remove(csPair);
	}

	public int portFromCSPair(String csPair) {
		String secondPair = csPair.split("-")[1];
		return Integer.valueOf(secondPair.substring(
				secondPair.lastIndexOf('.') + 1, secondPair.length()));
	}
	
	/**
	 * Every time we want to send out a payload on a c_s_pair, we first query its
       corresponding connection. If the connection doesn't exist (very first time we
       are sending a payload on this c_s_pair), it creates the connection.
	 * @param csPair
	 * @return
	 * @throws Exception
	 */
	public Socket getSocket(String csPair) throws Exception {
		if (_connections.get(csPair) != null)
			return _connections.get(csPair);
		else {
			String serverAddress;
			DataOutputStream dataOutputStream = null; 
			int portNo = 0;
			Socket socket;
			try
			{
				if (Config.get("original_ports").equalsIgnoreCase("true")) {
					serverAddress = InstanceManager.getInstance(
							Config.get("instance")).getName();
					portNo = portFromCSPair(csPair);
				} else {
					serverAddress = InstanceManager.getInstance(
							Config.get("instance")).getName();
					portNo = Integer.valueOf(Config.get("port-" + csPair));
				}

				Log.e("Conn", "Opening Connection " + serverAddress + ":" + portNo);
				//MainActivity.logText(  "Opening Connection " + serverAddress + ":" + portNo);
				
				socket = new Socket();
				InetSocketAddress endPoint = new InetSocketAddress(serverAddress, portNo);
				socket.setTcpNoDelay(true);
				socket.setReuseAddress(true);
				socket.connect(endPoint);
				dataOutputStream = new DataOutputStream(socket.getOutputStream());
				//Log.w("FirstPair", csPair);
				
				Log.e("Send", "Sending pair: " + csPair);
				//MainActivity.logText(  "Sending pair: " + csPair);
				dataOutputStream.write(csPair.getBytes());
				
				
				setSocket(csPair, socket);
				
				return socket;
			}
			catch(Exception  ex)
			{
				ex.printStackTrace();
				Log.e("Error", ex.toString());
				throw ex;
			}
			finally
			{
				/*try {
					if (dataOutputStream != null )
						dataOutputStream.close();
				} catch (IOException e) {
					e.printStackTrace();
				}*/
			}
			
		}
	}
}
