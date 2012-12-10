baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
plotsDir=paste(baseDir, "plots/", sep="");
opar = par();
newpar = par(cex.lab=1.25, cex.axis=1.25, cex.main=1.25, cex.sub=1.25, cex=1.25, xaxs="i", yaxs="i",lwd=3);


# For same user "dave
# Facebook on droid, iphone, ipad

convertStringColsToDouble <- function (stringCol) {
  stringCol <- as.double(stringCol)
  stringCol[is.na(stringCol)] <-0;
  stringCol;
}


readConnData <- function(fName) {
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  connData$orig_ip_bytes = convertStringColsToDouble(connData$orig_ip_bytes);
  connData$resp_ip_bytes = convertStringColsToDouble(connData$resp_ip_bytes);
  connData$orig_pkts = convertStringColsToDouble(connData$orig_pkts);
  connData$resp_pkts = convertStringColsToDouble(connData$resp_pkts);    
  connData;
}

readHttpData <- function(fName) {
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  connData;
}

readSSLData <- function(fName) {
  connData <- read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote="");
  connData;
}


userDir <- paste(broLogsDir, "/dave-ipad", sep="");
fName <- paste(userDir, "/conn.log.ann", sep="");
ipadConnData <- readConnData(fName);
fName <- paste(userDir, "/http.log.ann", sep="");
ipadHttpData <- readHttpData(fName);
fName <- paste(userDir, "/ssl.log.ann", sep="");
ipadSSLData <- readSSLData(fName);

userDir <- paste(broLogsDir, "/dave-iphone", sep="");
fName <- paste(userDir, "/conn.log.ann", sep="");
iphoneConnData <- readConnData(fName);
fName <- paste(userDir, "/http.log.ann", sep="");
iphoneHttpData <- readHttpData(fName);
fName <- paste(userDir, "/ssl.log.ann", sep="");
iphoneSSLData <- readSSLData(fName);

userDir <- paste(broLogsDir, "/dave-droid", sep="");
fName <- paste(userDir, "/conn.log.ann", sep="");
droidConnData <- readConnData(fName);
fName <- paste(userDir, "/http.log.ann", sep="");
droidHttpData <- readHttpData(fName);
fName <- paste(userDir, "/ssl.log.ann", sep="");
droidSSLData <- readSSLData(fName);

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

facebookSigs<- c("fbcdn", "facebook", "fbexternal")
ipadConns <- getSignatureConns(facebookSigs, ipadHttpData, ipadSSLData);

iphoneConns <- getSignatureConns(facebookSigs, iphoneHttpData, iphoneSSLData);

droidConns <- getSignatureConns(facebookSigs, droidHttpData, droidSSLData);


