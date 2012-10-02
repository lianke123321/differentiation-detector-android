CXXFLAGS = -O3 -Wall -fmessage-length=0
LIBS= -lboost_thread-mt  -lboost_date_time -lmysqlclient -lpthread -lz -lm -lrt -ldl
LIBDIR = -L/usr/lib/x86_64-linux-gnu -L/usr/lib64/mysql/ -L/usr/lib64/
SRC = $(wildcard $(PWD)/*.cc)
OBJS = $(SRC:.cc=.o)
# mysql_config --libs
# -L/usr/lib/x86_64-linux-gnu -lmysqlclient -lpthread -lz -lm -lrt -ldl

FILTERMAINSRC = $(PWD)/SignalUserUpDown.cc
FILTERMAINOBJS = $(FILTERMAINSRC:.cc=.o)
MAINOBJS = $(filter-out $(FILTERMAINOBJS), $(OBJS))
MAIN = SimplePacketFilter

FILTERSIGNALSRC = $(PWD)/SimplePacketFilter.cc $(PWD)/CommandHandler.cc $(PWD)/ReadDatabase.cc $(PWD)/MeddleDaemon.cc
FILTERSIGNALOBJS = $(FILTERSIGNALSRC:.cc=.o)
SIGNALOBJS = $(filter-out $(FILTERSIGNALOBJS), $(OBJS))
SIGNALUSER = SignalUserUpDown

%.o : %.cc
	$(CXX) $(LIBS) $(CFLAGS) -c $<

all: $(MAIN) $(SIGNALUSER)

distclean: clean
	rm -f $(MAIN)	

clean:
	rm -f $(OBJS)

$(MAIN): $(MAINOBJS)
	$(CXX) $(LIBDIR) -o $(MAIN) $(MAINOBJS) $(LIBS) 

$(SIGNALUSER) : $(SIGNALOBJS)
	$(CXX) $(LIBDIR) -o $(SIGNALUSER) $(SIGNALOBJS) $(LIBS) 

