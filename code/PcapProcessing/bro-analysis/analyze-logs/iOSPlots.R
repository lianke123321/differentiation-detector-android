baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
plotsDir=paste(baseDir, "plots/", sep="");
opar = par();
newpar = par(cex.lab=1.25, cex.axis=1.25, cex.main=1.25, cex.sub=1.25, cex=1.25, xaxs="i", yaxs="i",lwd=3);

convertStringColsToDouble <- function (stringCol) {
  stringCol <- as.double(stringCol)
  stringCol[is.na(stringCol)] <-0;
  stringCol;
}

getIOSConnTraffic <- function () {
  userDir <- broAggDir;
  fName <- paste(userDir, "/conn.log.ann", sep="");
  print("Read file")
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  connData$orig_ip_bytes = convertStringColsToDouble(connData$orig_ip_bytes);
  connData$resp_ip_bytes = convertStringColsToDouble(connData$resp_ip_bytes);
  connData$orig_pkts = convertStringColsToDouble(connData$orig_pkts);
  connData$resp_pkts = convertStringColsToDouble(connData$resp_pkts);   
  connData<-connData[connData$oper_sys == "iOS",]
  x<-connData
  x$resp_ip_bytes <- convertStringColsToDouble(x$resp_ip_bytes);
  x$orig_ip_bytes <- convertStringColsToDouble(x$orig_ip_bytes);
  tmpx <- x;
  tmpx$upanddown <- tmpx$orig_ip_bytes + tmpx$resp_ip_bytes
  userSum <- aggregate(tmpx[c("upanddown")], by=list(user_id=tmpx$user_id), FUN=sum)
  newTab <- NULL;
  # Filter users how have contributed less than 150 MB
  for (user_id in userSum$user_id) {
    userentries <- x[x$user_id ==user_id,];
    if (sum(userSum[userSum$user_id == user_id,]$upanddown) < (150*10^6)) {
      print(paste("Removing entries for",user_id));
      next;
    }
    newTab <- rbind(newTab, userentries)
  }
  x <- newTab;
  x;
}

getIOSDNSTraffic <- function () {
  userDir <- broAggDir;
  fName <- paste(userDir, "/dns.log.ann", sep="");
  print("Read file")
  dnsData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  dnsData<-dnsData[dnsData$oper_sys == "iOS",]
  dnsData
}

getAppleIPsFromDNS <- function(dnsData) {
  appleRows <- grep("apple", dnsData$query);
  appleRows <- append(appleRows, grep("apple", dnsData$answers))
  appleRows <- sort(unique(appleRows));
  appleEntries <- dnsData[appleRows,]
  appleIPs <- appleEntries$answers;
  appleIPList <- rep("", length(appleIPs)*20);
  j<-1
  i<-1
  for(entry in appleIPs) {
    ipList <- unlist(strsplit(entry, "\\,"))
    #print(ipList)
    for (ipEntry in ipList) {
      ipBitStream <- unlist(strsplit(ipEntry, "\\."))
      #print(ipEntry)
      ipValid <- TRUE;
      for (ipBit in ipBitStream) {
        if (is.na(as.numeric(ipBit))) {
            ipValid <- FALSE;
            break;
        }
      }
      if (ipValid) {
        appleIPList[j] <- ipEntry
        j<-j+1;
      }
    }
    if (i %% 10000 == 0) {
      print (i)
    }
    i<-i+1;
  }
  appleIPList <- appleIPList[1:j-1];
  appleIPList <- sort(unique(appleIPList))
  appleIPList
}

getAppleConnData <- function (appleIPList, connData) {
  i<-1
  connSrcs <- connData$id.orig_h
  connDst <- connData$id.resp_h
  rowIDList <- rep(-1, length(connDst));
  i<-1;
  j<-1
  for (dstIP in connDst) {
    if (dstIP %in% appleIPList) {
      rowIDList[j] <- i
      j<-j+1;
    } else {
      if (connSrcs[i] %in% appleIPList) {
        rowIDList[j]<-i;
        j<-j+1;
      }
    }
    i<-i+1;
    if ( i %% 10000 == 0) {
      print(i);
    }
  }
  rowIDList <- rowIDList[1:j-1]
  reqConnData <- connData[rowIDList, ];
  reqConnData;
}

