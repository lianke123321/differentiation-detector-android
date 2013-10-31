baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
setwd(scriptsDir);
broLogsDir<-paste(baseDir, "/bro-aggregate-data/", sep="")
miscDir <- paste(baseDir, "/miscData/", sep="")

source(paste(scriptsDir, "readLogFiles.R", sep=""))
source(paste(scriptsDir, "ipOperations.R", sep=""))

maxRTT <- 180
getRttFlows <- function(connName) {
  print(connName)
  connData <- readConnData(connName)
  connData$e2e_rtt <-  connData$ack_time - connData$ts;
  connData$serv_latency <- connData$ack_time - connData$synack_time;
  connData <- connData[ (connData$proto=="tcp")
                       & (connData$ack_time >0)
                       & (connData$synack_time>0) 
                       & (connData$e2e_rtt < maxRTT)
                       & (connData$serv_latency < maxRTT)            
                       & ((connData$conn_state=="SF")),]
#| (connData$conn_state=="S1") 
#                           | (connData$conn_state=="S2") | (connData$conn_state=="S3")
#                           | (connData$conn_state=="RSTO") | (connData$conn_state=="RSTR")), ]
  # Dump the http logs
  fName <- paste(broLogsDir, "filter.rtt.conn.log.info", sep="")
  print(fName)
  write.table(connData, fName, sep="\t", quote=F, col.names=c(colnames(connData)), row.names=FALSE)
}

connName <- paste(broLogsDir, "conn.log.info", sep="")
getRttFlows(connName)
