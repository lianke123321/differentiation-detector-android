#include <iostream>
#include <fstream>
#include <map>
#include <vector>
#include <string>
#include <iomanip>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <algorithm>
#define OPEN_FILE_HANDLE_LIMIT 1000
// TCP:
//  16:28:35.679756 IP 65.121.208.122.80 > 10.11.3.3.53453: Flags [F.], seq 1, ack 1, win 10456, options [nop,nop,TS val 189791440 ecr 1720112], length 0 <<<< IGNORE
// 16:28:38.136027 IP 216.156.199.139.80 > 10.11.3.3.42287: Flags [.], seq 2809:4157, ack 1083, win 8457, options [nop,nop,TS val 15965058 ecr 1720518], length 1348 <<<< WRITE
// UDP:
// 16:38:02.934352 IP 10.11.3.3.7416 > 111.221.74.15.40004: UDP, length 428 <<<< ACCUMULATE BY LENGTH
using namespace std;


// This will eath through white spaces.
void eatspaces(ifstream &inp)
{
    while(inp.peek() == ' ' || inp.peek() == '\n') inp.get();
}

// Generate an index for the plot character. First it gives 'A' to 'Z',
// then 'a' to 'z' and finally '0' to '9' (and every character beyond
// that, but this shouldn't happen).
char nextIndex()
{
    static char in = 'A' - 1;
    if (in >= 'A' - 1 && in < 'Z') in++;
    else if (in == 'Z') in = 'a';
    else if (in >= 'a' && in < 'z') in++;
    else if (in == 'z') in = '0';
    else if (in >= '0') in++;

    return in;
}

// Connection type.
enum type_e {TCP, UDP};

// Skip the rest of the line.
void skipline(ifstream &inp)
{
    while(inp.get() != '\n');
}

