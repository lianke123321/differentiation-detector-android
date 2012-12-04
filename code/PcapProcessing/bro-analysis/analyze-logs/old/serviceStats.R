baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
plotsDir=paste(baseDir, "plots/", sep="");
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
opar = par();


# Signatures to learn the IP addresses
getSignatureConns <- function (servSignatures, httpData, sslData) {
  #rowIds <- NULL;
  #for (serversigns in servSignatures) {
  #  rowIds <- append(rowIds, grep (serversigns,dnsData$query));
  #}
  rowIds <- NULL;
  for (serversigns in servSignatures) {
    rowIds <- append(rowIds, grep (serversigns,sslData$server_name));
    rowIds <- append(rowIds, grep (serversigns,sslData$subject));
  }
  rowIds <- unique(rowIds)
#  serverIPs <- sslData[rowIds, "id.resp_h"]
  connIDs <- sslData[rowIds, "uid"];
  rowIds <- NULL;
  for (serversigns in servSignatures) {
    rowIds <- append(rowIds, grep (serversigns,httpData$host));  
  }
#  serverIPs <- append(serverIPs, httpData[rowIds, "id.resp_h"]);
  connIDs <- append(connIDs, httpData[rowIds, "uid"]);  
#  serverIPs <- unique(serverIPs);
  connIDs <- unique(connIDs)
}


getServiceFlows <- function (httpData, sslData, serviceSigsList) { 
  userConns <- NULL
  i<-1; 
  for (serviceSigs in serviceSigsList) {
    userConns[[i]] <- getSignatureConns(serviceSigs, httpData, sslData)  
    i <- i+1;
  } 
  userConns;
}


facebookSigs<- c("fbcdn", "facebook", "fbexternal")   
gtalkSigs <- c("mtalk.google")
twitterSigs <- c("^t.co$", "twitter", "tweet")
abirdSigs <- c("rovio")
serviceSigsList <- list(facebookSigs, gtalkSigs, twitterSigs, abirdSigs);
userConns <- getServiceFlows(httpData, sslData, serviceSigsList)

userDirList = list.dirs(broLogsDir, recursive=FALSE)
userDir <- userDirList[6]
fName <- paste(userDir, "/ssl.log", sep="");
sslData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
fName <- paste(userDir, "/http.log", sep="");
httpData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
fName <- paste(userDir, "/conn.log", sep="");
connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding

#fName <- paste(userDir, "/dns.log", sep="");
#dnsData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding


rowIDs <- NULL;
i<-1
for (connID in connData$uid) {
  #print(connID)
  if (connID %in% userConns) {
    rowIDs <- append(rowIDs, i);
  }
  i<-i+1;
}
entries <- connData[rowIDs, ];
entries$rowIDs <- rowIDs;
entries <- entries[order(entries$ts), ];
rowIDs <- entries$rowIDs;
connTsVals <- as.double(entries$ts);
connDurations <- as.double(entries$duration)
#connTimeVals <- as.POSIXlt(connTsVals, origin="1970-01-01", tz="America/Los_Angeles", usetz=TRUE)
#reqEntries <- connTimeVals[(connTimeVals$hour < 5) & (connTimeVals$hour > 2)]
#reqDurations <- connDurations[(connTimeVals$hour < 5) & (connTimeVals$hour > 2)]
## Make sessions based on overlapping connections
flowStartStops <- matrix(nrow=length(connTsVals), ncol=3)
flowStartStops[1,] <- c(rowIDs[1], connTsVals[1], connTsVals[1]+connDurations[1])
j<-1
for (i in 1:length(connTsVals)) {
  if (connTsVals[i] < flowStartStops[j,3]) {
    flowStartStops[j,3] <- max(flowStartStops[j,2], connTsVals[i]+connDurations[i]);
  } else {
    j<-j+1;
    flowStartStops[j,] <- c(rowIDs[i], connTsVals[i], connTsVals[i]+connDurations[i]);
  }
}
flowStartStops<- flowStartStops[1:j-1,]

