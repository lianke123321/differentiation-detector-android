baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
setwd(scriptsDir);
#broLogsDir<-paste(baseDir, "bro-results/", sep="");
broLogsDir<-paste(baseDir, "/bro-aggregate-data/", sep="")
miscDir <- paste(baseDir, "/miscData/", sep="")

source(paste(scriptsDir, "readLogFiles.R", sep=""))

getAdsWithAppDetails <- function(httpLogName) {
  print(httpLogName)
  httpData <- readHttpData(httpLogName)
  httpData <- httpData[httpData$ad_flag==1, ]
  # Dump the http logs
  fName <- paste(broLogsDir, "filter.ads.http.log.info.ads.app", sep="")
  print(fName)
  write.table(httpData, fName, sep="\t", quote=F, col.names=c(colnames(httpData)), row.names=FALSE)
}

httpLogName <- paste(broLogsDir, "http.log.info.ads.app", sep="")
getAdsWithAppDetails(httpLogName)
