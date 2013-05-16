# We have the list of IP address from which the clients connect to the Meddle server
# based on the IP address, get the location, country, timezone, and isp info
# Also based on the isp label the connection to be either wireless or cellular
# Code to annotate the AS with the access technology 
# Also convert the IP/network to ip network and subnet mask for easy processing
baseDir<-"/home/arao/meddle_data/"
scriptsDir<-paste(baseDir, "parsing-scripts/", sep="");
ipDataDir<-paste(baseDir, "ipData/", sep="");
ipInfoFName <- "clientIPInfo.txt"
#baseDir<-"/home/arao/proj-work/meddle/arao-meddle/meddle/code/PcapProcessing/bro-analysis/gen-analysis-logs/"
#scriptsDir<-baseDir;
#ipDataDir<-baseDir;
setwd(scriptsDir);

gWifiStr="Wi-Fi"
gCellularStr ="Cellular"
gUnknownStr = "Unknown"

library(bitops)

getIPFromString <- function (ipString) {
  # Convert the ip from dotted form to integer
  ipBits <- unlist(strsplit(ipString, "\\.")) 
  x <- bitOr(bitOr(bitShiftL(ipBits[1],24), bitShiftL(ipBits[2], 16)), bitOr(bitShiftL(ipBits[3], 8), bitShiftL(ipBits[4],0)))  
}

getIPMaskFromSlash <- function(slash) {
  # Generate the bitmask from the / number , for example FF FF FF 00 -> /24 
  x <- bitFlip(0, bitWidth=32) - bitFlip(0, bitWidth=(32 - as.numeric(slash)))
}

annotateIPNetworkSubnetMask <- function (ipInfo) {
  IPNetwork <- rep(0, nrow(ipInfo))
  IPMask <- rep(0, nrow(ipInfo))
  for (i in 1:nrow(ipInfo)) {
    entry <- ipInfo[i,]
    strPrefix <- entry$ip_prefix;
    strPrefix <- unlist(strsplit(strPrefix, "/"))
    IPNetwork[i] <- getIPFromString(strPrefix[1])
    IPMask[i] <- getIPMaskFromSlash(strPrefix[2])
  }
  ipInfo$ip_network <- IPNetwork
  ipInfo$ip_subnet <- IPMask
  ipInfo 
}

annotateAccessTechnology <- function(ipInfo) { 
  # Note please verify the same with Dave and other others if the results are accurate.
  # unique(ipInfo[ipInfo$technology=="Cellular", ]$isp_info)
  signatureWifi <- c("integra", "internet4", "inria", "covad", "deutsche", "cable"
                     "megapath",  "core", "dummy", "university", "cable", "frontier\ communication",
                     "comcast", "renater", "sonic", "proxad", "myloc", "interoute",
                     "at&t\ internet", "qwest", "awg-", "airport", "prolocation",
                     "thecloud", "google", "amazon","microsoft", "spacelink",
                     "shaw\ communication", "janet", "host\ europe", "bell\ canada",
                     "internet\ backbone", "paetec\ communications",
                     "telus\ advanced", "bouygtel-isp",
                     "wayport", "cox\ communication", "worldlinx")
  technology <- rep(gCellularStr, nrow(ipInfo))
  for (signature in signatureWifi) {
    technology[grep(signature, ipInfo$isp_info, ignore.case=TRUE)] <- gWifiStr
  }  
  ipInfo$technology <- technology
  ipInfo  
}

annotateTimeZone <- function(ipInfo) {
  # Note that ISP and COUNTRY and TIMEZONE are matched
  # /usr/share/zoneinfo/zone.tab
  timeZoneLookUp = data.frame(country=unlist(c("CA", "DE", "FR", "GB", 
                                               "IE", "IN", "NL", "US")),
                              timeZone=unlist(c("America/Los_Angeles", "Europe/Berlin", 
                                                "Europe/Paris", "Europe/London", 
                                                "Europe/Dublin", "Asia/Calcutta",
                                                "Europe/Amsterdam", "America/Los_Angeles")),
                              stringsAsFactors=FALSE);
  # This is flawed to an extent because we need to take into account different timezones for a country
  # ideally the IP or Service provider should also be used to lookup the data
  tzString <- rep("America/Los_Angeles", nrow(ipInfo))
  for (i in 1:nrow(timeZoneLookUp)) {
    country <- timeZoneLookUp[i, ]$country
    tzVal <- timeZoneLookUp[i, ]$timeZone
    tzString[ipInfo$country==country] <- tzVal
  }
  # hardcoded strings come here
  tzString[(ipInfo$country=="US" && ipInfo$isp_info == "AWG-BOS - Advanced Wireless Group, LLC")] <- "America/New_York";
  ipInfo$timeZone <- tzString
  ipInfo
}

masterAnnotate <- function () {
    # Load the whois data and annotate the technology based on the service provider
  fName <- paste(ipDataDir, ipInfoFName, sep="");
  # Make sure you remove the trailing white spaces and tabs else row.names=NULL error will be seen
  ipInfo <- read.table(fName, header=TRUE, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  # default technology is unknown  
  ipInfo <- annotateIPNetworkSubnetMask(ipInfo)
  ipInfo <- annotateAccessTechnology(ipInfo)
  ipInfo <- annotateTimeZone(ipInfo)
  #unique(ipInfo[ipInfo$technology=="Cellular", ]$isp_info)  
  fName <- paste(ipDataDir, ipInfoFName, ".ann", sep="");
  write.table(ipInfo, fName, sep="\t", quote=F, col.names=c(colnames(connMeta)), row.names=FALSE)
}

masterAnnotate
