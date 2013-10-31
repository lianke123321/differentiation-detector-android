baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
setwd(scriptsDir);
broLogsDir<-paste(baseDir, "/bro-aggregate-data/", sep="")
miscDir <- paste(baseDir, "/miscData/", sep="")

source(paste(scriptsDir, "readLogFiles.R", sep=""))
source(paste(scriptsDir, "ipOperations.R", sep=""))

#http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.txt
locPorts <- c(7273, 7274, 7275, 7276, 7277, 9210, 9211)


getLocationFlows <- function(connName) {
  print(connName)
  connData <- readConnData(connName)
  connData <- connData[ (connData$proto=="tcp") & ((connData$id.orig_p %in% locPorts) | (connData$id.resp_p %in% locPorts)),]
  connIPs <- connData[(connData$id.resp_p %in%locPorts),]
  connIPs <- data.frame(ip_addr=connIPs$id.resp_h, port=connIPs$id.resp_p, user_id=connIPs$user_id, technology=connIPs$technology,
                        operating_system=connIPs$operating_system, stringsAsFactors=FALSE)
  # Dump the http logs
  fName <- paste(broLogsDir, "filter.location.conn.log.info", sep="")
  print(fName)
  write.table(connData, fName, sep="\t", quote=F, col.names=c(colnames(connData)), row.names=FALSE)

  fName <- paste(broLogsDir, "filter.location.ip.info", sep="")
  print(fName)
  write.table(connIPs, fName, sep="\t", quote=F, col.names=c(colnames(connIPs)), row.names=FALSE)

}

connName <- paste(broLogsDir, "conn.log.info", sep="")
getLocationFlows(connName)
