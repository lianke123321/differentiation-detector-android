#include <iostream>
#include <cmath>

using namespace std;

int main()
{
    double x, x2;
    long count = 0;
    int arr[200000];
    while(!cin.eof())
    {
	cin >> x;
	arr[count++] = x;
    }

    x = 0;
    for (long i = count * 0.1; i < count * 0.9; i++)
    {
	x += arr[i];
	x2 += arr[i] * arr[i];
    }
    
    cout << "nt_avg: " << (double(x) / double(count)) << "\t nt_stddev: " << sqrt(double(x2) / double(count) - pow(double(x) / double(count),2)) << endl;
    return 0;
}