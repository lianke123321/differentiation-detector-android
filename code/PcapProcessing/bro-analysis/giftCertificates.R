baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
setwd(scriptsDir);
#broLogsDir<-paste(baseDir, "bro-results/", sep="");
broLogsDir<-paste(baseDir, "/bro-aggregate-data/", sep="")
miscDataDir <- paste(baseDir, "/miscData/", sep="")
source(paste(scriptsDir, "readLogFiles.R", sep=""))

connData <- readConnData(paste(broLogsDir, 'conn.log.info',sep=""))
userInfo <- read.table (paste(miscDataDir, "userInfo.txt", sep=""), header=T)


connData$tot_bytes <- connData$orig_ip_bytes + connData$resp_ip_bytes;
connData$num_flows <- 1
# We now have the bytes from the user in each minute during which the test was conducted.
userMinuteAggr <- aggregate(connData[c("tot_bytes", "num_flows")],
                            by=list(user_id=connData$user_id, 
                                    year=connData$year, mon=connData$mon, 
                                    day=connData$day, hour=connData$hour, 
                                    min=connData$min),
                            FUN=sum)
allMinuteAggr <- aggregate(connData[c("tot_bytes", "num_flows")],
                           by=list(year=connData$year, mon=connData$mon, 
                                   day=connData$day, hour=connData$hour, 
                                   min=connData$min),
                           FUN=sum)
userMinuteAggr$num_minutes <- 1;
allMinuteAggr$num_minutes <- 1;
# number of minutes per month the user was active per month. 
userMonAggr <- aggregate(userMinuteAggr[c("tot_bytes", "num_flows", "num_minutes")],
                         by=list(user_id=userMinuteAggr$user_id, 
                                 year=userMinuteAggr$year, mon=userMinuteAggr$mon),
                         FUN=sum)
allMonAggr <- aggregate(allMinuteAggr[c("tot_bytes", "num_flows", "num_minutes")],
                        by=list(year=allMinuteAggr$year, mon=allMinuteAggr$mon),
                        FUN=sum)
colnames(allMonAggr) <- gsub("tot_bytes", "all_tot_bytes", colnames(allMonAggr))
colnames(allMonAggr) <- gsub("num_flows", "all_num_flows", colnames(allMonAggr))
colnames(allMonAggr) <- gsub("num_minutes", "all_num_minutes", colnames(allMonAggr))
userMonAggr <- merge(userMonAggr, allMonAggr)
userMonAggr$frac_minutes <- userMonAggr$num_minutes/userMonAggr$all_num_minutes

userMonAggr <- merge(userMonInfo, userInfo)
userMonAggr <- userMonAggr[order(userMonAggr$year, userMonAggr$mon, userMonAggr$user_id),]

write.table(userMonAggr, paste(broLogsDir, 'certificates.txt',sep=""), 
            sep="\t", quote=F, col.names=c(colnames(userMonAggr)), row.names=FALSE)

                         
                         
                         
                         




                               