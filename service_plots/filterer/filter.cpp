#include <iostream>
#include <fstream>
#include <map>
#include <string>
#include <iomanip>
#include <cstdlib>
#include <cstring>

// TCP:
//  16:28:35.679756 IP 65.121.208.122.80 > 10.11.3.3.53453: Flags [F.], seq 1, ack 1, win 10456, options [nop,nop,TS val 189791440 ecr 1720112], length 0 <<<< IGNORE
// 16:28:38.136027 IP 216.156.199.139.80 > 10.11.3.3.42287: Flags [.], seq 2809:4157, ack 1083, win 8457, options [nop,nop,TS val 15965058 ecr 1720518], length 1348 <<<< WRITE
// UDP:
// 16:38:02.934352 IP 10.11.3.3.7416 > 111.221.74.15.40004: UDP, length 428 <<<< ACCUMULATE BY LENGTH
using namespace std;

void eatspaces(ifstream &inp)
{
    while(inp.peek() == ' ' || inp.peek() == '\n') inp.get();
}

enum type_e {TCP, UDP};

void skipline(ifstream &inp)
{
    while(inp.peek() != '\n') inp.get();
}

int main(int argc, char ** argv)
{
    long length_thr;
    char *plot_title =  "";
    bool no_key = false;

    if (argc < 2)
    {
        cerr << "No input given." << endl;
        return -1;
    }
    if (argc >= 2 && (strcmp(argv[1],"--help") == 0 || strcmp(argv[1],"?") == 0 || strcmp(argv[1], "-help") == 0 || strcmp(argv[1],"-h") == 0))
    {
        cout << "Usage:" << endl
             << "filter input_file [size_threshold | - ] [plot_title]" << endl
             << "filter --help\t : print this message" << endl;
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
        length_thr = 1000;
    }
    if (argc >= 4)
    {
        plot_title = argv[3];
    }
    if (argc >= 5 && strcmp(argv[4], "nokey") == 0)
    {
         no_key = true;
    }

    string input_addr(argv[1]);
    ifstream inp(input_addr.c_str());
    system("rm -rf connections");
    system("mkdir connections");
    long connection_count = 0;
    bool plot_only = false;
    map<string,long> plot_index;
    map<string,long> max_len;
    map<string,type_e> connection_type; // false = UDP, true = TCP
    map<string,ofstream*> file_map;
    map<string,ofstream*>::iterator it;
    map<string,long> udp_offset;
    long i = 0;
    long seq1, seq2, len;
    char waste;
    int hh,mm,ss;
    long double micros;

    string p1, p2, protocol;
    string temp;
    long double start;
    long double ttime = 0;
    bool flag = false, first = false;
    inp >> hh; inp.get();
    inp >> mm; inp.get();
    inp >> ss; inp.get();
    inp >> micros;
    start = hh * 3600 + mm * 60 + ss + micros / 1000000;
    eatspaces(inp);
    inp >> temp >> p1 >> temp >> p2 >> protocol; //>> seq1;
    p2.resize(p2.size()-1);
    ttime = start;
    if (protocol == "Flags") // TCP
    {
        inp >> temp >> temp;
        inp >> seq1;

        if (inp.peek()==':')
        {
            flag = true;
            inp.get();
            inp >> seq2;
        }
        if(flag)
        {
            file_map[(p1 + "-" + p2)] = new ofstream(("connections/" + p1 + "-" + p2).c_str());
            plot_index[(p1 + "-" + p2)] = connection_count++;
            max_len[(p1 + "-" + p2)] = seq2;
            connection_type[(p1 + "-" + p2)] = TCP;
            (*(file_map[p1+ "-" + p2])) << "0.000000 0" << endl;
            flag = false;
        }
    }
    else if (protocol == "UDP,") // UDP
    {
        inp >> temp;
        inp >> len;

        file_map[(p1 + "-" + p2)] = new ofstream(("connections/" + p1 + "-" + p2 + "_UDP").c_str());
        plot_index[(p1 + "-" + p2)] = connection_count++;
        udp_offset[(p1 + "-" + p2)] = len;
        max_len[(p1 + "-" + p2)] = len;
        connection_type[(p1 + "-" + p2)] = UDP;
        (*(file_map[p1+ "-" + p2])) << "0.000000" << len << endl;
        flag = false;
    }
    skipline(inp);
    eatspaces(inp);

    while(!inp.eof())
    {
        eatspaces(inp);
        inp >> hh; inp.get();
        inp >> mm; inp.get();
        inp >> ss; inp.get();
        inp >> micros;
        ttime = hh * 3600 + mm * 60 + ss  + micros / 1000000 - start;

        eatspaces(inp);
        inp >> temp >> p1 >> temp >> p2 >> protocol; //>> seq1;
        p2.resize(p2.size()-1);

        if (protocol == "Flags") // TCP
        {
            inp >> temp >> temp;
            inp >> seq1;

            if (inp.peek()==':')
            {
                flag = true;
                inp.get();
                inp >> seq2;
            }
            skipline(inp);
            if(flag)
            {
                if(file_map.count(p1 + "-" + p2) == 0)
                {
                    file_map[(p1 + "-" + p2)] = new ofstream(("connections/" + p1 + "-" + p2).c_str());
                    plot_index[(p1 + "-" + p2)] = connection_count++;
                    connection_type[(p1 + "-" + p2)] = TCP;
                    flag = false;
                    (*(file_map[p1+ "-" + p2])) << "0.000000 0" << endl;
                    continue;
                }

                (*(file_map[p1+ "-" + p2])) << setprecision(14) << ttime << " " << seq2 << endl;
                max_len[(p1 + "-" + p2)] = seq2;
                eatspaces(inp);
                flag = false;
            }
        }
        else if (protocol == "UDP,") // UDP
        {
            inp >> temp;
            inp >> len;
            if(file_map.count(p1 + "-" + p2) == 0)
            {
                file_map[(p1 + "-" + p2)] = new ofstream(("connections/" + p1 + "-" + p2 + "_UDP").c_str());
                plot_index[(p1 + "-" + p2)] = connection_count++;
                udp_offset[(p1 + "-" + p2)] = len;
                connection_type[(p1 + "-" + p2)] = UDP;
                first = true;
            }

            udp_offset[(p1 + "-" + p2)] += len;
            max_len[(p1 + "-" + p2)] = len;
            (*(file_map[p1+ "-" + p2])) << setprecision(14) << ttime << " " << udp_offset[(p1 + "-" + p2)] << endl;
        }
        skipline(inp);
        eatspaces(inp);
    }
    ofstream index_file("connection_index.txt");

    ofstream plot("plot.gp");
    plot    << "set style data lines"  << endl
            << "set title \"" << plot_title << " (cutoff threshold = " << length_thr << ")\"" << endl
            << "set key out right" << endl
            << (no_key ? "set key off\n" : "")
            << "set xlabel \"Time (seconds)\"" << endl
            << "set ylabel \"Cumulative Transfer (MB)\"" << endl
            << "set term postscript color eps enhanced \"Helvetica\" 8" << endl
            << "set size ratio 0.5" << endl
            << "# Line style for axes" << endl
            << "set style line 80 lt 0" << endl
            << "set grid back linestyle 81" << endl
            << "set border 3 back linestyle 80" << endl
            << "set xtics nomirror" << endl
            << "set ytics nomirror" << endl
            << "set out \'p.ps\'" << endl << "plot ";

    first = false;
    long MAX = 0;
    for(map<string,long>::iterator it = max_len.begin(); it != max_len.end(); it++)
    {
        MAX = (MAX > it->second ? MAX : it->second);
    }

    for(map<string,long>::iterator it = max_len.begin(); it != max_len.end(); it++)
    {
        index_file << plot_index[it->first] << "\t -> \t" << (it->first + (connection_type[it->first] == UDP ? "_UDP" : "")) << endl;
        if(it->second * length_thr < MAX) continue;
        if(connection_type[it->first] == TCP)
        {
            if(first) { plot << ", \\\n";}
            plot << "\"connections/" << it->first << "\" using 1:($2/1e6) with lines title \"" << plot_index[it->first] << "\"";
            if(!first) first = true;
        }
        else
        {
            if(first) { plot << ", \\\n";}
            plot << "\"connections/" << it->first << "_UDP\" using 1:($2/1e6) with lines title \"" << plot_index[it->first] << "(UDP)\"";
            if(!first) first = true;
        }

    }
    plot << endl;
    plot.close();
    system("gnuplot plot.gp");
    system("convert -density 1000 p.ps -scale 2000x1000 p.jpg");
    return 0;
}
