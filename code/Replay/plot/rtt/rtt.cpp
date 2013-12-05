#include <iostream>
#include <fstream>
#include <cstring>
#include <string>
#include <vector>

using namespace std;

int main(int argc, char **argv)
{
    // Parsing arguments.
    if (argc < 2)
    {
        cerr << "No input given." << endl;
        return -1;
    }
    if (argc >= 2 && (strcmp(argv[1],"--help") == 0 || strcmp(argv[1],"?") == 0 || strcmp(argv[1], "-help") == 0 || strcmp(argv[1],"-h") == 0))
    {
        cout   << "Usage:" << endl
                << "rtt input_file" << endl;
    }

    // Input file address.
    string input_addr(argv[1]);
    // Input file handle.
    ifstream inp(input_addr.c_str());

    // Current RTT.
    double rtt;

    // List of all RTTs
    vector<double> rtts;
    while(!inp.eof())
    {
        inp >> rtt;
        rtts.push_back(rtt);
    }

    double rtt_max = rtts[0];
    double rtt_min = rtts[0];
    double rtt_sum = 0;

    // Find the maximum throughput and calculate the sum of all throughputs.
    for(int i = 0; i < rtts.size(); i++)
    {
        if (rtt_max < rtts[i])
            rtt_max = rtts[i];
        if (rtt_min > rtts[i])
            rtt_min = rtts[i];
        rtt_sum += rtts[i];
    }


    // Simplest sorting algorithm in the world! :)
    bool swapped = false;
    for(int i = rtts.size(); i > 0; i--)
    {
        swapped = false;
        for (int j = 1; j <= i; j++)
        {
            if (rtts[i-1] > rtts[i])
            {
                swap(rtts[i-1], rtts[i]);
                swapped = true;
            }
        }
        if(!swapped)
            break;
    }

    cout << "Maximum RTT: " << rtt_max * 1000 << " ms" << endl;
    cout << "Minimum RTT: " << rtt_min * 1000 << " ms" << endl;
    cout << "Mean RTT: " << rtt_sum / rtts.size() * 1000 << " ms" << endl;
    cout << "Median RTT: " << rtts[rtts.size() / 2] * 1000 << " ms" << endl;

    return 0;
}
