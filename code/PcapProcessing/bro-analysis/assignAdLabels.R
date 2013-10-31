baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
setwd(scriptsDir);
#broLogsDir<-paste(baseDir, "bro-results/", sep="");
broLogsDir<-paste(baseDir, "/bro-aggregate-data/", sep="")
miscDir <- paste(baseDir, "/miscData/", sep="")

source(paste(scriptsDir, "readLogFiles.R", sep=""))

assignAdLabels <- function(httpLogName, connLogName, namedAdFile) {
  print(httpLogName)
  httpData <- readHttpData(httpLogName)
  adTable <- read.table(namedAdFile, header=FALSE, sep="\"", fill=TRUE, 
                        col.names=c("zone", "domain", "misc1", "misc2", "misc3"),
                        stringsAsFactors=FALSE, quote="",comment.char = "/", )
  cnt<-1
  adRows <- unique(unlist(lapply(adTable$domain,  function(x) {print(paste(cnt, x)); cnt<-cnt+1; grep(x, httpData$host)})))
  httpData$ad_flag = 0
  httpData[adRows,]$ad_flag=1
  # Dump the http logs
  fName <- paste(httpLogName, ".ads", sep="")
  print(fName)
  write.table(httpData, fName, sep="\t", quote=F, col.names=c(colnames(httpData)), row.names=FALSE)
  # Now find the rows in conn.log* and label them ads    
  httpAdConns = data.frame(uid=httpData$uid, ad_flag=httpData$ad_flag, stringsAsFactors=FALSE)
  rm(httpData) # To save memory 
  print(connLogName)
  connData <- readConnData(connLogName)
  print("merging")
  connData <- merge(x=connData, y=httpAdConns, by="uid", all.x=TRUE)
  connData$ad_flag <- convertStringColsToDouble(connData$ad_flag)
  fName <- paste(connLogName, ".ads", sep="")
  print(fName)
  write.table(connData, fName, sep="\t", quote=F, col.names=c(colnames(connData)), row.names=FALSE)
}

connLogName <- paste(broLogsDir, "conn.log.info", sep="")
httpLogName <- paste(broLogsDir, "http.log.info", sep="")
namedAdFile <- paste(miscDir, "named.conf.adblock", sep="")
assignAdLabels(httpLogName, connLogName, namedAdFile)
