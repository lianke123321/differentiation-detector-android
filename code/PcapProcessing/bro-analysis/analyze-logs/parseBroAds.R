baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broLogsDir<-paste(baseDir, "bro-results/", sep="");
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
adBytesFile <- paste(broAggDir, "adBytes.txt", sep="");
plotsDir=paste(baseDir, "plots/", sep="");
adData <- read.table(paste(broAggDir, "adDomain.txt", sep=""), header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
opar = par();
# Default parameters for the plots
newpar <- par(cex.lab=1.25, cex.axis=1.25, cex.main=1.25, cex.sub=1.25,
    xaxs="i", yaxs="i",lwd=3);

isAdAnalyticsDomain <- function (currDomain, adData)  {    
  strVector<-unlist(strsplit(currDomain, '\\.')); 
  # We need to support subdomains. For example if admob.com is an ad domain
  # I assume that *.admob.com is also an ad domain. 
  retVal <- FALSE;
  for (i in 2:length(strVector)) {    
    #print (i);
    tmpVec <- paste(tail(strVector, i), sep=" ", collapse=".");    
    #print(tmpVec);
    if (TRUE == is.element(tmpVec, adData$domain)) {      
      retVal <- TRUE;      
      break
    }
  }
  retVal;
}

getAdData <- function(httpData, connData, adData) {
  nHttpRows <- nrow(httpData);
  adTable <- data.frame(matrix(nrow=nHttpRows, ncol=12), stringsAsFactors=FALSE, quote="");
  userHostList <- httpData$host
  nAdRow <- 1;
  i<-1
  for (userHost in userHostList) {  
    if ( i %% 500 == 1) {
      print(i)      
    }
    if(TRUE == isAdAnalyticsDomain(userHost, adData)) {
      entry <- httpData[i, ];
      connEntry <- connData[connData$uid == entry$uid,];      
      #cat(sprintf("%d %d %s %d %d\n", i, sum, connEntry$uid, connEntry$orig_ip_bytes, connEntry$resp_ip_bytes));
      # Take first entry of the connData as multiple may be found
      if (nrow(connEntry) >= 1) {
        # adTable <- rbind(adTable, list(entry$ts, entry$host,  entry$referrer, entry$user_agent, entry$mime_type, as.int64(connEntry$orig_ip_bytes[1]), as.int64(connEntry$resp_ip_bytes[1])));
        adTable[nAdRow, ] <- list(entry$ts, entry$uid, entry$user_id, entry$oper_sys, entry$technology, entry$isp_info, entry$host,  entry$referrer, entry$user_agent, entry$mime_type, as.double(connEntry$orig_ip_bytes[1]), as.double(connEntry$resp_ip_bytes[1]));
      } else {
        # Condition when the conn.log does not have the ip bytes, we use the http bytes 
        #adTable <-  rbind(adTable, list(entry$ts, entry$host,  entry$referrer, entry$user_agent, entry$mime_type, as.int64(entry$), as.int64(entry$)));    
        print("Conn Not Found")
        adTable[nAdRow, ] <- list(entry$ts, entry$uid, entry$user_id, entry$oper_sys, entry$technology, entry$isp_info, entry$host,  entry$referrer, entry$user_agent, entry$mime_type, as.double(entry$request_body_len), as.double(entry$response_body_len));
      }
      nAdRow <- nAdRow + 1;
    }
    i<-i+1;
  } 
  adTable <- adTable[1:nAdRow-1, ];
  totBytes <- sum(connData$orig_ip_bytes) + sum(connData$resp_ip_bytes);
  list(totBytes, adTable); 
}
#adData <- getAdData();
#totBytes <- sum(as.numeric(connData$resp_ip_bytes) + as.numeric(connData$resp_ip_bytes));

convertStringColsToDouble <- function (stringCol) {
  stringCol <- as.double(stringCol)
  stringCol[is.na(stringCol)] <-0;
  stringCol;
}

parseAdData <- function (adData, userDir) {  
  print(userDir)
  fName <- paste(userDir, "/http.log.ann", sep="");
  if (file.exists(fName) == FALSE) {
    print(fName);
    return(NA);
  }
  httpData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
  if (nrow(httpData) < 10) {
    print(fName);
    return(NA);
  }
  print("Read the httpData")
  fName <- paste(userDir, "/conn.log", sep="");
  if (file.exists(fName) == FALSE) {
    print(fName);
    return(NA);
  }
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  if (nrow(connData) < 10) {
    print(fName);
    return(NA);
  }
  #first make double
  connData$orig_ip_bytes = convertStringColsToDouble(connData$orig_ip_bytes);
  connData$resp_ip_bytes = convertStringColsToDouble(connData$resp_ip_bytes);
  connData$orig_pkts = convertStringColsToDouble(connData$orig_pkts);
  connData$resp_pkts = convertStringColsToDouble(connData$resp_pkts);
  print ("Read the connData");
  adMeta <- getAdData(httpData, connData, adData);    
  adMeta;
}

isolatedAdTraffic <- function(userLogsDir, tolerance) {
  fName <- paste(userLogsDir, "/conn.log", sep="");
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
  connData <- connData[order(connData$ts),];
  
  print("Read conn");
  fName <- paste(userLogsDir, "/adsTable.txt", sep="");
  adData <-read.table(fName, header=F, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="")
  print("Read ads");
  adData <- adData[order(adData$V1),];
  
  #ignore dns traffic
  connData <- connData[(connData$proto != "udp" & connData$service != "dns"), ];
  connData <- connData[(connData$proto != "udp" & as.numeric(connData$id.resp_p) != 53), ];
  connData$ts <- convertStringColsToDouble(connData$ts)
  connData$duration <- convertStringColsToDouble(connData$duration)
  connData$stops <- connData$ts + connData$duration  

  
  i<-1
  currStart <- connData[i,]$ts;
  currStop <- connData[i,]$stops + tolerance;
  stopVals <- connData$ts+connData$duration+tolerance;
  
  sst<-1;
  startStop <- matrix(nrow=nrow(connData), ncol=2)
  startStop[sst,] <- c(connData[i, ]$ts, stopVals[i])
  
  for (ts in connData$ts) {
    if (ts <= currStop) {
      if ((stopVals[i]) > currStop) {
        currStop <- stopVals[i];
        startStop[sst, 2] <- currStop; 
      }
    } else {
      sst <- sst+1;
      startStop[sst,] <- c(ts, stopVals[i])
    }
    i<-i+1;
  }
  startStop <- startStop[1:sst, ];

  j<-1;
  rowIDs <- NULL;
  for (i in 1:nrow(adData)) {
    entry <- adData[i,];
    while (entry$V1 > startStop[j,2]) {
      j <- j +1;
    }
    if (entry$V1 >  startStop[j,1]) {
      print(paste(entry$V1, startStop[j,1], startStop[j,2]))
      rowIDs <- append(rowIDs, j)
    }
  }
  #rowIDs are the rows where the ad traffic is between some other flow
  
  fracNotOrphan <- length(rowIDs)/nrow(adData);
  fracNotOrphan;
}

computeADTraffic <- function () {
  #userLogDirs <- list.dirs(broLogsDir, recursive=FALSE)
  for (userLogsDir in list.dirs(broLogsDir, recursive=FALSE)) { 
    print(userLogsDir);
    userName <- basename(userLogsDir)
    if ( (userName == "a8d88b9b98") ) {
      #if (userName != "parikshan-droid") {
      break;
    }
    userAdData <- parseAdData(adData, userLogsDir);  
    if (is.na(userAdData)) {
      print(userName)
      next;
    }
    print("Got AdData; Now Dumping the logs");  
    adTable <- data.frame(userAdData[2]);
    # TODO:: modify this entry when you modify the schema of the table.
    adBytes <- (sum(as.double(unlist(adTable$X11)))) + sum(as.double(unlist(adTable$X12))); 
    print("Dumping the Ad bytes")
    dataList <- list(userName, as.numeric(userAdData[1]), as.numeric(adBytes));
    adBytesFile <- paste(broLogsDir,"/userAdBytes.txt", sep="");
    print(unlist(dataList));
    print(adBytesFile)
    cat(unlist(dataList), file=adBytesFile, append=TRUE);
    cat("\n", file=adBytesFile, append=TRUE);  
    print("Dumping the ad Table for the user");
    userAdFile <- paste(userLogsDir, "/adsTable.txt", sep="");  
    tmpTable <- data.frame(unlist(adTable$X1), unlist(adTable$X2), unlist(adTable$X3), unlist(adTable$X4), unlist(adTable$X5), unlist(adTable$X6), unlist(adTable$X7),unlist(adTable$X9),unlist(adTable$X9),unlist(adTable$X10),unlist(adTable$X11),unlist(adTable$X12));
    write.table(tmpTable, userAdFile, sep="\t", col.names=FALSE, row.names=FALSE);  
  }                         
}

# pdf(file=paste(plotsDir,"userAdsShare.pdf", sep=""));
# userAds <- read.table(paste(broLogsDir,"userAdBytes.txt", sep=""));
# userAds <- userAds[userAds$V1 != "parikshan-droid",]
# userAds <- userAds[order(userAds$V2, decreasing=TRUE),]
# 
# yvals <- matrix(nrow=nrow(userAds), ncol=3);
# yvals[1:nrow(userAds),1] <- userAds$V3/userAds$V2;
# yvals[1:nrow(userAds),2] <- userAds$V3;
# yvals[1:nrow(userAds),3] <- userAds$V2;
# yvals[1:nrow(userAds),3] <- userAds$V1;
# yvals <- yvals[sort.list(yvals[,3],decreasing=TRUE),];
# 
# plot(yvals[,1]*100,
#      xlab="User",
#      ylim=c(0, max(yvals[,1]*1.5)*100),
#      ylab="Percentage of Ad Traffic (Volume of Ad Traffic )");
# #text(x=1:nrow(yvals), y=(yvals[,1]*100+6), 
# #     paste(round(100*yvals[,2]/(10^6))/100, " MB/", round(100*yvals[,3]/(10^6))/100, " MB", sep=""), 
# #     xpd=TRUE, srt=90)
# text(x=1:nrow(yvals), y=(yvals[,1]*100+6), 
#      paste(round(100*yvals[,2]/(10^6))/100, " MB/", round(100*yvals[,3]/(10^6))/100, " MB", sep=""), 
#      xpd=TRUE, srt=90)
# 
# dev.off()




getAdTrafficData <- function (userLogsDir) {
  userName <- basename(userLogsDir);
  print("Reading conn")
  fName <- paste(userLogsDir, "/conn.log.ann", sep="");
  print("Read Conn")
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
  #connData <- connData[order(connData$ts),];
  
  connData$orig_ip_bytes = convertStringColsToDouble(connData$orig_ip_bytes);
  connData$resp_ip_bytes = convertStringColsToDouble(connData$resp_ip_bytes);
  connData$orig_pkts = convertStringColsToDouble(connData$orig_pkts);
  connData$resp_pkts = convertStringColsToDouble(connData$resp_pkts);
  connData$totBytes = connData$orig_ip_bytes + connData$resp_ip_bytes;
  
  fName <- paste(userLogsDir, "/adsTable.txt", sep="");
  print ("Read ads")
  adData <- read.table(fName, header=F, sep="\t", fill=TRUE, stringsAsFactors=FALSE); # Note FILL causes silent padding
  adCumul <- read.table
  adData <- aggregate(adData[c("V3", "V5", "V11", "V12")],
                      by=list(V2=adData$V2),
                      FUN=max); # Take the median of the bytes (HACK)
  
  #aggrTechCumulBytes <- aggregate(connData[c("orig_ip_bytes", "resp_ip_bytes")], 
  #                            by=list(user_id=connData$user_id, technology=connData$technology),
  #                            FUN=sum);
  #aggrTechCumulBytes$totBytes <- aggrTechCumulBytes$orig_ip_bytes + aggrTechCumulBytes$resp_ip_bytes
  # we now have the total bytes per technology for the user
  
  aggrAdBytes <- aggregate(adData[c("V11", "V12")],
                           by=list(V3=adData$V3, V5=adData$V5),
                           FUN=sum);
  aggrAdBytes$totBytes <- as.numeric(aggrAdBytes$V11)+as.numeric(aggrAdBytes$V12)
  
  x<- c(userName, sum(connData$totBytes), 
        sum(connData[connData$technology=="Cellular",]$orig_ip_bytes),
        sum(connData[connData$technology=="Cellular",]$resp_ip_bytes),
        sum(connData[connData$technology=="Cellular",]$totBytes),
        sum(connData[connData$technology=="Wi-Fi",]$orig_ip_bytes),
        sum(connData[connData$technology=="Wi-Fi",]$resp_ip_bytes),
        sum(connData[connData$technology=="Wi-Fi",]$totBytes),
        sum(aggrAdBytes$totBytes),
        sum(aggrAdBytes[aggrAdBytes$V5=="Cellular",]$V11),
        sum(aggrAdBytes[aggrAdBytes$V5=="Cellular",]$V12),
        sum(aggrAdBytes[aggrAdBytes$V5=="Cellular",]$totBytes),
        sum(aggrAdBytes[aggrAdBytes$V5=="Wi-Fi",]$V11),
        sum(aggrAdBytes[aggrAdBytes$V5=="Wi-Fi",]$V12),
        sum(aggrAdBytes[aggrAdBytes$V5=="Wi-Fi",]$totBytes));
  x;
}

plotAdMatrix <- matrix(nrow=1000, ncol=15)
i<-1
for (userLogsDir in list.dirs(broLogsDir, recursive=FALSE)) {
  print(userLogsDir)
  plotAdMatrix[i,] <- getAdTrafficData(userLogsDir)
  i<-i+1;
}
plotAdMatrix<-plotAdMatrix[1:i-1,]
filtAdMatrix <- plotAdMatrix[as.numeric(plotAdMatrix[,2])>(100*10^6), ];
pdf(paste(plotsDir,"/ad"))
par(newpar)
plot(1:length(filtAdMatrix[,1]), 100*as.numeric(filtAdMatrix[,9])/as.numeric(filtAdMatrix[,2]),
     pch="+",
     ylim=c(0,4),
     xlim=c(0, length(filtAdMatrix[,1])+1),
     xlab="User (ordered by total traffic volume)",
     ylab="Percentage of ad traffic");
points(100*as.numeric(filtAdMatrix[,12])/as.numeric(filtAdMatrix[,5]), pch="v")
textVectors <- (as.numeric(filtAdMatrix[,12])/as.numeric(filtAdMatrix[,15]))/(as.numeric(filtAdMatrix[,5])/as.numeric(filtAdMatrix[,8]))
textVectors <- round(100*textVectors)/100;
textVectors[is.na(textVectors)] <- "N/A"
textVectors <- paste("(", textVectors,")", sep="")
text(x=1:length(filtAdMatrix[,1]), y=3.5,
     labels=textVectors, xpd=TRUE, srt=90)
grid(lwd=1)
legend(x=7, y=3, legend=c("Aggregate", "Cellular"), pch=c("+", "v"));
       





# WHEN ADS WERE BEING SENT OUT
# x<-read.table("/user/arao/home/windows/pcap-data-meddle/bro-results/1bb03d7910.adsTable")
# plot(as.POSIXlt(x$V1, origin="1970-01-01"), (as.numeric(x$V3)+as.numeric(x$V4))/(10^3))
# sum(as.numeric(x$V3))+sum(as.numeric(x$V4))

# TOP TALKERS OF ADS
# x<-read.table("/user/arao/home/windows/pcap-data-meddle/bro-results/1bb03d7910.adsTable")
# adSources <- aggregate(x[c("V3", "V4")], list(V2=x$V2), sum)
# adSources <- adSources[order(-(adSources$V3+adSources$V4)), ]
# adSources[1:10, ];

# EXPORT TO PDF 
# pdf(file="abc.pdf")
# ecdfInput <- (plainHTTP$request_body_len + plainHTTP$response_body_len)/10^3;
# plot.ecdf(ecdf(ecdfInput), 
#          main="Uncompressed HTTP data from each flow",
#          xlab="Amount of data (kB)", ylab="CDF",
#          xlim=range((plainHTTP$request_body_len + plainHTTP$response_body_len)/10^3));
# grid();
# dev.off();
# par() http://www.statmethods.net/advgraphs/parameters.html


