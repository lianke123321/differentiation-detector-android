include meddle.config
CXXFLAGS = -Wall -Werror
# -O has been removed because the optimization causes the checksum code to break! 
LIBS= -lboost_thread-mt  -lboost_date_time -lboost_program_options -lmysqlclient -lpthread -lz -lm -lrt -ldl
LIBDIR = -L/usr/lib/ -L/usr/lib/mysql/ -L/usr/lib/
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
	$(CXX) $(LIBS) $(CXXFLAGS) -c $<

all: clean $(MAIN) $(SIGNALUSER) $(SIGNALCONFIG)

distclean: clean
	rm -f $(MAIN)	

clean:
	rm -f $(OBJS) $(SIGNALUSER) $(MAIN) $(SIGNALCONFIG)

$(MAIN): $(MAINOBJS)
	$(CXX) $(LIBDIR) -o $(MAIN) $(MAINOBJS) $(LIBS)

$(SIGNALUSER) : $(SIGNALUSEROBJS)
	$(CXX) $(LIBDIR) -o $(SIGNALUSER) $(SIGNALUSEROBJS) $(LIBS)

$(SIGNALCONFIG) : $(SIGNALCONFIGOBJS)
	$(CXX) $(LIBDIR) -o $(SIGNALCONFIG) $(SIGNALCONFIGOBJS) $(LIBS)

install: $(MAIN) $(SIGNALUSER) $(SIGNALCONFIG)
	cp -v meddle.config $(MEDDLE_ROOT)
	cp -v SetupPacketFilter.sh $(MAIN) $(SIGNALUSER) $(SIGNALCONFIG) $(MEDDLE_ROOT)/usr/sbin/
	ln -sf $(MEDDLE_ROOT)/meddle.config $(MEDDLE_ROOT)/usr/sbin/
	cp -vR meddle_root_files/* $(MEDDLE_ROOT)/
	# Replace the quotes and escape the /s 
	sed -i 's/MEDDLE_ROOT_PATH_FILLER/$(subst /,\/,$(subst ",,$(MEDDLE_ROOT)))/g' $(MEDDLE_ROOT)/usr/lib/ipsec/_updown
