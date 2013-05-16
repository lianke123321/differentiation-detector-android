# The bro logs contain the ip from which the connection was made and the user details
# For each user, add the the user login name and the device type 
# based on the ip info annotate the technology, timezone and other information.
baseDir<-"/home/arao/meddle_data/"
scriptsDir<-paste(baseDir, "parsing-scripts/", sep="")
miscDataDir<-paste(baseDir, "miscData/", sep="")
broLogsDir <- paste(baseDir, "bro-results/", sep="")
#baseDir<-"/user/arao/home/proj-work/meddle/arao-meddle/meddle/code/PcapProcessing/bro-analysis/gen-analysis-logs/"
#scriptsDir<-baseDir
#ipDataDir<-baseDir
setwd(scriptsDir)
library(bitops)

# Convert the IP address to an integer
getIPFromString <- function (ipString) {
  # Convert the ip from dotted form to integer
  ipBits <- unlist(strsplit(ipString, "\\.")) 
  x <- bitOr(bitOr(bitShiftL(ipBits[1],24), bitShiftL(ipBits[2], 16)), bitOr(bitShiftL(ipBits[3], 8), bitShiftL(ipBits[4],0)))  
}

# Load the table that contains the user details
getUserInfo <- function () {
  fName <- paste(miscDataDir, "userInfo.txt", sep="")
  tmp<- read.table(fName, header=TRUE, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="")
  tmp
}

# Load the table that contains the details of the IP (as, isp_info, etc)
getAnnotatedClientIPInfo <- function() {
  fName <- paste(miscDataDir, "clientIPInfo.txt.ann", sep="")  
  tmp<- read.table(fName, header=TRUE, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="")
  tmp
}


# This function is called for each user separately, so the user 
# information can be safely annotated to the users bro logs. 
annotateUserInfoToBroLog<-function(userInfo, broData) {
  # annotate the bro logs with the user information
  nRows <- nrow(broData)
  broData$operating_system <- rep(userInfo$operating_system, nRows)
  broData$device_type <- rep(userInfo$device_type, nRows)
  broData$user_id <- rep(userInfo$user_id, nRows)
  broData;
}

# This is important because we might have missed some IP addresses
# Also some packets might have leaked into the tunnel due to some
# buggy rule implementation in the linux kernel.
generateDummyIPEntry <- function (clientIPInfo) {
  x <- clientIPInfo[1,]
  for (i in 1:ncol(x)) {
    x[1,i] = "UNKNOWN"
  }  
  x$time_zone = "America/Los_Angeles"
  x
}

# Get the details for the given IP address. 
# If the IP address is not present in the table then use the dummy 
# entry that has been provided.
getIPDetails <- function(strIP, clientIPInfo, dummyEntry) {
  entry <- clientIPInfo[bitAnd(clientIPInfo$ip_subnet, getIPFromString(strIP)) == clientIPInfo$ip_network, ];
  if (nrow(entry) > 0) {
    entry <- entry[1,]
  } else {
    entry <- dummyEntry
  }
  entry
}

# The columns are passed as argument because they may be different for different logs 
annotateIPInfoToBroLog<-function(clientIPInfo, broData, srcIPCol, dstIPCol) {
  nRows <- nrow(broData);
  dummyIPEntry <- generateDummyIPEntry(clientIPInfo)
  prevTech <- dummyIPEntry;
  # We need only 4 columns: as_number, technology, country, isp_info, time_zone
  ipDetails <- matrix(ncol=5, nrow=nrow(broData))
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
        tmpTech <- getIPDetails(entry, clientIPInfo, dummyIPEntry)
        #print(paste(entry, tmpTech))
        if (tmpTech$isp_info == "UNKNOWN") {
          tmpTech <- getIPDetails(dstIPCol[i], clientIPInfo, dummyIPEntry)
          if(tmpTech$isp_info == "UNKNOWN") {
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
    ipDetails[i,] <- c(tmpTech$technology, tmpTech$as, tmpTech$country, tmpTech$time_zone, tmpTech$isp_info)
    i<-i+1;
    if (i%%10000 == 0) {
      print(i);
    }
  }
  # HERE IS THE HARDCODING I DO NOT LIKE
  broData$technology <- ipDetails[,1]
  broData$as_number <- ipDetails[,2]  
  broData$country <- ipDetails[,3]  
  broData$time_zone <- ipDetails[,4]
  broData$isp_info <- ipDetails[,5]  
  #print(technology)
  broData
}
#setwd("/home/arao/proj-work/meddle/arao-meddle/meddle/code/PcapProcessing/bro-analysis/gen-analysis-logs")
#fName = "http.log.ann"
#broData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
#clientIPInfo <- getAnnotatedClientIPInfo();
#annData <- annotateIPInfoToBroLog(clientIPInfo, broData, broData$id.orig_h, broData$id.resp_h)  

annotateBroLogsForUsers <- function(userDirList) {
  userInfoTable <- getUserInfo()
  clientIPInfo <- getAnnotatedClientIPInfo();
  for (userDir in userDirList) {
    userName <- basename(userDir)
    print (userName)
#   if (userName != "arao-droid") {
#     next;
#   }
    userInfo <- userInfoTable[userInfoTable$userID == userName, ];
    if (nrow(userInfo) != 1) {
      print (paste("Skipping user ", userName));
      next;
    }
    for (logName in c("/conn.log", "/http.log", "/ssl.log", "/dns.log")) {
      fName <- paste(userDir, logName, sep="")
      print (fName)
      if (file.exists(fName) == FALSE) {
        print(paste("File ", fName , "not found", sep=""));
        next;
      }
      broData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
      if (nrow(broData) < 3) {
        print(fName);
        next;
      }
      broData <- (clientIPInfo, broData, broData$id.orig_h, broData$id.resp_h)
      broData <- annotateBroDataWithUserInfo(userInfo, broData)
    
      print(colnames(broData))
      fName <- paste(fName, ".info", sep="")
      print(fName)
      write.table(broData, fName, sep="\t", quote=F, col.names=c(colnames(broData)), row.names=FALSE)
    }
  }
  return(TRUE);
}
userLogDir <- list.dirs(broLogsDir, recursive=FALSE)
annotateForUsers(userLogDir)

