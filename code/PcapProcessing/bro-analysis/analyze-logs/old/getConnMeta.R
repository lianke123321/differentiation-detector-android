,# Script to classify L4 Traffic
# TCP <- HTTP, HTTPS, Other
# UDP <- DNS, Other
# ICMP 
# Other
#require(int64)


baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
  opar = par();

(baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
ipDataDir<-paste(baseDir, "ipData/", sep="");
opar = par();
library(bitops);

getIPFromString <- function (ipString) {
  ipBits <- unlist(strsplit(ipString, "\\.")); 
  x <- bitOr(bitOr(bitShiftL(ipBits[1],24), bitShiftL(ipBits[2], 16)), bitOr(bitShiftL(ipBits[3], 8), bitShiftL(ipBits[4],0)))  
}

getIPMaskFromSlash <- function(slash) {
  x <- bitFlip(0, bitWidth=32) - bitFlip(0, bitWidth=(32 - as.numeric(slash)));
}

getIPData <- function () {
  wifiStr="Wi-Fi"
  cellularStr ="Cellular"
  fName <- paste(ipDataDir, "globalASIPMeta.txt", sep="");
  # Make sure you remove the trailing white spaces and tabs else row.names=NULL error will be seen
  cellData <- read.table(fName, header=TRUE, sep="\t", fill=TRUE, 
                       stringsAsFactors=FALSE, quote="");
  technology <- rep(cellularStr, nrow(cellData))

  sigWifi <- c("university", "cable", "comcast", "renater", "sonic", "PROXAD", "at&t\ internet", "qwest")
  for (sig in sigWifi) {
    technology[grep(sig, cellData$isp_info, ignore.case=TRUE)] <- wifiStr
  }
  cellData$technology <- technology
  IPNetwork <- rep(0, nrow(cellData))
  IPMask <- rep(0, nrow(cellData))
  for (i in 1:nrow(cellData)) {
    entry <- cellData[i,]
    strPrefix <- entry$ip_prefix;
    strPrefix <- unlist(strsplit(strPrefix, "/"))
    IPNetwork[i] <- getIPFromString(strPrefix[1])
    IPMask[i] <- getIPMaskFromSlash(strPrefix[2])
  }
  cellData$ip_network <- IPNetwork;
  cellData$ip_subnet <- IPMask;
  cellData;
}

getTechnologyFromIP <- function(strIP, ipData) {
  entry <- ipData[bitAnd(ipData$ip_subnet, getIPFromString(strIP)) == ipData$ip_network, ];
  technology <- "Unknown"
  if (nrow(entry) > 0) {
    technology <- entry[1,]$technology
  } 
  #else {
  #  
  #}
  technology;
}


computeUserConnMeta <- function(connData, ipData) {
  x <- connData;
  print("Processing")
  # POST PROCESSING BASED ON PORT VALUES
  x[(x$proto=="tcp" & ( x$id.resp_p==443 | x$id.resp_p==5228 | x$id.resp_p== 8883)),]$service = "ssl"
  # 5228 gtalk android
  # 8882 mqtt ssl 
  x[(x$proto=="tcp" & x$id.resp_p==80),]$service = "http"
  technology <- rep(0, nrow(x))
  uc <- 1
  origIPLst <- x$id.orig_h
  respIPLst <- x$id.resp_h
  prevIP <- "";
  prevTech <- "Unknown";
  print("Getting the technology")
  i<-1
  for (entry in origIPLst) {
    if(entry == prevIP) {
      tmpTech <- prevTech
    } else{
      if(prevIP == respIPLst[i]) {
        tmpTech <- prevTech
      } else {
        tmpTech <- getTechnologyFromIP(entry, ipData)
        if (tmpTech == "Unknown") {
          #  print(paste("Try again", entry$id.orig_h, entry$id.resp_h));
          tmpTech <- getTechnologyFromIP(respIPLst[i], ipData)
          # print(paste("Got", tmpTech));
          if(tmpTech == "Unknown") {
            #print(c(entry, respIPLst[i]));
            unknownIPs[uc, ] <- c(entry, respIPLst[i])
            uc <- uc + 1;
            prevIP <- entry;
          } else {
            prevIP <- respIPLst[i]
          }
        } else {
          prevIP <- entry;
        }
        prevTech <- tmpTech
      }
    }
    technology[i] <- tmpTech;
    i<-i+1;
    if (i%%10000 == 0) {
      print(i);
    }
  }
#  for (i in 1:nrow(x)) {    
#     entry <- x[i,];
#     if ((entry$id.orig_h == prevIP) || (entry$id.resp_h == prevIP)) {
#       tmpTech <- prevTech
#     } else {
#       tmpTech <- getTechnologyFromIP(entry$id.orig_h, ipData)
#       if (tmpTech == "Unknown") {
#       #  print(paste("Try again", entry$id.orig_h, entry$id.resp_h));
#         tmpTech <- getTechnologyFromIP(entry$id.resp_h, ipData)
#       # print(paste("Got", tmpTech));
#         if(tmpTech == "Unknown") {
#           uc <- uc + 1;
#         }
#         prevIP <- entry$id.resp_h;
#       } else {
#         prevIP <- entry$id.orig_h
#       }
#       prevTech <- tmpTech
#     }
#     technology[i] <- tmpTech;
#     if (i%%100 == 0) {
#       print(i);
#     }
#   }
  x$technology <- technology
  print ("Now aggregating the results");
  y<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],by=list(proto=x$proto, service=x$service, technology=x$technology), FUN=sum)
  z<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],by=list(proto=x$proto, service=x$service, technology=x$technology), FUN=length)
  #return a table with proto, service, orig_pkts, resp_pkts, orig_ip_bytes, resp_ip_bytes, num_flows
  y$num_flows <- z$orig_pkts;
  print("Done")
  unknownIPs <<- unknownIPs[1:uc-1,]
  y;
}


