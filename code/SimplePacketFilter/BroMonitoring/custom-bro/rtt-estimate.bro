module Conn;

export {
    # log the act
	redef record Info += {
        ack_time: time &log &optional;
        synack_time: time &log &optional;
	};
	
}

redef record connection += {
    conn_synack_time:    time &default=network_time();
    conn_ack_time:    time &default=network_time();   
};

## Log the first ACK from the originator
## Note that this ACK is not the SYN/ACK packet sent in response to the SYNi
event connection_SYN_packet(c: connection, pkt: SYN_packet) 
    {
        # Assumption here is that it will be written twice. 
        # The SYN/ACK will overwrite the time written by the the SYN packet sent by the originator
        c$conn_synack_time = network_time();
    }

event connection_first_ACK(c: connection) 
    {
       c$conn_ack_time = network_time();
    }

function write_rtt_estimate(c: connection) 
{
        if ( ! c?$conn )
        {
            local tmp: Info;
            c$conn = tmp;
        }
       c$conn$ack_time = c$conn_ack_time;
       c$conn$synack_time = c$conn_synack_time;
}

event connection_state_remove(c: connection) 
{
    write_rtt_estimate(c);
}

event content_gap(c: connection, is_orig: bool, seq: count, length: count)
    {
      write_rtt_estimate(c);
    }
event tunnel_changed(c: connection, e: EncapsulatingConnVector)
    {
    write_rtt_estimate(c);
    }