getDiffLists <- function(userList, appleConnData) {
  pushConn <- appleConnData[(appleConnData$id.resp_p == 5223 | appleConnData$id.orig_p == 5223),];
  #pushConn <- appleConnData;
  uID<-1;
  metaDiffs <- NULL;
  for (userID in userList) {
    print(userID)
    prevIP <- ""
    userConns <- pushConn[pushConn$user_id == userID,]
    userConns <- userConns[order(userConns$ts),];
    tsDiffs <- rep(0, nrow(userConns));
    userTS <- as.numeric(userConns$ts);
    startID <- 1;
    stopID <- 1
    i<-1;
    for (entry in userConns$id.orig_h) {
      if (entry != prevIP) {
        prevIP <- entry;
        if ((stopID-startID)>5) {
          tmpDiffs <- diff (userTS[startID:stopID-1])
          #print(median(tmpDiffs));
          tsDiffs[i:(i+length(tmpDiffs)-1)] <- tmpDiffs
          i<-i+length(tmpDiffs)
          #print(length(tmpDiffs))
        }
        startID<-stopID;
      }
      stopID <- stopID+1;
    }
    tmpDiffs <- diff (userTS[startID:stopID-1])
    tsDiffs[i:(i+length(tmpDiffs)-1)] <- tmpDiffs
    i<-i+length(tmpDiffs)
    tsDiffs <- tsDiffs[1:i-1]
    metaDiffs[[uID]] <- tsDiffs
    uID<-uID +1;
    print(median(tsDiffs))
  }
  metaDiffs;
}

# getPushFlowRatio <- function(userList, appleConnData) {
#   pushConn <- appleConnData[(appleConnData$id.resp_p == 5223 | appleConnData$id.orig_p == 5223),];
#   httpConn <- appleConnData[appleConnData$proto == "tcp",]
#   fractList = matrix(0, nrow=length(userList), ncol=4)
#   #pushConn <- appleConnData;
#   i<-1
#   for (userID in userList) {
#     userPushConns <- pushConn[pushConn$user_id == userID,]
#     userConns <- userConns[order(userConns$ts),];
#     #userHttpConns <- httpConn[httpConn$user_id == userID,]
#     #fractList[i,] <- c(userID, nrow(userPushConns), nrow(userHttpConns),0)
#     #i<-i+1;
#   }
#  fractList;
# }

getNightPushTimes <- function(userList, appleConnData) {
  pushConn <- appleConnData[(appleConnData$id.resp_p == 5223 | appleConnData$id.orig_p == 5223),];
  nightPush <- matrix(nrow=length(userList), ncol=11);
  i<-1
  for (userID in userList) {
    userConns <- pushConn[pushConn$user_id == userID,]   
    userTS <- sort(as.numeric(userConns$ts));
    userDiffTS <- diff(userTS)
    if (length(userTS)<200) {
      next;
    }
    userConns <- userConns[(userConns$ts_date$hour>0 & userConns$ts_date$hour < 6),]
    userNightTS <- sort(as.numeric(userConns$ts));
    userDiffNightTS <- diff(userNightTS);
    nightPush[i,] <- c(userID, quantile(userDiffTS, c(0.1, 0.25, 0.5, 0.75, 0.9), names=FALSE),
                       quantile(userDiffNightTS, c(0.1, 0.25, 0.5, 0.75, 0.9), names=FALSE));
    print(nightPush[i,]);                
    i<-i+1;
    
  }
  nightPush <- nightPush[1:i-1,];
  
  plot(nightPush[, 4], ylim=c(0,1500));
  
  nightPush;
}

error.bar <- function(x,y,upper,lower)
{
  if ((length(x)!=length(y)) | (length(lower) != length(upper)) | (length(x)!= length(upper))) {
    stop("Vectors must have same length")
  }
  arrows(x,upper, x, lower, angle=90, code=3, length=0.1)
}

