# Code to annotate the AS with the access technology 
# Also convert the IP/network to ip network and subnet mask for easy processing
baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "parsing-scripts/", sep="");
ipDataDir<-paste(baseDir, "miscData/", sep="");
ipInfoFName <- "clientIPInfo.txt"
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


createAsTable <-function(ipInfo) {
   as_info <- ipInfo
   #isp_sigs <- unlist(lapply(isp_info, function(x) unlist(strsplit(x, " ")[1])[1]))
   as_info <- as_info[!duplicated(as_info$as),]
   as_info$ip_prefix <- NULL;
   #as_tmp_id <- 1:length(as_info)  
   write.table(as_info, paste(ipDataDir, "as_table.txt", sep=""),
               sep="\t", quote=FALSE, row.names=FALSE) 
}

getAsTable <- function(ipInfo) {
  asTable <- readTable(paste(ipDataDir, "as_table.txt", sep=""))  
  return (asTable)
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
  fName <- paste(ipDataDir, "as_table_manual.txt", sep="")
  sigTable <- readTable(fName)
  mergeTable <- data.frame(as=sigTable$as,
                           isp_id=sigTable$isp_id,
                           time_zone=sigTable$time_zone,
                           technology=sigTable$technology, 
                           stringsAsFactors=F)
  ipInfo <- merge(x=ipInfo, y=mergeTable, by="as")
  return(ipInfo)
}
  
# NOTE THIS REQUIRES MANUAL STEPS SO DO NOT RUN IT AS BATCH
# Load the whois data and annotate the technology based on the service provider
fName <- paste(ipDataDir, ipInfoFName, sep="");
# # Make sure you remove the trailing white spaces and tabs else row.names=NULL error will be seen
ipInfo <- readTable(fName);
# # default technology is unknown  
# TODO:: UNCOMMENT THE FOLLOWING LINE TO INITIATE THE MANUAL ACTIVITY OF ASSIGNING ISP IDS
createAsTable(ipInfo)
#asTable <- getAsTable(ipInfo)
ipInfo <- annotateIPNetworkSubnetMask(ipInfo)

# Todo use utrace.de for getting timezone
# Also manually edit the isp_signature_table_manual.txt and annotate the time_zone 
# and access technology. This shall be used in the following two steps.  
# Also merge the ISP id manually in the isp_signature_table.tx

# TODO:: After manual step is done please uncomment the following lines
ipInfo <- annotateAccessTechnologyAndTimeZone(ipInfo)
ipInfo <- ipInfo[order(ipInfo$as),]
ipInfo$prefix_id=1:nrow(ipInfo)
unique(ipInfo[ipInfo$technology=="c", ]$isp_id)  
unique(ipInfo[ipInfo$technology=="w", ]$isp_id)  
fName <- paste(ipDataDir, ipInfoFName, ".info", sep="");
colNames <- colnames(ipInfo)
colNames <- colNames[order(colNames)]
write.table(ipInfo[colNames], fName, sep="\t", quote=F, col.names=colNames, row.names=FALSE)
