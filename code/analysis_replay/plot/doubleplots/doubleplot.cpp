#include <iostream>
#include <cstdlib>
#include <string>
#include <cstring>
#include <fstream>

using namespace std;

// This will eath through white spaces.
void eatspaces(ifstream &inp)
{
    while(inp.peek() == ' ' || inp.peek() == '\n') inp.get();
}

// Skip the rest of the line.
void skipline(ifstream &inp)
{
    while(inp.get() != '\n');
}

int main(int argc, char **argv)
{
    // Parsing arguments.
    if (argc < 2)
    {
        cerr << "No input directories given." << endl;
        return -1;
    }
    if (argc < 3)
    {
        cerr << "Two input directories are needed." << endl;
        return -1;
    }

    // Input file address.
    string input1_addr(argv[1]);
    // Input file handle.
    ifstream inp1((input1_addr + "/connection_index.txt").c_str());

    // Input file address.
    string input2_addr(argv[2]);
    // Input file handle.
    ifstream inp2((input2_addr + "/connection_index.txt").c_str());

    string index, address, waste;

    system(("rm -rf " + input1_addr + "_" + input2_addr + "-plot").c_str());
    system(("mkdir " + input1_addr + "_" + input2_addr + "-plot").c_str());
    ofstream plot((input1_addr + "_" + input2_addr + "-plot/plot.gp").c_str());
    plot    << "set style data lines"  << endl
            << "set key out right" << endl
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
            << "set out \'doublep.ps\'" << endl << "plot ";

    bool first = false;
    int color = 2;
    while(!inp1.eof())
    {
        inp1 >> index >> waste >> address;
        eatspaces(inp1);

        if(first) { plot << ", \\\n";}
        plot    << "\"../" << input1_addr << "/connections/" << address << "\" using 1:($2/1e6) with lines lw 3 lt 1 linecolor " << color++ <<  " title \""
                << input1_addr << " (" << index << ")\"";
        if(!first) first = true;
    }

    color = 2;
    while(!inp2.eof())
    {
        inp2 >> index >> waste >> address;
        eatspaces(inp2);

        if(first) { plot << ", \\\n";}
        plot    << "\"../" << input2_addr << "/connections/" << address << "\" using 1:($2/1e6) with lines lw 3 lt 3 linecolor " << color++ <<  " title \""
                << input2_addr << " (" << index << ")\"";
        if(!first) first = true;
    }

    plot.close();

    // Draw the plot.
    system(("echo gnuplot plot.gp >" + input1_addr + "_" + input2_addr + "-plot/draw.sh").c_str());
    // Convert it to JPEG for convenience.
    system(("echo convert -density 1000 doublep.ps -scale 2000x1000 p.jpg >>" + input1_addr + "_" + input2_addr + "-plot/draw.sh").c_str());
    // Make it executable.
    system(("chmod +x " + input1_addr + "_" + input2_addr + "-plot/draw.sh").c_str());
    return 0;
}
