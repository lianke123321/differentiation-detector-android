baseDir<-"/home/arao/meddle_data/"
scriptsDir<-paste(baseDir, "parsing-scripts/", sep="")
miscDataDir<-paste(baseDir, "miscData/", sep="")
broLogsDir <- paste(baseDir, "bro-results/", sep="")
#baseDir<-"/user/arao/home/proj-work/meddle/arao-meddle/meddle/code/PcapProcessing/bro-analysis/gen-analysis-logs/"
#scriptsDir<-baseDir
#miscDataDir<-baseDir
setwd(scriptsDir)
library(bitops)

source(paste(scriptsDir, "readLogFiles.R", sep=""))

# Convert the IP address to an integer
getIPFromString <- function (ipString) {
  # Convert the ip from dotted form to integer
  ipBits <- unlist(strsplit(ipString, "\\.")) 
  if (length(ipBits) == 4 ) { 
     x <- bitOr(bitOr(bitShiftL(ipBits[1],24), bitShiftL(ipBits[2], 16)), bitOr(bitShiftL(ipBits[3], 8), bitShiftL(ipBits[4],0)))  
  } else {
    x <- 0
  }
  x
}

# Load the table that contains the user details
getUserInfo <- function () {
  fName <- paste(miscDataDir, "userInfo.txt", sep="")
  tmp<- read.table(fName, header=TRUE, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="")
  tmp$operating_system="a"
  tmp[(tmp$operating_system_name=="iOS"),]$operating_system="i"
  tmp
}

# Load the table that contains the details of the IP (as, isp_info, etc)
getAnnotatedClientIPInfo <- function() {
  fName <- paste(miscDataDir, "clientIPInfo.txt.info", sep="")  
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
  broData
}

