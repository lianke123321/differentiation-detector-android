baseDir<-"/user/arao/home/china_meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
setwd(scriptsDir);
#broLogsDir<-paste(baseDir, "bro-results/", sep="");
broLogsDir<-paste(baseDir, "/bro-aggregate-data/", sep="")

source(paste(scriptsDir, "readLogFiles.R", sep=""))

httpLogName <- paste(broLogsDir, "http.log.info", sep="")
httpData <- readHttpData(httpLogName)
httpData$tot_bytes <- httpData$orig_ip_bytes + httpData$resp_ip_bytes
sortData <- httpData[order(httpData$tot_bytes, decreasing=TRUE),]
sortData[1:30,c("ts", "orig_ip_bytes", "resp_ip_bytes", "uid")]

sslLogName <- paste(broLogsDir, "ssl.log.info", sep="")
sslData <- readSslData(sslLogName)
sslData$tot_bytes <- sslData$orig_ip_bytes + sslData$resp_ip_bytes
sortData <- sslData[order(sslData$tot_bytes, decreasing=TRUE),]
sortData[1:30,c("ts", "orig_ip_bytes", "resp_ip_bytes", "uid")]
