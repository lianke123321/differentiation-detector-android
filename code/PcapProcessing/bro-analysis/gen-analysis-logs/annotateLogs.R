baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/gen-analysis-logs/"
setwd(scriptsDir);
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
ipDataDir<-paste(baseDir, "ipData/", sep="");


gWifiStr="Wi-Fi"
gCellularStr ="Cellular"
gUnknownStr = "Unknown"

library(bitops)

getIPFromString <- function (ipString) {
  # Convert the ip from dotted form to integer
  ipBits <- unlist(strsplit(ipString, "\\.")); 
  x <- bitOr(bitOr(bitShiftL(ipBits[1],24), bitShiftL(ipBits[2], 16)), bitOr(bitShiftL(ipBits[3], 8), bitShiftL(ipBits[4],0)))  
}

getIPMaskFromSlash <- function(slash) {
  # Generate the bitmask from the / number , for example FF FF FF 00 -> /24 
  x <- bitFlip(0, bitWidth=32) - bitFlip(0, bitWidth=(32 - as.numeric(slash)));
}

getIPData <- function () {
  # Load the whois data and annotate the technology based on the service provider
  fName <- paste(ipDataDir, "globalASIPMeta.txt", sep="");
  # Make sure you remove the trailing white spaces and tabs else row.names=NULL error will be seen
  cellData <- read.table(fName, header=TRUE, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  technology <- rep(gCellularStr, nrow(cellData))
  
  # Hardcoded entries here!!!
  sigWifi <- c("university", "cable", "comcast", "renater", "sonic", "PROXAD", "at&t\ internet", "qwest")
  for (sig in sigWifi) {
    technology[grep(sig, cellData$isp_info, ignore.case=TRUE)] <- gWifiStr
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

globalIPHash <- NULL;
getIPDetails <- function(strIP, ipData) {
  # Given the string, check if the IP belongs to a given network 
  #technology <- globalIPHash[strIP]
  #if (is.na(technology)) {
  entry <- ipData[bitAnd(ipData$ip_subnet, getIPFromString(strIP)) == ipData$ip_network, ];
  technology <- gUnknownStr
  asID <- 0
  isp_info <- "-"
  if (nrow(entry) > 0) {
    technology <- entry[1,]$technology
    asID <- entry[1,]$as
    isp_info <- entry[1,]$isp_info
  }
  #  globalIPHash[strIP] <<- technology;
  #}
  #print(paste(strIP, technology));
  c(asID, technology, isp_info);
}

convertStringColsToDouble <- function (stringCol) {
  stringCol <- as.double(stringCol)
  stringCol <- stringCol[is.na(stringCol)] <-0;
}

getUserOSData <- function () {
  fName <- paste(ipDataDir, "userOSData.csv", sep="");
  tmp<- read.csv(fName);
  tmp;
}

annotateBroDataWithUserInfo<-function(userInfo, broData) {
  # annotate the bro logs with the user information
  nRows <- nrow(broData);  
  broData$oper_sys <- rep(userInfo$OS, nRows)
  broData$dev_type <- rep(userInfo$deviceType, nRows)
  broData$user_id <- rep(userInfo$userID, nRows)
  broData;
}

annotateBroDataWithAccessTechnology<-function(ipData, broData, srcIPCol, dstIPCol)
{
  nRows <- nrow(broData);
  prevTech <- getIPDetails("127.0.0.1", ipData);
  ipDetails <- matrix(ncol=length(prevTech), nrow=nrow(broData))
  for(i in 1:ncol(ipDetails)) { ipDetails[,i]<- prevTech[i]}
  prevIP <- "127.0.0.1";
  i<-1;
  for (entry in srcIPCol) {
    if(entry == prevIP) {
      tmpTech <- prevTech
    } else{
      if(prevIP == dstIPCol[i]) {
        tmpTech <- prevTech
      } else {
        # Get the technology and update the prev*
        tmpTech <- getIPDetails(entry, ipData)
        #print(paste(entry, tmpTech))
        if (tmpTech == "Unknown") {
          tmpTech <- getIPDetails(dstIPCol[i], ipData)
          if(tmpTech == "Unknown") {
#            unknownIPs[uc, ] <- c(entry, respIPLst[i])
#            uc <- uc + 1;
            prevIP <- entry;
          } else {
            prevIP <- dstIPCol[i]
          }
        } else {
          prevIP <- entry;
        }
        prevTech <- tmpTech
      }
    }
    # We found the technlogy for the entry
    #print(paste(i, tmpTech))
    ipDetails[i,] <- tmpTech;    
    i<-i+1;
    if (i%%10000 == 0) {
      print(i);
    }
  }
  broData$as <- ipDetails[,1]
  broData$technology <- ipDetails[,2]
  broData$isp_info <- ipDetails[,3]
  #print(technology)
  broData;
}

annotateForUsers <- function(userDirList) {
  userInfoTable <- getUserOSData();
  ipData <- getIPData();
  for (userDir in userDirList) {
    userName <- basename(userDir)
    print (userName)
    userInfo <- userInfoTable[userInfoTable$userID == userName, ];
    if (nrow(userInfo) != 1) {
      print (paste("Skipping user ", userName));
      next;
    }
    for (logName in c("/conn.log", "/http.log", "/ssl.log", "/dns.log")) {
      fName <- paste(userDir, logName, sep="")
      print (fName)
      if (file.exists(fName) == FALSE) {
        print(fName);
        next;
      }
      broData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
      if (nrow(broData) < 10) {
        print(fName);
        next;
      }
      broData <- annotateBroDataWithAccessTechnology(ipData, broData, broData$id.orig_h, broData$id.resp_h)
      broData <- annotateBroDataWithUserInfo(userInfo, broData)
      print(colnames(broData))
      fName <- paste(fName, ".ann", sep="")
      print(fName)
      write.table(broData, fName, sep="\t", quote=F, col.names=c(colnames(broData)), row.names=FALSE)
    }
  }
  return(TRUE);
}
userLogDir <- list.dirs(broLogsDir, recursive=FALSE)
annotateForUsers(userLogDir)





