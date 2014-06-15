package com.stonybrook.replay.udp;

import java.util.ArrayList;
import java.util.HashMap;

import android.util.Log;

import com.stonybrook.replay.bean.RequestSet;

/**
 * Communication sequence on side channel:

        1- Client creates side channel and connects to server
        2- Client sends its randomly generated ID (10 bytes) to server, side_channel.identify()
        3- Client receives port mapping from server, SideChannel().receive_server_port_mapping().
           This is necessary because server may choose no to use original ports.
        4- Every client socket sends (id, c_s_pair) to corresponding socket server and receives
           Acknowledgment on the side channel (this is repeated every 1 second until ack is
           received), client.identify(side_channel, NAT_map, id)
           The acknowledgment/response from server is the client's port, so at this point client
           knows its NAT port
        5- Now client sockets start sending and receiving.
        6- Side channel listens for FIN confirmations from server sockets, and closes client socket
           receiving processes
        7- Once all sending/receiving is done, the client sends all its NAT ports to server
           so it can clean up its maps
        8- Client closes the side channel.
 * @author rajesh
 *
 */
public class UDPQueue implements Runnable {

	private ArrayList<RequestSet> Q = null;
	HashMap<String, ClientThread> CSPairMapping = null;
	boolean timing;

	public UDPQueue(ArrayList<RequestSet> q,
			HashMap<String, ClientThread> cSPairMapping, boolean timing) {
		super();
		Q = q;
		CSPairMapping = cSPairMapping;
		this.timing = timing;
	}

	@Override
	public void run() {
		long timeOrigin = System.currentTimeMillis();
		try {
			int i = 1;
			int len = this.Q.size();
			for (RequestSet RS : this.Q) {
				Log.d("UDPReplay", "Sending " + (i++) +  "/" + len);
				if (timing) {
					double expectedTime = timeOrigin + RS.getTimestamp() * 1000;
					if (System.currentTimeMillis() < expectedTime) {
						long waitTime = Math.round(expectedTime
								- System.currentTimeMillis());
						if(waitTime > 0)
							Thread.sleep(waitTime);
					}
				}
				
				CSPairMapping.get(RS.getc_s_pair()).getClient().sendUDPPacket(RS.getPayload());
			}
		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}

}
