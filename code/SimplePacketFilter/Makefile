CXXFLAGS = -O3 -g -Wall -fmessage-length=0
LIBS= -lboost_thread  -lboost_date_time
SRC = $(wildcard $(PWD)/*.cc)
OBJS = $(SRC:.cc=.o)

FILTERMAINSRC = $(PWD)/SignalUserUpDown.cc
FILTERMAINOBJS = $(FILTERMAINSRC:.cc=.o)
MAINOBJS = $(filter-out $(FILTERMAINOBJS), $(OBJS))
MAIN = SimplePacketFilter

FILTERSIGNALSRC = $(PWD)/SimplePacketFilter.cc $(PWD)/CommandHandler.cc
FILTERSIGNALOBJS = $(FILTERSIGNALSRC:.cc=.o)
SIGNALOBJS = $(filter-out $(FILTERSIGNALOBJS), $(OBJS))
SIGNALUSER = SignalUserUpDown

%.o : %.cc
	$(CXX) $(LIBS) $(CFLAGS) -c $<

all: clean $(MAIN) $(SIGNALUSER)

distclean: clean
	rm -f $(MAIN)	

clean:
	rm -f $(OBJS)

$(MAIN): $(MAINOBJS)
	$(CXX)  -o $(MAIN) $(MAINOBJS) $(LIBS) 

$(SIGNALUSER) : $(SIGNALOBJS)
	$(CXX)  -o $(SIGNALUSER) $(SIGNALOBJS) $(LIBS) 