plotIOSPushForUsers <- function(appleConnData) {
  pushConn <- appleConnData[(appleConnData$id.resp_p == 5223 | appleConnData$id.orig_p == 5223),];
  
  hourMat <- matrix(nrow=24, ncol=4)
  i<-1
  for (userID in c("dave-ipad", "dave-iphone", "arvind-iphone", "will-ipad")) {
    userConns <- pushConn[pushConn$user_id == userID,];
    userConns <- userConns[order(as.numeric(userConns$ts)),];
    userConns <- userConns[userConns$ts_date$yday>320,]
    userConns$ts <- as.numeric(userConns$ts);
    userDiffTS <- diff(userConns$ts);
    par(newpar)
    diffsTable <- NULL;
    diffsTable$hour <- userConns[1:nrow(userConns)-1,]$ts_date$hour
    diffsTable$diffValue <- userDiffTS;
    
    tmpAggr<-NULL;
    aggrDiff <- aggregate(diffsTable[c("diffValue")], by=list(hour=diffsTable$hour), FUN=median)
  
    plot(diffsTable$hour, diffsTable$diffValue, ylim=c(0, 1800))
    
    #tmpAggr <- aggregate(diffsTable[c("diffValue")], by=list(hour=diffsTable$hour), FUN=quantile, probs=0.25)
    #aggrDiff$q25 <- tmpAggr$diffValue;
    #tmpAggr <- aggregate(diffsTable[c("diffValue")], by=list(hour=diffsTable$hour), FUN=quantile, probs=0.75)
    #aggrDiff$q75 <- tmpAggr$diffValue;
    
    tmpAggr <- aggregate(diffsTable[c("diffValue")], by=list(hour=diffsTable$hour), FUN=length)
    tmpAggr$diffValue <- tmpAggr$diffValue/sum(tmpAggr$diffValue);
    hourMat[, i] <- tmpAggr$diffValue
    #hourMat[,i] <- aggrDiff$diffValue;
    i<-i+1;
  }
  
  
  pdf(paste(plotsDir, "iosPushHourDistrib.pdf"))
  plot(0:23, hourMat[,1], pch="+", ylim=c(0, 0.08),
       xlab="Hour of the day", ylab="Fraction of push messages");  
  points(0:23, hourMat[,2], pch="o");
  #points(0:23, hourMat[,3], pch="*");
  points(0:23, hourMat[,4], pch="x")
  dev.off()
  
  
  
  
}

iosConnData <- getIOSConnTraffic();
iosDNSData <- getIOSDNSTraffic();
appleIPList <- getAppleIPsFromDNS(iosDNSData)
iosUsers <- unique(iosConnData$user_id)
appleConnData <- getAppleConnData(appleIPList, iosConnData)
userTsDiffs <- getDiffLists(iosUsers, iosConnData)
appleTimes<- as.POSIXlt(as.numeric(appleConnData$ts), tz="America/Los_Angeles", origin = "1970-01-01")
# TODO:: Not tested
#rowIDs <- grep("arnaud-iphone", appleConnData$user_id)
#appleTimes[rowIDs] <- as.POSIXlt(as.numeric(appleConnData[rowIDs,]$ts), tz="Europe/Paris", origin = "1970-01-01");
#appleTimes<- as.POSIXlt(as.numeric(appleConnData[,]$ts), tz="Europe/Paris", origin = "1970-01-01")
appleConnData$ts_date <- appleTimes;
fName <- paste(broAggDir, "/appleConn.txt", sep="");
write.table(appleConnData, fName, sep="\t", quote=F, col.names=c(colnames(appleConnData)), row.names=FALSE)
pushTimes<-getNightPushTimes(iosUsers, iosConnData)
userPushFlowFraction <- getPushFlowRatio(iosUsers, iosConnData)
for (i in 1:length(userTsDiffs)) {
  entry <- userTsDiffs[[i]]
  userPushFlowFraction[i,4]<-median(entry);
}
plotIOSPushForUsers(appleConnData)



