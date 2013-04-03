#include <boost/program_options.hpp>
#include <iostream>
#include <fstream>
#include <string>

#include "MeddleConfig.h"
#include "Logging.h"
#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/erase.hpp>

namespace po = boost::program_options;

MeddleConfig::MeddleConfig()
{
	validConfig = false;
}

MeddleConfig::MeddleConfig(std::string configName)
{
	validConfig = readConfigFile(configName);
	return;
}

inline void MeddleConfig::removeQuote(std::string &quotedString)
{
	// remove trailing whitespaces
	boost::trim(quotedString);
	// remove the quotes
	quotedString.erase(std::remove(quotedString.begin(), quotedString.end(), '\"'), quotedString.end());
	return;
}

bool MeddleConfig::handleQuotes()
{
	removeQuote(tunDeviceName); removeQuote(tunFwdPathNet);
	removeQuote(tunRevPathNet); removeQuote(tunIpNetmask);
	removeQuote(tunRouteNetmask); removeQuote(tunIpAddress);

	removeQuote(msgSockPort); removeQuote(msgSockIpAddress);

	removeQuote(fltrDefaultDNS); removeQuote(fltrAdBlockDNS);

	removeQuote(dbServer); removeQuote(dbUserName);
	removeQuote(dbPassword); removeQuote(dbName);
	return true;
}
bool MeddleConfig::readConfigFile(std::string configName)
{
	std::ifstream configFile;
	configFile.open(configName.c_str());
	if (false == configFile.is_open()) {
		logError("Error in opening the configuration file" << configName);
		return false;
	}
	try {
		po::variables_map vm;
		bindVariables();
		// the last parameter is to allow_unregistered options -- these options are the ones used in the shell scripts
		po::store(po::parse_config_file(configFile, desc, true), vm);
		po::notify(vm);
		handleQuotes();
	} catch(std::exception& e) {
			logError("Error: " << e.what() << ". The valid options are as follows" << std::endl << desc);
			configFile.close();
			return false;
	} catch(...) {
			logError("Unknown error!");
			configFile.close();
			return false;
	}
	configFile.close();
	return true;
}

bool MeddleConfig::bindVariables()
{
	logDebug("Binding variables");
	// Tunnel options
	desc.add_options()
		("tunDeviceName", po::value<std::string>(&tunDeviceName)->required(), "The name of the tun device. (tun0)")
		("tunFwdPathNet", po::value<std::string>(&tunFwdPathNet)->required(), "The network of the mobile clients when entering the tun device from the mobile network")
		("tunRevPathNet", po::value<std::string>(&tunRevPathNet)->required(), "The network of the mobile clients after leaving the tun device to the rest of the Internet.")
		("tunIpNetmask", po::value<std::string>(&tunIpNetmask)->required(), "The network mask for the IP address assigned to the tunnel device")
		("tunRouteNetmask", po::value<std::string>(&tunRouteNetmask)->required(), "The network mask to check if the given packet is in the forward direction or reverse direction (When a mobile phone contacts a web server, forward is mobile to web server, and reverse is from web server to mobile device)")
		("tunIpAddress", po::value<std::string>(&tunIpAddress)->required(), "The IP address of the tunnel device");

	// Message Handling Options
	desc.add_options()
		("msgSockPort", po::value<std::string>(&msgSockPort)->required(), "The port on which the message handler listens to messages from auxillary programs.")
		("msgSockIpAddress", po::value<std::string>(&msgSockIpAddress)->required(), "The IP address on which the message handler listens to messages from auxillary programs");

	// Filtering Options
	desc.add_options()
		("fltrDefaultDNS", po::value<std::string>(&fltrDefaultDNS)->required(), "The default DNS server provided by Strongswan to the mobile clients")
		("fltrAdBlockDNS", po::value<std::string>(&fltrAdBlockDNS)->required(), "The DNS server which provides the ad blocking service");

	// Database Options
	desc.add_options()
		("dbServer", po::value<std::string>(&dbServer)->required(), "The hostname of the machine on which the database server is running")
		("dbUserName", po::value<std::string>(&dbUserName)->required(), "The username to access the database")
		("dbPassword", po::value<std::string>(&dbPassword)->required(), "The password to access the database")
		("dbName", po::value<std::string>(&dbName)->required(), "The name of the database");
	return true;
}

MeddleConfig::~MeddleConfig()
{

};

std::ostream& operator<<(std::ostream& os, const MeddleConfig &mc)
{
	os << "Tunnel Params " << std::endl
			<< " Device " << mc.tunDeviceName
			<< " Netmask " << mc.tunIpNetmask
			<< " IP " << mc.tunIpAddress
			<< " FwdPath " << mc.tunFwdPathNet
			<< " RevPath " << mc.tunRevPathNet
			<< std::endl;
	os << "DB Params" << std::endl
			<< " Server " << mc.dbServer
			<< " Name " << mc.dbName
			<< " user " << mc.dbUserName
			<< " password " << mc.dbPassword
			<<std::endl;

	os << "Message Params" << std::endl
			<< " IP " << mc.msgSockIpAddress
			<< " port " << mc.msgSockPort
			<<std::endl;
	return os;
}