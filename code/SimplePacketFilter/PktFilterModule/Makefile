include meddle.config
CXXFLAGS = -Wall -Werror
# -O has been removed because the optimization causes the checksum code to break! 
LIBS= -lboost_thread-mt  -lboost_date_time -lboost_program_options -lmysqlclient -lpthread -lz -lm -lrt -ldl
LIBDIR = -L/usr/lib64/ -L/usr/lib64/mysql/ 
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

TMP_VAR = $(shell date +%s)

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

take_backups:
	echo "Taking backups if they exist"
	if test -f $(MEDDLE_ROOT)/etc/ipsec.secrets ; then cp -v $(MEDDLE_ROOT)/etc/ipsec.secrets $(MEDDLE_ROOT)/etc/.ipsec.secrets.backup.$(TMP_VAR); else echo "ipsec.secrets file not present in MEDDLE_ROOT therefore not taking any backup"; fi
	if test -f $(MEDDLE_ROOT)/meddle.config; then cp -v $(MEDDLE_ROOT)/meddle.config $(MEDDLE_ROOT)/.meddle.config.backup.$(TMP_VAR); else echo "meddle.config file not present in MEDDLE_ROOT therefore not taking any backup"; fi
	#cp $(MEDDLE_ROOT)/etc/ipsec.secrets $(MEDDLE_ROOT)/etc/.ipsec.secrets.backup.$(TMP_VAR)
	#cp $(MEDDLE_ROOT)/meddle.config $(MEDDLE_ROOT)/.meddle.config.backup.$(TMP_VAR)

restore_backups:
	@echo "Attempting a restore of saved files"	
	@if test -f $(MEDDLE_ROOT)/etc/.ipsec.secrets.backup.$(TMP_VAR); then cp -v $(MEDDLE_ROOT)/etc/.ipsec.secrets.backup.$(TMP_VAR) $(MEDDLE_ROOT)/etc/ipsec.secrets; else echo "No backup was created therefore not restoring ipsec.secrets file"; fi

install_meddle_root_files:
	@echo "Installing files in $(MEDDLE_ROOT)"
	@cp -v meddle.config $(MEDDLE_ROOT)
	@cp -vR meddle_root_files/* $(MEDDLE_ROOT)/
# Replace the quotes and escape the /s 
	@echo "Modifications to the _updown script"
	@sed -i 's/MEDDLE_ROOT_PATH_FILLER/$(subst /,\/,$(subst ",,$(MEDDLE_ROOT)))/g' $(MEDDLE_ROOT)/usr/lib/ipsec/_updown
	@echo "Modifications for ipsec.conf"
	@sed -i 's/SERVER_HOSTNAME_FILLER/$(subst /,\/,$(subst ",,$(serverHostname)))/g' $(MEDDLE_ROOT)/etc/ipsec.conf
	@sed -i 's/ANDROID_PRIV_NETWORK_FILLER/$(subst /,\/,$(subst ",,$(tunClientAndroidNetwork)))/g' $(MEDDLE_ROOT)/etc/ipsec.conf
	@sed -i 's/IOS_PRIV_NETWORK_FILLER/$(subst /,\/,$(subst ",,$(tunClientIOSNetwork)))/g' $(MEDDLE_ROOT)/etc/ipsec.conf
	@sed -i 's/TEST_PRIV_NETWORK_FILLER/$(subst /,\/,$(subst ",,$(tunClientTestNetwork)))/g' $(MEDDLE_ROOT)/etc/ipsec.conf
	@sed -i 's/SERVER_IP_FILLER/$(subst /,\/,$(subst ",,$(tunIpAddress)))/g' $(MEDDLE_ROOT)/etc/ipsec.conf
	@echo "Modifications for strongswan.conf"
	@sed -i 's/DNS_IP_FILLER/$(subst /,\/,$(subst ",,$(fltrDefaultDNS)))/g' $(MEDDLE_ROOT)/etc/strongswan.conf
	@sed -i 's/MEDDLE_LOG_PATH_FILLER/$(subst /,\/,$(subst ",,$(MEDDLE_LOG_PATH)))/g' $(MEDDLE_ROOT)/etc/strongswan.conf
	@sed -i 's/MEDDLE_ROOT_FILLER/$(subst /,\/,$(subst ",,$(MEDDLE_ROOT)))/g' $(MEDDLE_ROOT)/credential-mgmt/certificate.config
	@echo "Modifications to ipsec.secrets"
	@sed -i 's/MEDDLE_SERVER_KEY_FILLER/$(subst /,\/,$(subst ",,$(serverKeyName)))/g' $(MEDDLE_ROOT)/etc/ipsec.secrets

install_pkt_filter: $(MAIN) $(SIGNALUSER) $(SIGNALCONFIG) 
	@echo "Installing the packet filter"
	@mkdir -p ${pcapDataPath}
	@cp -v SetupMeddle.sh $(MAIN) $(SIGNALUSER) $(SIGNALCONFIG) $(MEDDLE_ROOT)/usr/sbin/
	@sed -i 's/MEDDLE_ROOT_FILLER/$(subst /,\/,$(subst ",,$(MEDDLE_ROOT)))/g' $(MEDDLE_ROOT)/usr/sbin/SetupMeddle.sh
	@ln -sf $(MEDDLE_ROOT)/meddle.config $(MEDDLE_ROOT)/usr/sbin/

install: install_pkt_filter take_backups install_meddle_root_files restore_backups
	@echo "Done Installation!"
