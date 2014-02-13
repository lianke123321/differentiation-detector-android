baseDir<-"/user/arao/home/controlled_experiments/community_experiments/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
broLogsDir<-paste(baseDir, "/bro-results/droid-10-min-amy/", sep="")
miscDir<-paste(baseDir, "/miscData/", sep="")

source(paste(scriptsDir, "readLogFiles.R", sep=""))
fName <- paste(broLogsDir, "http.log", sep="");
httpData <- readHttpData(fName)
fName <- paste(broLogsDir, "conn.log", sep="");
connData <- readConnData(fName)
fName <- paste(broLogsDir, "ssl.log", sep="");
sslData <- readSslData(fName)
fName <- paste(broLogsDir, "dns.log", sep="");
dnsData <- readSslData(fName)

apkMetaData <- paste(miscDir, "apkMetaData.txt", sep="");
#timestampHeaders <- c("apkName", "pkgName", "tStart", "tStartHuman", "tStop", "tStopHuman")
apkMetaData <- read.table(apkMetaData, header=T, sep="|", fill=FALSE, stringsAsFactors=FALSE,
                            quote="", row.names=NULL)
apkMetaData$tStart <- as.numeric(apkMetaData$tStart)
apkMetaData$tStop <- as.numeric(c(apkMetaData[2:nrow(apkMetaData),]$tStart, 1386240125))
apkMetaData <- apkMetaData[order(apkMetaData$tStart, decreasing=FALSE), ]


addColumns <- function(inpData) {
  inpData$pkgName <- "-"
  inpData$pkgID <- 0
  return(inpData)
}

labelMalware<-function(inpData, i) {
  reqRows <- which((inpData$ts>= apkMetaData[i,]$tStart) & (inpData$ts <= apkMetaData[i,]$tStop))
  if (length(reqRows) > 0) {
#   print(i)
    inpData[reqRows,]$pkgID <- i;
    inpData[reqRows,]$pkgName <- apkMetaData[i,]$pkgName
  }  
  return(inpData)
}

httpData <- addColumns(httpData)
connData <- addColumns(connData)
sslData <- addColumns(sslData)
dnsData <- addColumns(dnsData)

colnames(apkMetaData)
for (i in 1:nrow(apkMetaData)) {
#for (i in 1:10) {
  print(paste(i, apkMetaData[i,]$tStart, apkMetaData[i, ]$tStop))
  sslData <- labelMalware(sslData, i)
  connData <- labelMalware(connData,i)
  httpData <- labelMalware(httpData, i)
  dnsData <- labelMalware(dnsData,i)
}

httpData<-httpData[httpData$pkgID >0, ]
sslData<-sslData[sslData$pkgID >0, ]
connData<-connData[connData$pkgID >0, ]
dnsData<-dnsData[dnsData$pkgID >0, ]


write.table(httpData, paste(broLogsDir, "http.log.pkg", sep=""), sep="\t", 
            quote=F, col.names=c(colnames(httpData)), row.names=FALSE, fileEncoding="utf-8")
write.table(sslData, paste(broLogsDir, "ssl.log.pkg", sep=""), sep="\t", 
            quote=F, col.names=c(colnames(sslData)), row.names=FALSE, fileEncoding="utf-8")
write.table(connData, paste(broLogsDir, "conn.log.pkg", sep=""), sep="\t", 
            quote=F, col.names=c(colnames(connData)), row.names=FALSE, fileEncoding="utf-8")
write.table(dnsData, paste(broLogsDir, "dns.log.pkg", sep=""), sep="\t", 
            quote=F, col.names=c(colnames(dnsData)), row.names=FALSE, fileEncoding="utf-8")
