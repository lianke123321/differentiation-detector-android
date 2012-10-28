CXXFLAGS = -O3 -Wall -fmessage-length=0
LIBS= -lboost_thread-mt  -lboost_date_time -lmysqlclient -lpthread -lz -lm -lrt -ldl
LIBDIR = -L/usr/lib/x86_64-linux-gnu -L/usr/lib64/mysql/ -L/usr/lib64/
SRC = $(wildcard $(PWD)/*.cc)
OBJS = $(SRC:.cc=.o)
# mysql_config --libs
# -L/usr/lib/x86_64-linux-gnu -lmysqlclient -lpthread -lz -lm -lrt -ldl

FILTERMAINSRC = $(PWD)/SignalUserUpDown.cc $(PWD)/SignalConfigChange.cc
FILTERMAINOBJS = $(FILTERMAINSRC:.cc=.o)
MAINOBJS = $(filter-out $(FILTERMAINOBJS), $(OBJS))
MAIN = SimplePacketFilter

FILTERUSERSIGNALSRC = $(PWD)/SimplePacketFilter.cc $(PWD)/MessageHandler.cc $(PWD)/ReadDatabase.cc $(PWD)/MeddleDaemon.cc $(PWD)/SignalConfigChange.cc
FILTERUSERSIGNALOBJS = $(FILTERUSERSIGNALSRC:.cc=.o)
SIGNALUSEROBJS = $(filter-out $(FILTERUSERSIGNALOBJS), $(OBJS))
SIGNALUSER = SignalUserUpDown

FILTERCONFIGSIGNALSRC = $(PWD)/SimplePacketFilter.cc $(PWD)/MessageHandler.cc $(PWD)/ReadDatabase.cc $(PWD)/MeddleDaemon.cc $(PWD)/SignalUserUpDown.cc
FILTERCONFIGSIGNALOBJS = $(FILTERCONFIGSIGNALSRC:.cc=.o)
SIGNALCONFIGOBJS = $(filter-out $(FILTERCONFIGSIGNALOBJS), $(OBJS))
SIGNALCONFIG = SignalConfigChange

%.o : %.cc
	$(CXX) $(LIBS) $(CFLAGS) -c $<

all: $(MAIN) $(SIGNALUSER) $(SIGNALCONFIG)

distclean: clean
	rm -f $(MAIN)	

clean:
	rm -f $(OBJS) $(SIGNALUSER) $(MAIN)

$(MAIN): $(MAINOBJS)
	$(CXX) $(LIBDIR) -o $(MAIN) $(MAINOBJS) $(LIBS) 

$(SIGNALUSER) : $(SIGNALUSEROBJS)
	$(CXX) $(LIBDIR) -o $(SIGNALUSER) $(SIGNALUSEROBJS) $(LIBS)

$(SIGNALCONFIG) : $(SIGNALCONFIGOBJS)
	$(CXX) $(LIBDIR) -o $(SIGNALCONFIG) $(SIGNALCONFIGOBJS) $(LIBS)