# This is important because we might have missed some IP addresses
# Also some packets might have leaked into the tunnel due to some
# buggy rule implementation in the linux kernel.
generateDummyIPEntry <- function (clientIPInfo) {
  x <- clientIPInfo[1,]
  for (i in 1:ncol(x)) {
    x[1,i] = "-"
  }  
  x$time_zone = "America/Los_Angeles"
  x$isp_id= "-1"
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
  # We need only 4 columns: as_number, technology, country, isp_id, time_zone
  ipDetails <- matrix(ncol=6, nrow=nrow(broData))
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
        if (tmpTech$isp_info == "-") {
          tmpTech <- getIPDetails(dstIPCol[i], clientIPInfo, dummyIPEntry)
          if(tmpTech$isp_info == "-") {
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
    #print(tmpTech$isp_id)
    #print(c(tmpTech$technology, tmpTech$as, tmpTech$country, tmpTech$time_zone, tmpTech$isp_id))
    ipDetails[i,] <- c(tmpTech$technology, tmpTech$as, tmpTech$country, tmpTech$time_zone, tmpTech$isp_id, tmpTech$prefix_id)
    i<-i+1;
    if (i%%10000 == 0) {
      print(i);
    }
  }
  # HERE IS THE HARDCODING I DO NOT LIKE
  broData$technology <- ipDetails[,1]
  broData$as <- ipDetails[,2]  
  broData$country <- ipDetails[,3]  
  broData$time_zone <- ipDetails[,4]
  broData$isp_id <- ipDetails[,5]  
  broData$prefix_id <- ipDetails[, 6]
  #print(technology)
  broData
}
#fName = "http.log"
#broData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
#clientIPInfo <- getAnnotatedClientIPInfo();
#annData <- annotateIPInfoToBroLog(clientIPInfo, broData, broData$id.orig_h, broData$id.resp_h)  

annotateLocalTime <- function(broData) {
  # Convert the time stamps to date time
  # For each user group by the day, hour, on which at least one packet was seen

  # This takes too much time 
  #connData$ts_date <- mapply(x=as.numeric(connData$ts), y=connData$time_zone, function(x,y) {z<-as.POSIXlt(x, tz=y, origin = "1970-01-01"); z})
  broData$ts <- convertStringColsToDouble(broData$ts)
  unique_tz <- unique(broData$time_zone)
  broData$year <- 0; broData$mon <- 0; broData$day <- 0; broData$hour <- 0 ; broData$min <- 0 ; broData$sec <- 0
  i<-1
  for(i in 1:length(unique_tz)) {
    tz_rows <- grep(unique_tz[i], broData$time_zone)
    print("Converting")
    ts_date <- as.POSIXlt(broData[tz_rows, ]$ts, tz=unique_tz[i], origin = "1970-01-01");
    print(paste(unique_tz[i], length(tz_rows), broData[tz_rows[1],]$ts))
    broData[tz_rows, ]$hour <- ts_date$hour;#convertStringColsToDouble(broData[tz_rows,]$ts_date$hour)
    broData[tz_rows, ]$min  <- ts_date$min
    broData[tz_rows, ]$sec  <- as.integer(ts_date$sec)
    broData[tz_rows, ]$year <- ts_date$year
    broData[tz_rows, ]$mon  <- ts_date$mon+1; # R gives months from 0 to 11
    broData[tz_rows, ]$day  <- ts_date$mday
  }
  # remove the bulky timezone string
  broData$time_zone <- NULL;
  #print(broData[1,])
  broData
}

  
annotateBroLogsForUsers <- function(userDirList) {
  userInfoTable <- getUserInfo()
  clientIPInfo <- getAnnotatedClientIPInfo();
  for (userDir in userDirList) {
    userName <- basename(userDir)
    print (userName)
    # if (userName != "arao-droid") {
    #   next;
    # }
    userInfo <- userInfoTable[userInfoTable$user_name == userName, ];
    if (nrow(userInfo) != 1) {
      print (paste("Skipping user ", userName));
      next;
    }
#    for (logName in c("/conn.log", "/http.log", "/ssl.log", "/dns.log")) {      
    logName <- "/conn.log"
    fName <- paste(userDir, logName, sep="")
    print (paste("Reading", fName))
    if (file.exists(fName) == FALSE) {
      print(paste("File ", fName , "not found", sep=""));
      next;
    }
    connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
    print (paste("Done reading ", fName))
    if (nrow(connData) < 3) {
        print(fName);
        next;
    }
    print("Annotating IP Info")
    connData <- annotateIPInfoToBroLog(clientIPInfo, connData, connData$id.orig_h, connData$id.resp_h)
    print("Annotating User Info")
    connData <- annotateUserInfoToBroLog(userInfo, connData)
    print("Converting UTC to Local time of the Client")
    connData <- annotateLocalTime(connData)
    fName <- paste(fName, ".info", sep="")
    print(paste(fName, "now has the following columnns", str(colnames(connData))))
    write.table(connData, fName, sep="\t", quote=F, col.names=c(colnames(connData)), row.names=FALSE)
    # Now add the bytes exchaged in the http, and ssl logs
    print (paste("Done reading ", fName))
    # add the columns you have added to the other files 
    connUidInfo  <- data.frame(uid=connData$uid, 
                               orig_ip_bytes=connData$orig_ip_bytes, resp_ip_bytes=connData$resp_ip_bytes, 
                               hour=connData$hour, min=connData$min, sec=connData$sec, 
                               year=connData$year, mon=connData$mon, day=connData$day,
                               technology=connData$technology, as=connData$as, prefix_id=connData$prefix_id,
                               country=connData$country, isp_id=connData$isp_id,  
                               operating_system=connData$operating_system, 
                               device_type=connData$device_type, 
                               user_id=connData$user_id, stringsAsFactors=FALSE)
    for (logName in c("/http.log", "/ssl.log")) {
      fName <- paste(userDir, logName, sep="")
      print (paste("Reading", fName))
      if (file.exists(fName) == FALSE) {
        print(paste("File ", fName , "not found", sep=""));
        next;
      }
      broData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
      print (paste("Done reading ", fName))
      if (nrow(broData) < 3) {
        print(fName);
        next;
      }
      print("Annotating connInfo based on uid")
      broData <- merge(x=broData, y=connUidInfo, by="uid")
      fName <- paste(fName, ".info", sep="") 
      write.table(broData, fName, sep="\t", quote=F, col.names=c(colnames(broData)), row.names=FALSE)
    }
  }
  return(TRUE);
}

userLogDir <- list.dirs(broLogsDir, recursive=FALSE)
print(userLogDir)
annotateBroLogsForUsers(userLogDir)