getUserConnMeta <- function(userDir, cellData) {
  fName <- paste(userDir, "/conn.log", sep="");
  print("Reading file")
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  #first make double
  print("Done Reading");
  if (nrow(connData) < 2) {
    return (NA);
  }
  connData$orig_ip_bytes = as.double(connData$orig_ip_bytes);
  connData$resp_ip_bytes = as.double(connData$resp_ip_bytes);
  connData$orig_pkts = as.double(connData$orig_pkts);
  connData$resp_pkts = as.double(connData$resp_pkts);
  # massage data if na or invalid entries are present -- this may be due to parsing errors
  connData$orig_ip_bytes[is.na(connData$orig_ip_bytes)] <-0;
  connData$resp_ip_bytes[is.na(connData$resp_ip_bytes)] <-0;
  connData$orig_pkts[is.na(connData$orig_pkts)] <-0;
  connData$resp_pkts[is.na(connData$resp_pkts)] <-0;
  connMeta <- computeUserConnMeta(connData, ipData);
  print("Dumping the meta")
  fName=paste(userDir, "/connMeta.txt", sep="");
  print(fName);
  write.table(connMeta, fName, col.names=TRUE, row.names=FALSE)
}

ipData <- getIPData();
userDirList <- list.dirs(broLogsDir, recursive=FALSE)
for (userDir in userDirList) {
  unknownIPs <- matrix(nrow=10^6, ncol=2);
  userName<-basename(userDir)
  print(userDir)
  getUserConnMeta(userDir, ipData);
}


unknownIPs <- matrix(nrow=10^6, ncol=2);
userDir <- broAggDir;
getUserConnMeta(userDir, ipData);
tmpIPs <- unique(unknownIPs);

  
# write.table(connMeta, fName, col.names=TRUE, row.names=FALSE)
# baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
# scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/R/"
# setwd(scriptsDir);
# broLogsDir<-paste(baseDir, "bro-results/", sep="");
# 
# getUserConnMeta <- function(connData) {
#   x <- connData;
#   # POST PROCESSING BASED ON PORT VALUES
#   x[(x$proto=="tcp" & x$id.resp_p==443),]$service = "ssl"
#   x[(x$proto=="tcp" & x$id.resp_p==80),]$service = "http"
# 
#   y<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],by=list(proto=x$proto, service=x$service), FUN=sum)
#   z<-aggregate(x[c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes")],by=list(proto=x$proto, service=x$service), FUN=length)
#   #return a table with proto, service, orig_pkts, resp_pkts, orig_ip_bytes, resp_ip_bytes, num_flows
#   y$num_flows <- z$orig_pkts;
#   y;
# }
# 
# getConnMeta <- function(userDirList) {
#   masterTable <- NULL;
#   cnt <- 1
#   for (userDir in userDirList) {
#     userName <- basename(userDir)
#     #userDir <- paste(broLogsDir, userName, "/", sep="");
#     fName <- paste(userDir, "/conn.log", sep="");
#     print("Reading the connection Data");
#     connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); #, nrows=5);
#     connData$orig_ip_bytes = as.double(connData$orig_ip_bytes);
#     connData$resp_ip_bytes = as.double(connData$resp_ip_bytes);
#     connData$orig_pkts = as.double(connData$orig_pkts);
#     connData$resp_pkts = as.double(connData$resp_pkts);
#     print("Converted to numeric/double");
#     colTypes <- sapply(connData, class)
#     print(colTypes)
#     print("Summarizing the connection data");
#     userConnMeta <- getUserConnMeta(connData);
# 
#     if (cnt == 1) {
#       masterTable <- userConnMeta
#     } else {
#       print("Adding")
#       for (i in 1:nrow(userConnMeta)) {
#         entry <- userConnMeta[i,];
#         y <- masterTable[((masterTable$service==entry$service) & (masterTable$proto==entry$proto)),];
#         if  ( nrow(y) == 1 ) {
#           colIds <- c("orig_pkts", "resp_pkts", "orig_ip_bytes", "resp_ip_bytes", "num_flows");
#           masterTable[((masterTable$service==entry$service) & (masterTable$proto==entry$proto)), colIds] <- masterTable[((masterTable$service==entry$service) & (masterTable$proto==entry$proto)), colIds] + entry[, colIds];
#         } else {
#           print("Appending an entry");
#           print(entry);
#           masterTable[nrow(masterTable)+1, ]<- entry;
#         }
#       }
#     }
#     cnt <- cnt + 1;
#   }
#   masterTable;
# }
# 
# userDirList <- list.dirs(broLogsDir, recursive=FALSE)
# connMeta<-getConnMeta(userDirList);
# fName=paste(broLogsDir, "/connMeta.txt", sep="");
# write.table(connMeta, fName, col.names=TRUE, row.names=FALSE)
# pie((connMeta$orig_ip_bytes+connMeta$resp_ip_bytes), labels=paste(connMeta$proto, connMeta$service))
# pie((connMeta$orig_pkts+connMeta$resp_), labels=paste(connMeta$proto, connMeta$service))
