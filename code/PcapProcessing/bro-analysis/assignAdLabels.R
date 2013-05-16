baseDir<-"/user/arao/home/proj-work/meddle/"
scriptsDir<-"/home/arao/proj-work/meddle/arao-meddle/meddle/code/PcapProcessing/bro-analysis/gen-analysis-logs/"
setwd(scriptsDir);
#broLogsDir<-paste(baseDir, "bro-results/", sep="");
broLogsDir<-"/user/arao/home/proj-work/meddle/projects/app-identification/bro-results/"
source(paste(scriptsDir, "readLogFiles.R", sep=""))

assignAdLabels <- function(httpLogName, connLogName, namedAdFile) {
  httpData <- readHttpData(httpLogName)
  connData <- readConnData(connLogName)
  adTable <- read.table(namedAdFile, header=FALSE, sep="\"", fill=TRUE, 
                        col.names=c("zone", "domain", "misc1", "misc2", "misc3"),
                        stringsAsFactors=FALSE, quote="",comment.char = "/", )
  adRows <- unique(unlist(lapply(adTable$domain,  function(x) {print(x); grep(x, httpData$host)})))
  httpData$ad_flag = 0
  httpData[adRows,]$ad_flag=1
  # Dump the http logs
  fName <- paste(httpLogName, ".ads", sep="")
  print(fName)
  write.table(httpData, fName, sep="\t", quote=F, col.names=c(colnames(httpData)), row.names=FALSE)

  # Now find the rows in conn.log* and label them ads    
  httpAdConns = data.frame(uid=httpData$uid, ad_flag=httpData$ad_flag, stringsAsFactors=FALSE)
  rm(httpData) # To save memory 
  connData <- merge(x=connData, y=httpAdConns, by="uid", all.x=TRUE)
  connData$ad_flag <- convertStringColsToDouble(connData$ad_flag)
  fName <- paste(connLogName, ".ads", sep="")
  print(fName)
  write.table(connData, fName, sep="\t", quote=F, col.names=c(colnames(connData)), row.names=FALSE)
}

connLogName <- paste(broLogsDir, "conn.log.info.app", sep="")
httpLogName <- paste(broLogsDir, "http.log.info.app", sep="")
namedAdFile <- paste(scriptsDir, "named.conf.adblock", sep="")
assignAdLabels(httpLogName, connLogName, namedAdFile)
