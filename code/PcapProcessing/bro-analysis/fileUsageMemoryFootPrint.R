# Objective is to see the number of flows per hour and per day for each file
# For each file get the max line length
# wc -L for max line length and wc -l is the number of lines and wc -c is character count

baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
setwd(scriptsDir);
#broLogsDir<-paste(baseDir, "bro-results/", sep="");
broLogsDir<-paste(baseDir, "/bro-aggregate-data/", sep="")
miscDataDir <- paste(baseDir, "/miscData/", sep="")
source(paste(scriptsDir, "readLogFiles.R", sep=""))

connData <- readConnData(paste(broLogsDir, 'conn.log.info',sep=""))
#userInfo <- read.table (paste(miscDataDir, "userInfo.txt", sep=""), header=T)


connData$tot_bytes <- as.numeric(connData$orig_ip_bytes) + as.numeric(connData$resp_ip_bytes);
connData$num_flows <- as.numeric(1)
# We now have the bytes from the user in each minute during which the test was conducted.
userConnHourAggr <- aggregate(connData[c("tot_bytes", "num_flows")],
                              by=list(user_id=connData$user_id, 
                                      year=connData$year, mon=connData$mon, 
                                      day=connData$day, hour=connData$hour),
                              FUN=sum)
userConnHourAggr <- userConnHourAggr[order(userConnHourAggr$num_flows, decreasing=TRUE),]
summary(userConnHourAggr$num_flows)
quantile(userConnHourAggr$num_flows,c(0.9, 0.95, 0.98, 0.99, 1))


httpData <- readHttpData(paste(broLogsDir, 'http.log.info',sep=""))
httpData$tot_bytes <- as.numeric(httpData$orig_ip_bytes) + as.numeric(httpData$resp_ip_bytes);
httpData$num_flows <- as.numeric(1)
# We now have the bytes from the user in each minute during which the test was conducted.
userHttpHourAggr <- aggregate(httpData[c("tot_bytes", "num_flows")],
                              by=list(user_id=httpData$user_id, 
                                      year=httpData$year, mon=httpData$mon, 
                                      day=httpData$day, hour=httpData$hour),
                              FUN=sum)
userHttpHourAggr <- userHttpHourAggr[order(userHttpHourAggr$num_flows, decreasing=TRUE),]
summary(userHttpHourAggr$num_flows)
quantile(userHttpHourAggr$num_flows,c(0.9, 0.95, 0.98, 0.99, 1))

sslData <- readSslData(paste(broLogsDir, 'ssl.log.info',sep=""))
sslData$tot_bytes <- as.numeric(sslData$orig_ip_bytes) + as.numeric(sslData$resp_ip_bytes);
sslData$num_flows <- as.numeric(1)
userSslHourAggr <- aggregate(sslData[c("tot_bytes", "num_flows")],
                              by=list(user_id=sslData$user_id, 
                                      year=sslData$year, mon=sslData$mon, 
                                      day=sslData$day, hour=sslData$hour),
                              FUN=sum)
userSslHourAggr <- userSslHourAggr[order(userSslHourAggr$num_flows, decreasing=TRUE),]
summary(userSslHourAggr$num_flows)
quantile(userSslHourAggr$num_flows,c(0.9, 0.95, 0.98, 0.99, 1))


