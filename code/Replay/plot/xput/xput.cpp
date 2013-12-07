#include <iostream>
#include <vector>
#include <fstream>
#include <cstring>

using namespace std;


// This will eath through white spaces.
void eatspaces(istream &inp)
{
    while(inp.peek() == ' ' || inp.peek() == '\n') inp.get();
}

// Skip the rest of the line.
void skipline(istream &inp)
{
    while(inp.get() != '\n');
}


int main(int argc, char **argv)
{
    if (argc < 2)
    {
        cerr << "No output file given." << endl;
        return -1;
    }
    if (argc >= 2 && (strcmp(argv[1],"--help") == 0 || strcmp(argv[1],"?") == 0 || strcmp(argv[1], "-help") == 0 || strcmp(argv[1],"-h") == 0))
    {
        cout << "Usage:" << endl
             << "xput output_file" << endl
             << "xput --help\t : print this message" << endl << endl;
        return 0;
    }

    double xput_interval = 0.1;
    string temp;
    vector<double> xputs;
    ofstream output_file(argv[1]);

    for (int i = 0; i < 3; i++) skipline(cin);

    cin >> temp;
    cin.get();
    cin >> xput_interval;

    for (int i = 0; i < 4; i++) skipline(cin);

    double start, end;
    long frames, bytes;

    while(!cin.eof())
    {
        if (cin.peek() == '=') break;
        cin >> start;
        cin.get();
        cin >> end;
        cin >> frames >> bytes;
        skipline(cin);
        output_file << end << "\t" << double(bytes) / xput_interval << endl;
        xputs.push_back(double(bytes) / xput_interval);
    }
    output_file.close();

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


    cout << "xput_max\t" << xp_max / 1e+3 << endl;
    cout << "xput_avg\t" << (xp_sum / xputs.size()) / 1e+3 << endl;
    cout << "xput_mdn\t" << xputs[xputs.size() / 2] / 1e+3 << endl;

    return 0;
}
