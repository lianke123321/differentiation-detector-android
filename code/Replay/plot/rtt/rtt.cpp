#include <iostream>
#include <fstream>
#include <string>
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

int main(int argc, char ** argv)
{
    string s;
    
    cin >> s;
    
    eatspaces(cin);
    cin >> s;
    cout << "file\t" << s << endl;
    
    eatspaces(cin);
    if(cin.eof()) return 0;
    cin >> s >> s >> s;
    cout << "rtt_ab_min\t" << s << endl;
    cin >> s >> s >> s >> s;
    cout << "rtt_ba_min\t" << s << endl;
    skipline(cin);
    
    eatspaces(cin);
    cin >> s >> s >> s;
    cout << "rtt_ab_max\t" << s << endl;
    cin >> s >> s >> s >> s;
    cout << "rtt_ba_max\t" << s << endl;
    skipline(cin);
    
    eatspaces(cin);
    cin >> s >> s >> s;
    cout << "rtt_ab_avg\t" << s << endl;
    cin >> s >> s >> s >> s;
    cout << "rtt_ba_avg\t" << s << endl;
    skipline(cin);
    
    eatspaces(cin);
    cin >> s >> s >> s;
    cout << "rtt_ab_stdev\t" << s << endl;
    cin >> s >> s >> s >> s;
    cout << "rtt_ba_stdev\t" << s << endl;
    skipline(cin);
    
    return 0;
}
