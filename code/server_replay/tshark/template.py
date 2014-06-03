"""@package docstring

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    Dec 2013
"""
import os, sys
import python_lib 
from python_lib import Configs, PRINT_ACTION

def run(args):
    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()

def main():
    run(sys.argv)

if __name__=="__main__":
    main()