int main(int argc, char ** argv)
{
    // Threshold for length-based filtering.
    long length_thr = 1000;
    // Title that appears on top of the plot.
    string plot_title =  "";
    // If the plot key is too cluttered, set this flag to disable it.
    bool no_key = false;

    // Parsing arguments.
    if (argc < 2)
    {
        cerr << "No input given." << endl;
        return -1;
    }
    if (argc >= 2 && (strcmp(argv[1],"--help") == 0 || strcmp(argv[1],"?") == 0 || strcmp(argv[1], "-help") == 0 || strcmp(argv[1],"-h") == 0))
    {
        cout << "Usage:" << endl
             << "filter input_file [size_threshold | - ] [plot_title] [nokey]" << endl
             << "filter --help\t : print this message" << endl << endl
             << "If a size_threshold value is not entered or a \"-\" is in its place, " << endl
             << "the default value is used (" << length_thr << ")." << endl << endl
             << "plot_title sets the title of the plot." << endl << endl
             << "If nokey is set, the plot will not have a key." << endl << endl
             << "Example:" << endl
             << "filter sample.pcap.txt 500 \"Sample Trace\" nokey" << endl << endl
             << "Creates a plot out of the input with cut-off threshold of 500 " << endl
             << "that has the title \"Sample Trace\" and doesn't have a key." << endl;

        return 0;
    }

    if (argc >= 3)
    {
        if(strcmp(argv[2],"-") != 0)
            length_thr = atoi(argv[2]);
    }
    else
    {
        cout << "No threshold given, using default (1000)." << endl;
    }
    if (argc >= 4)
    {
        plot_title = argv[3];
    }
    if (argc >= 5 && strcmp(argv[4], "nokey") == 0)
    {
         no_key = true;
    }

    // Input file address.
    string input_addr(argv[1]);
    // Input file handle.
    ifstream inp(input_addr.c_str());
    // Remove and recreate the input directory.
    system("rm -rf connections");
    system("mkdir connections");
    // Keeping the number of connections seen so far.
    long connection_count = 0;
    // Index for plot key.
    map<string,char> plot_index;
    // Maximum transfer length for each connection.
    map<string,long> max_len;
    // keep the reverse form of
    // "x.x.x.x.portx-y.y.y.y.porty" as
    // "y.y.y.y.porty-x.x.x.x.portx"
    map<string,string> reverse;
    // Connection type for each connection (TCP or UDP).
    map<string,type_e> connection_type;
    // Maps files to connections.
    map<string,ofstream*> file_map;
    // Keep a tap on the number of open files,
    // more than 1019 files cannot be open at
    // the same time.
    long open_files = 0;
    map<string,ofstream*>::iterator it;
    // Keep total UDP length for each UDP connection.
    map<string,long> udp_offset;
    long i = 0;
    // TCP sequence number/UDP packet length.
    long seq1, seq2, len;
    // Waste character.
    char waste;
    // Time values.
    int hh,mm,ss;
    long double micros;

    // Strings for parties involved in the connection
    // and the string to determine the protocol.
    string p1, p2, protocol;
    // To skip over unnecessary strings in the input.
    string temp;
    // TCP packet type (syn or ack)
    string seq_or_ack;
    // To identify packet type (IP or non-IP)
    string packet_type;
    // Starting time for the connection (used to calculate
    // time offset).
    long double start;
    // Packet time.
    long double ttime = 0;
    // Flag is to mark a valid TCP row and first is to
    // determine if the first line in the plot.gp file
    // has been written.
    bool flag = false, first = false;

    // Total number of all TCP packets.
    long total_tcp_packets = 0;

    // Total number of lost TCP packets.
    long total_tcp_lost = 0;

    // Map of ACKS
    map<string, bool> acks;

    // Map of SEQs.
    vector<string> seqs;

    // Throughput timer.
    double now_time = 0;
    double last_time = 0;

    // Momentary throughput.
    long now_length = 0;

    // Throughput interval.
    double xput_interval = 0.1;

    // Throughput vector.
    vector<double> xputs;

    // Throughput file.
    ofstream xput_data("./xput.txt");

    // Metadata file.
    ofstream meta("meta.txt");

    // Read the first time value (starting time).
    inp >> hh; inp.get();
    inp >> mm; inp.get();
    inp >> ss; inp.get();
    inp >> micros;
    start = hh * 3600 + mm * 60 + ss + micros / 1000000;
    eatspaces(inp);

    // Read the first line, up until protocol.
    inp >> packet_type >> p1 >> temp >> p2 >> protocol; //>> seq1;
    // Remove the : from the destination address and port.
    p2.resize(p2.size()-1);
    ttime = start;

    // If it has flags, it's TCP.
    if (protocol == "Flags") // TCP
    {
        // Find where the sequence number is.
        inp >> temp >> seq_or_ack;
        inp >> seq1;

        // If the sequence number is in form of xxx:yyy
        // it is acceptable.
        if (inp.peek()==':')
        {
            flag = true;
            inp.get();
            inp >> seq2;
        }
        // Write the acceptable packet in the file.
        if(flag)
        {
            // Create a file for the new connection in "connections" directory.
            file_map[(p1 + "-" + p2)] = new ofstream(("connections/" + p1 + "-" + p2).c_str());
            open_files++;
            // Add the reverse line in the revers map.
            reverse[(p1 + "-" + p2)] = (p2 + "-" + p1);
            // Increment the number of connections.
            connection_count++;
            // length of the first packet is assumed to be 0.
            max_len[(p1 + "-" + p2)] = 0;
            // Set the connection type.
            connection_type[(p1 + "-" + p2)] = TCP;
            // The first time is 0 because it's the first packet
            // in the trace. Also, the sequence number is set to
            // 0 because the fist sequence number is a large random
            // number and should not be considered for the plot.
            (*(file_map[p1+ "-" + p2])) << "0.000000 0" << endl;
            // Reset the "acceptable TCP packet" flag.
            flag = false;
            // Add to the length for the current throughput interval.
            now_length += seq2 - seq1;
        }
        // Increment the total number of TCP packets.
        total_tcp_packets++;
    }
    else if (protocol == "UDP,") // UDP
    {
        // Skip through the input.
        inp >> temp;
        // Read the UDP packet length.
        inp >> len;

        file_map[(p1 + "-" + p2)] = new ofstream(("connections/" + p1 + "-" + p2 + "_UDP").c_str());
        open_files++;
        reverse[(p1 + "-" + p2)] = (p2 + "-" + p1);
        connection_count++;
        udp_offset[(p1 + "-" + p2)] = 0;
        max_len[(p1 + "-" + p2)] = 0;
        connection_type[(p1 + "-" + p2)] = UDP;
        (*(file_map[p1+ "-" + p2])) << "0.000000" << len << endl;
        // Add to the length for the current throughput interval.
        now_length += len;
    }
    skipline(inp);
    eatspaces(inp);

    while(!inp.eof())
    {
        eatspaces(inp);
        // Read the time value (packet time).
        inp >> hh; inp.get();
        inp >> mm; inp.get();
        inp >> ss; inp.get();
        inp >> micros;
        ttime = hh * 3600 + mm * 60 + ss  + micros / 1000000 - start;

        eatspaces(inp);

        // Read row up until protocol.
        inp >> temp >> p1 >> temp >> p2 >> protocol;
        p2.resize(p2.size()-1);

        if (protocol == "Flags") // TCP
        {
            inp >> temp >> seq_or_ack;
            inp >> seq1;

            if (inp.peek()==':')
            {
                flag = true;
                inp.get();
                inp >> seq2;
            }
            if(flag)
            {
                if(file_map.count(p1 + "-" + p2) == 0)
                {
                    file_map[(p1 + "-" + p2)] = new ofstream(("connections/" + p1 + "-" + p2).c_str());
                    open_files++;
                    reverse[(p1 + "-" + p2)] = (p2 + "-" + p1);
                    connection_count++;
                    max_len[(p1 + "-" + p2)] = 0;
                    flag = false;
                    (*(file_map[p1+ "-" + p2])) << ttime << " 0" << endl;
                    // If there are too many files open, close this one.
                    if(open_files > OPEN_FILE_HANDLE_LIMIT) { (*(file_map[p1+ "-" + p2])).close(); open_files--;}
                }
                else
                {
                    // If the file has been closed, reopen it.
                    if(!((file_map[p1+ "-" + p2])->is_open()))
                    {
                        (file_map[p1+"-"+p2])->open(("connections/" + p1 + "-" + p2).c_str(), std::ofstream::out | std::ofstream::app);
                        open_files++;
                    }

                    // Write the packet time and sequence number into the file for that connection.
                    (*(file_map[p1+ "-" + p2])) << setprecision(14) << ttime << " " << seq2 << endl;
                    // Maximum connection length for a TCP connection is the last sequence number.
                    max_len[(p1 + "-" + p2)] = seq2;
                    eatspaces(inp);
                    flag = false;
                    // If there are too many files open, close this one.
                    if(open_files > OPEN_FILE_HANDLE_LIMIT) {(*(file_map[p1+ "-" + p2])).close(); open_files--;}

                }

                // If packet time is in the current throughput interval, add the length to the interval.
                if(long(ttime / xput_interval) == now_time)
                {
                    now_length += seq2 - seq1;
                }
                else
                {
                // Otherwise, write the current interval throughput and set a new interval.
                    for (double i = double(last_time + 1) * xput_interval; i < double(now_time) * xput_interval; i += xput_interval)
                    {
                        xput_data << i << " " << 0 << endl;
                        xputs.push_back(0);
                    }

                    xput_data << double(now_time) * xput_interval << " " << now_length / xput_interval << endl;
                    // Keep values to in an array for median finding purposes.
                    xputs.push_back(now_length / xput_interval);
                    last_time = now_time;
                    now_time = long(ttime / xput_interval);
                    now_length = seq2 - seq1;
                }
            }

            // Look for packet loss.
            // If there's a duplicate "seq m:n", it is a retransmit.
            if(seq_or_ack == "seq" && flag)
            {
                string s;
                char seq1c[20];
                sprintf(seq1c,"%ld", seq1);
                char seq2c[20];
                sprintf(seq2c,"%ld", seq2);
                s += p1 + p2 + seq1c + seq2c;

                if(find(seqs.begin(), seqs.end(), s) != seqs.end())
                {
                    //cout << "Duplicate seq: " << p1 << ">" << p2 << " seq " << seq1c << ":" << seq2c << endl;
                    total_tcp_lost++;
                }
                else
                {
                    // If it hasn't been seen before, add it.
                    seqs.push_back(s);
                }
            }
            // If there is a duplicate "ack n" that has been seen only once before,
            // a packet has been lost.
            else if (seq_or_ack == "ack")
            {
                string s;
                char seq1c[20];
                sprintf(seq1c,"%ld", seq1);
                s += p1 + p2 + seq1c;

                // If this has been seen and only seen once, a packet was lost.
                if(acks.count(s) != 0 && acks[s] == false)
                {
                    acks[s] = true;
                    //cout << "Duplicate ack: " << p1 << ">" << p2 << " ack " << seq1c << endl;
                    total_tcp_lost++;
                }
                else
                {
                    // If it hasn't been seen before, add it.
                    if (acks.count(s) == 0)
                        acks[s] = false;
                }
            }
            total_tcp_packets++;
        }
        else if (protocol == "UDP,") // UDP
        {
            inp >> temp;
            inp >> len;
            if(file_map.count(p1 + "-" + p2) == 0)
            {
                file_map[(p1 + "-" + p2)] = new ofstream(("connections/" + p1 + "-" + p2 + "_UDP").c_str());
                open_files++;
                reverse[(p1 + "-" + p2)] = (p2 + "-" + p1);
                connection_count++;
                udp_offset[(p1 + "-" + p2)] = 0;
                max_len[(p1 + "-" + p2)] = 0;
                connection_type[(p1 + "-" + p2)] = UDP;
            }

            udp_offset[(p1 + "-" + p2)] += len;
            max_len[(p1 + "-" + p2)] = udp_offset[(p1 + "-" + p2)];

            // If the file has been closed, reopen it.
            if(!((file_map[p1+ "-" + p2])->is_open()))
            {
                (file_map[p1+"-"+p2])->open(("connections/" + p1 + "-" + p2 + "_UDP").c_str(), std::ofstream::out | std::ofstream::app);
                open_files++;
            }

            // Write the packet time and sequence number into the file for that connection.
            (*(file_map[p1+ "-" + p2])) << setprecision(14) << ttime << " " << udp_offset[(p1 + "-" + p2)] << endl;

            // If there are too many files open, close this one.
            if(open_files > OPEN_FILE_HANDLE_LIMIT) {(*(file_map[p1+ "-" + p2])).close(); open_files--;}
            if(long(ttime / xput_interval) == now_time)
            {
                now_length += len;
            }
            else
            {
                for (double i = double(last_time + 1) * xput_interval; i < double(now_time) * xput_interval; i += xput_interval)
                {
                    xput_data << i << " " << 0 << endl;
                    xputs.push_back(0);
                }

                xput_data << double(now_time) * xput_interval << " " << now_length / xput_interval << endl;
                // Keep values to in an array for median finding purposes.
                xputs.push_back(now_length / xput_interval);
                last_time = now_time;
                now_time = long(ttime / xput_interval);
                now_length = len;
            }
        }
        skipline(inp);
        eatspaces(inp);
    }

    xputs.push_back(now_length / xput_interval);
    xput_data << now_time * xput_interval << " " << now_length / xput_interval << endl;

    double xp_max = xputs[0];
    double xp_sum = 0;

    // Find the maximum throughput and calculate the sum of all throughputs.
    for(int i = 0; i < xputs.size(); i++)
    {
        if (xp_max < xputs[i])
            xp_max = xputs[i];
        xp_sum += xputs[i];
    }


    // Simplest sorting algorithm in the world! :)
    bool swapped = false;
    for(int i = xputs.size(); i > 0; i--)
    {
        swapped = false;
        for (int j = 1; j <= i; j++)
        {
            if (xputs[i-1] > xputs[i])
            {
                swap(xputs[i-1], xputs[i]);
                swapped = true;
            }
        }
        if(!swapped)
            break;
    }

    meta << "xput_max\t" << xp_max / 1e+3 << endl;
    meta << "xput_avg\t" << (xp_sum / xputs.size()) / 1e+3 << endl;
    meta << "xput_mdn\t" << xputs[xputs.size() / 2] / 1e+3 << endl;

    meta << "tcp_lost\t" << total_tcp_lost << endl;
    meta << "tcp_total\t" << total_tcp_packets << endl;
    meta << "loss_rate\t" << double(total_tcp_lost) / double(total_tcp_packets) * 100.0 << endl;

    meta.close();

    // Throughput plot.
    ofstream xputplot("xput.gp");
    xputplot    << "set style data lines"  << endl
            << "set title \"" << plot_title << " Throughput (" << xput_interval * 1000 << " ms intervals)\"" << endl
            << "set key off" << endl
            << "set xlabel \"Time (seconds)\"" << endl
            << "set ylabel \"Throughput (KB/s)\"" << endl
            << "set term postscript color eps enhanced \"Helvetica\" 16" << endl
            << "set size ratio 0.5" << endl
            << "# Line style for axes" << endl
            << "set style line 80 lt 0" << endl
            << "set grid back linestyle 81" << endl
            << "set border 3 back linestyle 80" << endl
            << "set xtics nomirror" << endl
            << "set ytics nomirror" << endl
            << "set out \'xp.ps\'" << endl
            << "plot \"xput.txt\" using 1:($2/1e3) with lines lw 3";
    xputplot.close();
    // Draw the plot.
    system("gnuplot xput.gp");
    // Convert it to JPEG for convenience.
    stringstream ssstr;
    ssstr   << "convert -font helvetica -fill black -draw \'text 50,100 \""
            << "Maximum throughput: " << xp_max / 1e+3 << " KB/s\n"
            << "Mean throughput: " << (xp_sum / xputs.size()) / 1e+3 << " KB/s\n"
            << "Median throughput: " << xputs[xputs.size() / 2] / 1e+3 << " KB/s\n"
            << "TCP packets lost: " << total_tcp_lost << "\n"
            << "Total TCP packets: " << total_tcp_packets << "\n"
            << "Loss rate: " << double(total_tcp_lost) / double(total_tcp_packets) * 100.0 << "%\n"
            << "\"\' -pointsize 6 -density 1000 xp.ps -scale 2000x1000 xp.jpg";
    system(ssstr.str().c_str());

    // Create a file to map the plot legend to connections in the plot.
    ofstream index_file("connection_index.txt");

    // Prepare the plot.
    ofstream plot("plot.gp");
    plot    << "set style data lines"  << endl
            << "set title \"" << plot_title << " (cutoff threshold = " << length_thr << ")\"" << endl
            << "set key out right" << endl
            << (no_key ? "set key off\n" : "")
            << "set xlabel \"Time (seconds)\"" << endl
            << "set ylabel \"Cumulative Transfer (MB)\"" << endl
            << "set term postscript color eps enhanced \"Helvetica\" 16" << endl
            << "set size ratio 0.5" << endl
            << "# Line style for axes" << endl
            << "set style line 80 lt 0" << endl
            << "set grid back linestyle 81" << endl
            << "set border 3 back linestyle 80" << endl
            << "set xtics nomirror" << endl
            << "set ytics nomirror" << endl
            << "set out \'p.ps\'" << endl << "plot ";

    // The first line in the plot file has not been written yet.
    first = false;

    // Maximum connection length.
    long MAX = 0;

    // Find the maximum connection length among all connections in the trace.
    for(map<string,long>::iterator it = max_len.begin(); it != max_len.end(); it++)
    {
        MAX = (MAX > it->second ? MAX : it->second);
    }

    // Add files to the plot.
    for(map<string,long>::iterator it = max_len.begin(); it != max_len.end(); it++)
    {
        // If connection length for this connection is smaller than
        // MAX divided by length threshold, it should be cut off.
        if(it->second * length_thr < MAX) continue;

        // If the other way of this connection is not already in the plot,
        // add a new index for it, otherwise, leave a mark on it so the
        // index for the other way could be used.
        if(plot_index.count(reverse[it->first]) == 0)
        {
            plot_index[it->first] = nextIndex();
        }
        else
        {
            plot_index[it->first] = '*';
        }

                    // If it's the other way, use the index for its original connection.
        index_file  << (plot_index[it->first] == '*' ? plot_index[reverse[it->first]] : plot_index[it->first])
                    // and append a "*" to it.
                    << (plot_index[it->first] == '*' ? "*" : "")
                    // If this is a UDP connection, add the "_UDP" so the file associated
                    // with it can later be opened easily.
                    << "\t -> \t" << (it->first + (connection_type[it->first] == UDP ? "_UDP" : "")) << endl;
        if(connection_type[it->first] == TCP)
        {
            if(first) { plot << ", \\\n";}
            plot    << "\"connections/" << it->first << "\" using 1:($2/1e6) with lines lw 3 title \""
                    // If it's the other way, use the index for its original connection.
                    << (plot_index[it->first] == '*' ? plot_index[reverse[it->first]] : plot_index[it->first])
                    // and append a "*" to it.
                    << (plot_index[it->first] == '*' ? "*" : "") << "\"";
            if(!first) first = true;
        }
        else
        {
            if(first) { plot << ", \\\n";}
            plot    << "\"connections/" << it->first << "_UDP\" using 1:($2/1e6) with lines lw 3 title \""
                    // If it's the other way, use the index for its original connection.
                    << (plot_index[it->first] == '*' ? plot_index[reverse[it->first]] : plot_index[it->first])
                    // and append a "*" to it.
                    << (plot_index[it->first] == '*' ? "*" : "")
                    << "(UDP)\"";
            if(!first) first = true;
        }

    }
    plot << endl;
    plot.close();

    // Draw the plot.
    system("gnuplot plot.gp");
    // Convert it to JPEG for convenience.
    system("convert -density 1000 p.ps -scale 2000x1000 p.jpg");
    return 0;
}
