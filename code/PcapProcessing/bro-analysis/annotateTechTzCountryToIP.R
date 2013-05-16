# Code to annotate the AS with the access technology 
# Also convert the IP/network to ip network and subnet mask for easy processing
baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "analysis-scripts/", sep="");
ipDataDir<-paste(baseDir, "miscData/", sep="");
ipInfoFName <- "clientIPInfo.txt"
#baseDir<-"/home/arao/proj-work/meddle/arao-meddle/meddle/code/PcapProcessing/bro-analysis/gen-analysis-logs/"
#scriptsDir<-baseDir;
#ipDataDir<-baseDir;
setwd(scriptsDir);

source(paste(scriptsDir, "readLogFiles.R", sep=""))

gWifiStr="w" # For wifi
gCellularStr ="c" # cellular
gUnknownStr = "u" # Unknown

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


assignIspIDs <-function(ipInfo) {
   isp_info <- unique(ipInfo$isp_info)
   isp_sigs <- unlist(lapply(isp_info, function(x) unlist(strsplit(x, " ")[1])[1]))
   isp_id <- 1:length(isp_info)
   ispNumTable <- data.frame(isp_id=isp_id, isp_info=isp_info, isp_sigs, stringsAsFactors=FALSE)
   ipInfo <- merge(x=ipInfo, y=ispNumTable, by="isp_info")
   write.table(ispNumTable, paste(ipDataDir, "isp_signature_table.txt", sep=""),
               sep="\t", quote=FALSE, row.names=FALSE)
   ipInfo
}

getIspIDs <- function(ipInfo) {
  ispIdTable <- readTable(paste(ipDataDir, "isp_signature_table.txt", sep=""))
  ipInfo <- merge(x=ipInfo, y=ispIdTable, by="isp_info")
  return (ipInfo)
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

annotateAccessTechnologyAndTimeZone <- function(ipInfo) {
  fName <- paste(ipDataDir, "isp_signature_table_manual.txt", sep="")
  sigTable <- readTable(fName)
  mergeTable <- data.frame(isp_info=sigTable$isp_info, 
                           time_zone=sigTable$time_zone,
                           technology=sigTable$technology, 
                           stringsAsFactors=F)
  ipInfo <- merge(x=ipInfo, y=mergeTable, by="isp_info")
  ipInfo
}
  
#annotateAccessTechnology <- function(ipInfo) { 
#  # Note please verify the same with Dave and other others if the results are accurate.
#  # unique(ipInfo[ipInfo$technology=="Cellular", ]$isp_info)
#  signatureWifi <- c("integra", "internet4", "inria", "covad", "deutsche", "cable",
#                     "megapath",  "core", "dummy", "university", "cable", "frontier\ communication",
#                     "comcast", "renater", "sonic", "proxad", "myloc", "interoute",
#                     "at&t\ internet", "qwest", "awg-", "airport", "prolocation",
#                     "thecloud", "google", "amazon","microsoft", "spacelink",
#                     "shaw\ communication", "janet", "host\ europe", "bell\ canada",
#                     "internet\ backbone", "paetec\ communications",
#                     "telus\ advanced", "bouygtel-isp",
#                     "wayport", "cox\ communication", "worldlinx")
#  technology <- rep(gCellularStr, nrow(ipInfo))
#  for (signature in signatureWifi) {
#    technology[grep(signature, ipInfo$isp_info, ignore.case=TRUE)] <- gWifiStr
#  }  
#  ipInfo$technology <- technology
#  ipInfo  
#}

#annotateTimeZone <- function(ipInfo) {
  # Note that ISP and COUNTRY and TIMEZONE are matched
  # /usr/share/zoneinfo/zone.tab
#  timeZoneLookUp = data.frame(country=unlist(c("CA", "DE", "FR", "GB", 
#                                               "IE", "IN", "NL", "US")),
#                              timeZone=unlist(c("America/Los_Angeles", "Europe/Berlin", 
#                                                "Europe/Paris", "Europe/London", 
#                                                "Europe/Dublin", "Asia/Calcutta",
#                                                "Europe/Amsterdam", "America/Los_Angeles")),
#                              stringsAsFactors=FALSE);
#  # This is flawed to an extent because we need to take into account different timezones for a country
#  # ideally the IP or Service provider should also be used to lookup the data
#  tzString <- rep("America/Los_Angeles", nrow(ipInfo))
#  for (i in 1:nrow(timeZoneLookUp)) {
#    country <- timeZoneLookUp[i, ]$country
#    tzVal <- timeZoneLookUp[i, ]$timeZone
#    tzString[ipInfo$country==country] <- tzVal
#  }
#  # hardcoded strings come here # TODO:: Build on top of this later
#  tzString[(ipInfo$country=="US" && ipInfo$isp_info == "AWG-BOS - Advanced Wireless Group, LLC")] <- "America/New_York";
#  ipInfo$time_zone <- tzString
#  ipInfo
#}

# NOTE THIS REQUIRES MANUAL STEPS SO DO NOT RUN IT AS BATCH
# Load the whois data and annotate the technology based on the service provider
fName <- paste(ipDataDir, ipInfoFName, sep="");
# # Make sure you remove the trailing white spaces and tabs else row.names=NULL error will be seen
ipInfo <- readTable(fName);
# # default technology is unknown  
# TODO:: UNCOMMENT THE FOLLOWING LINE TO INITIATE THE MANUAL ACTIVITY OF ASSIGNING ISP IDS
# ipInfo <- assignIspIDs(ipInfo)
ipInfo <- getIspIDs(ipInfo)
ipInfo <- annotateIPNetworkSubnetMask(ipInfo)

# Todo use utrace.de for getting timezone
# Also manually edit the isp_signature_table_manual.txt and annotate the time_zone 
# and access technology. This shall be used in the following two steps.  
# Also merge the ISP id manually in the isp_signature_table.tx

# TODO:: After manual step is done please uncomment the following lines
ipInfo <- annotateAccessTechnologyAndTimeZone(ipInfo)
ipInfo <- ipInfo[order(ipInfo$as),]
ipInfo$prefix_id=1:nrow(ipInfo)
unique(ipInfo[ipInfo$technology=="c", ]$isp_sig)  
unique(ipInfo[ipInfo$technology=="w", ]$isp_sig)  
fName <- paste(ipDataDir, ipInfoFName, ".info", sep="");
colNames <- colnames(ipInfo)
colNames <- colNames[order(colNames)]
write.table(ipInfo[colNames], fName, sep="\t", quote=F, col.names=colNames, row.names=FALSE)
