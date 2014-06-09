import pickle, json
from python_lib import *

Q1, client_ports1, num_server_ports1, c_s_pairs1, replay_name1 = pickle.load(open('../data/skype/skype.pcap_client_pickle' , "r"))
Q2, client_ports2, num_server_ports2, c_s_pairs2, replay_name2 = json.load(open('../data/skype/skype.pcap_client_json'  , "r"), cls=UDPjsonDecoder_client)
assert(client_ports1 == client_ports2)
assert(num_server_ports1 == num_server_ports1)
assert(c_s_pairs1 == c_s_pairs2)
assert(replay_name1 == replay_name1)
for i in xrange(len(Q1)):
    assert(Q1[i].payload     == Q2[i].payload)
    assert(Q1[i].timestamp   == Q2[i].timestamp)
    assert(Q1[i].c_s_pair    == Q2[i].c_s_pair)
    assert(Q1[i].client_port == Q2[i].client_port)
    assert(Q1[i].end         == Q2[i].end)

Q1, server_ports1, replay_name1 = pickle.load(open('../data/skype/skype.pcap_server_pickle' , "r"))
Q2, server_ports2, replay_name2 = json.load(open('../data/skype/skype.pcap_server_json'  , "r"), cls=UDPjsonDecoder_server)
assert(server_ports1 == server_ports2)
assert(replay_name1 == replay_name1)
for server_port in Q1:
    for i in xrange(len(Q1[server_port])):
        assert(Q1[server_port][i].payload     == Q2[server_port][i].payload)
        assert(Q1[server_port][i].timestamp   == Q2[server_port][i].timestamp)
        assert(Q1[server_port][i].c_s_pair    == Q2[server_port][i].c_s_pair)
        assert(Q1[server_port][i].client_port == Q2[server_port][i].client_port)
        assert(Q1[server_port][i].end         == Q2[server_port][i].end)
        
        



Q1, c_s_pairs1, replay_name1 = pickle.load(open('../data/dropbox_d/dropbox_d.pcap_client_pickle', 'r'))
Q2, c_s_pairs2, replay_name2 = pickle.load(open('../data/dropbox_d2/dropbox_d.pcap_client_pickle', 'r'))
assert(c_s_pairs1   == c_s_pairs2)
assert(replay_name1 == replay_name1)
for i in xrange(len(Q1)):
    assert(Q1[i].payload   == Q2[i].payload.decode('hex'))
    assert(Q1[i].payload   == Q2[i].payload)
    assert(Q1[i].timestamp == Q2[i].timestamp)
    assert(Q1[i].c_s_pair  == Q2[i].c_s_pair)
