baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broLogsDir<-paste(baseDir, "bro-results/", sep="");
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
adBytesFile <- paste(broAggDir, "adBytes.txt", sep="");
adData <- read.table(paste(broAggDir, "adDomain.txt", sep=""), header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
opar = par();
# Default parameters for the plots
par(cex.lab=1.25, cex.axis=1.25, cex.main=1.25, cex.sub=1.25,
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
  adTable <- data.frame(matrix(nrow=nHttpRows, ncol=7), stringsAsFactors=FALSE, quote="");
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
        adTable[nAdRow, ] <- list(entry$ts, entry$host,  entry$referrer, entry$user_agent, entry$mime_type, as.double(connEntry$orig_ip_bytes[1]), as.double(connEntry$resp_ip_bytes[1]));
      } else {
        # Condition when the conn.log does not have the ip bytes, we use the http bytes 
        #adTable <-  rbind(adTable, list(entry$ts, entry$host,  entry$referrer, entry$user_agent, entry$mime_type, as.int64(entry$), as.int64(entry$)));    
        print("Conn Not Found")
        adTable[nAdRow, ] <- list(entry$ts, entry$host,  entry$referrer, entry$user_agent, entry$mime_type, as.double(entry$request_body_len), as.double(entry$response_body_len));
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

parseAdData <- function (adData, userDir) {  
  print(userDir)
  fName <- paste(userDir, "/http.log", sep="");
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
  connData$orig_ip_bytes = as.double(connData$orig_ip_bytes);
  connData$resp_ip_bytes = as.double(connData$resp_ip_bytes);
  connData$orig_pkts = as.double(connData$orig_pkts);
  connData$resp_pkts = as.double(connData$resp_pkts);
  # massage data if na or invalid entries are present -- this may be due to parsing errors
  connData$orig_ip_bytes[is.na(connData$orig_ip_bytes)] <-0;
  connData$resp_ip_bytes[is.na(connData$resp_ip_bytes)] <-0;
  connData$orig_pkts[is.na(connData$orig_pkts)] <-0;
  connData$resp_pkts[is.na(connData$resp_pkts)] <-0;
  print ("Read the connData");
  adMeta <- getAdData(httpData, connData, adData);    
}

userLogDirs <- list.dirs(broLogsDir, recursive=FALSE)
for (userLogsDir in list.dirs(broLogsDir, recursive=FALSE)) { 
  userName <- basename(userLogsDir)
  #if ( (userName != "will-droid") && (userName != "will-ipad")) {
  #if (userName != "parikshan-droid") {
  #  next;
  #}
  userAdData <- parseAdData(adData, userLogsDir);  
  if (is.na(userAdData)) {
    print(userName)
    next;
  }
  print("Got AdData; Now Dumping the logs");  
  adTable <- data.frame(userAdData[2]);
  adBytes <- (sum(as.double(unlist(adTable$X6)))) + sum(as.double(unlist(adTable$X7))); 
  print("Dumping the Ad bytes")
  dataList <- list(userName, as.numeric(userAdData[1]), as.numeric(adBytes));
  adBytesFile <- paste(broLogsDir,"/userAdBytes.txt", sep="");
  print(unlist(dataList));
  print(adBytesFile)
  cat(unlist(dataList), file=adBytesFile, append=TRUE);
  cat("\n", file=adBytesFile, append=TRUE);  
  print("Dumping the ad Table for the user");
  userAdFile <- paste(userLogsDir, "/adsTable.txt", sep="");  
  tmpTable <- data.frame(unlist(adTable$X1), unlist(adTable$X2), unlist(adTable$X3), unlist(adTable$X4), unlist(adTable$X5), unlist(adTable$X6), unlist(adTable$X7));
  write.table(tmpTable, userAdFile, col.names=FALSE, row.names=FALSE);  
}                         

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


