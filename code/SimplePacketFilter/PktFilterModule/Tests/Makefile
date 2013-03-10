CXXFLAGS = -g -I $(PWD)/../ -Wall -fmessage-length=0
SRC = $(wildcard $(PWD)/*.cc)
OBJS = $(SRC:.cc=.o)
MAINSRC = $(filter-out $(PWD)/../SimplePacketFilter.cc, $(wildcard $(PWD)/../*.cc))
MAINOBJS = $(MAINSRC:.cc=.o)
TMP=$(shell date +%s)

all:clean $(OBJS)

%.o : %.cc
	$(CXX) $(CXXFLAGS) -o $@ $< $(MAINOBJS)
	
clean:
	echo $(TMP)
	rm -f $(OBJS)
