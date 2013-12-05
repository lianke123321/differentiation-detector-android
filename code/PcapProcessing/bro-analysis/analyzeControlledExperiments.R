baseDir<-"/user/arao/home/proj-work/meddle/projects/meddle_controlled_experiments/community_experiments/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/bro-results/", sep="");
cexVal<-1.5
resultsDir<-paste(baseDir,"/results/", sep="")
source(paste(scriptsDir, "/readLogFiles.R", sep=""))

amyData  <-  readHttpData(paste(broAggDir, '/amy/http.log.ads.app',sep=""))
test1Data <- readHttpData(paste(broAggDir, '/test1/http.log.ads.app',sep=""))
test2Data <- readHttpData(paste(broAggDir, '/test2/http.log.ads.app',sep=""))
test3Data <- readHttpData(paste(broAggDir, '/test3/http.log.ads.app',sep=""))
shenData  <-  readHttpData(paste(broAggDir, '/shen/http.log.ads.app',sep=""))
shenStartTime <- 1369710000
print(as.POSIXlt(shenStartTime, tz="America/Los_Angeles", origin = "1970-01-01"))
shenData <- shenData[shenData$ts > shenStartTime,]
unique(shenData$user_agent_signature)
unique(shenData$app_label)
######################################
##########ANAYLYSIS FOR IOS ##########
######################################

shenAppEnd <- aggregate(shenData[c("ts")],
                        by=list(app_label=shenData$app_label),
                        FUN=max)
shenAppEnd$end_ts <- as.POSIXlt(shenAppEnd$ts, tz="America/Los_Angeles", origin = "1970-01-01")
shenAppEnd$ts <- NULL
shenAppStart <- aggregate(shenData[c("ts")],
                          by=list(app_label=shenData$app_label),
                          FUN=min)
shenAppStart$start_ts <- as.POSIXlt(shenAppStart$ts, tz="America/Los_Angeles", origin = "1970-01-01")
shenAppTimes <- merge(shenAppStart, shenAppEnd, all.x=TRUE, all.y=TRUE)
shenAppTimes <- shenAppTimes[order(shenAppTimes$ts),]
write.table(shenAppTimes, paste(resultsDir, "/shen_appdetect_times.txt", sep=""), 
            sep="\t", quote=F, col.names=TRUE, row.names=FALSE)
shenHostStart <- aggregate(shenData[c("ts")],
                          by=list(host=shenData$host,
                                  app_label=shenData$app_label),
                          FUN=min)
shenHostStart$start_ts <- as.POSIXlt(shenHostStart$ts, tz="America/Los_Angeles", origin = "1970-01-01")
shenHostStart <- shenHostStart[order(shenHostStart$ts),]
write.table(shenHostStart, paste(resultsDir, "/shen_host_times.txt", sep=""), 
            sep="\t", quote=F, col.names=TRUE, row.names=FALSE)


# To get the tcpdump files with HTTP -- 
#for d in tcpdump* ; do echo ${d}; tshark -R "http" -r ${d}; | grep -c "GET"
#device id for shen: CD862A6E-ACA6-4B90-A662-4293A20E2263
1-(nrow(shenData[shenData$user_agent=="",])+nrow(shenData[shenData$user_agent=="-",]))/(nrow(shenData))


#shenData[grep("analytics", shenData$host), ]$analytics_label <- 
#  x <- unlist(lapply(shenData[grep("doubleclick", shenData$host), ]$referrer, function(x) 
#  {
#   y<- regexpr("app=.*?(\b|&|$)",x);   
#   if (y != -1) {
#     # #+3 for CN=
#     signature<-unlist(substring(x, y+3, y+attr(y, "match.length")-2))
#   } else {            
#     signature <- "-"
#   } 
#  })
                                                                   
  
                                                           

######################################
########## ANAYLYSIS ANDROID##########
######################################
manualTests <- rbind(test1Data, test2Data, test3Data)
amyStart <- 1365880000  #1365880595  
amyEnd   <- 1365886800  #1365886892
amyManual <- amyData[amyData$ts > amyStart, ]
amyManual <- amyManual[amyManual$ts < amyEnd, ]
manualTests <- rbind(amyManual, manualTests)
manualTests$num_flows <- 1
1-(nrow(manualTests[manualTests$user_agent=="",])+nrow(manualTests[manualTests$user_agent=="-",]))/(nrow(manualTests))
unique(manualTests$user_agent)
unique(manualTests$app_label)

manualAppEnd <- aggregate(manualTests[c("ts")],
                          by=list(app_label=manualTests$app_label,
                                  user_id=manualTests$user_id),
                          FUN=max)
manualAppEnd$end_ts <- as.POSIXlt(manualAppEnd$ts, tz="America/Los_Angeles", origin = "1970-01-01")
manualAppEnd$ts <- NULL;
manualAppStart <- aggregate(manualTests[c("ts")],
                          by=list(app_label=manualTests$app_label,
                                  user_id=manualTests$user_id),
                          FUN=min)
manualAppStart$start_ts <- as.POSIXlt(manualAppStart$ts, tz="America/Los_Angeles", origin = "1970-01-01")
manualAndroid <- merge(manualAppStart, manualAppEnd, all.x=TRUE, all.y=TRUE)
write.table(manualAndroid, paste(resultsDir, "/manualAndroid_appdetect_times.txt", sep=""), 
            sep="\t", quote=F, col.names=TRUE, row.names=FALSE)

manualHostStart <- aggregate(manualTests[c("ts")],
                           by=list(host=manualTests$host,
                                   app_label=manualTests$app_label),
                           FUN=min)
manualHostStart$start_ts <- as.POSIXlt(manualHostStart$ts, tz="America/Los_Angeles", origin = "1970-01-01")
manualHostStart <- manualHostStart[order(manualHostStart$ts),]
write.table(manualHostStart, paste(resultsDir, "/manualAndroid_host_times.txt", sep=""), 
            sep="\t", quote=F, col.names=TRUE, row.names=FALSE)
######################################
########## ANALYSIS AMY ##############
######################################
amyStart <- 1365880000  #1365880595  
amyEnd   <- 1365886800  #1365886892
amyAuto <- amyData[(amyData$ts >amyEnd) | (amyData$ts < amyStart), ]
as.POSIXlt(min(amyAuto$ts), tz="America/Los_Angeles", origin = "1970-01-01")
as.POSIXlt(max(amyAuto$ts), tz="America/Los_Angeles", origin = "1970-01-01")
as.POSIXlt(max(amyData$ts), tz="America/Los_Angeles", origin = "1970-01-01")

autoAppEnd <- aggregate(amyAuto[c("ts")],
                          by=list(app_label=amyAuto$app_label),
                          FUN=max)
autoAppEnd$end_ts <- as.POSIXlt(autoAppEnd$ts, tz="America/Los_Angeles", origin = "1970-01-01")
autoAppEnd$ts <- NULL;
autoAppStart <- aggregate(amyAuto[c("ts")],
                          by=list(app_label=amyAuto$app_label),
                          FUN=min)
autoAppStart$start_ts <- as.POSIXlt(autoAppStart$ts, tz="America/Los_Angeles", origin = "1970-01-01")
autoAppAndroid <- merge(autoAppStart, autoAppEnd, all.x=TRUE, all.y=TRUE)
autoAppAndroid <- autoAppAndroid[order(autoAppAndroid$ts),]
write.table(autoAppAndroid, paste(resultsDir, "/autoAppAndroid_appdetect_times.txt", sep=""), 
            sep="\t", quote=F, col.names=TRUE, row.names=FALSE)

amyAuto$num_flows <- 1
autoAggr <- aggregate(amyAuto[c("num_flows")],
                      by=list(app_label=amyAuto$app_label),
                      FUN=sum)
autoAggr <- autoAggr[order(autoAggr$num_flows, decreasing=TRUE),]
manualAggr <- aggregate(manualTests[c("num_flows")],
                           by=list(app_label=manualTests$app_label),
                           FUN=sum)
manualAggr <- manualAggr[order(manualAggr$num_flows, decreasing=TRUE),]




timeStampData <- read.table("/home/arao/proj-work/meddle/projects/meddle_controlled_experiments/community_experiments/timestamp/apktimestamps.txt.sed", 
                            header=T, sep="|", fill=TRUE, stringsAsFactors=FALSE, quote="");

timeStampData$ts <- y<-as.POSIXlt(strptime(timeStampData$ts_string, format="%a %b %d %H:%M:%S %Y", tz="America/Los_Angeles"))
#timeStampData <- timeStampData[order()
write.table(timeStampData, paste(resultsDir, "/autoAppAndroid_timestamps_fmt.txt", sep=""), 
            sep="\t", quote=F, col.names=TRUE, row.names=FALSE)
autoHostStart <- aggregate(amyAuto[c("ts")],
                             by=list(host=amyAuto$host,
                                     app_label=amyAuto$app_label,
                                     ad_flag=amyAuto$ad_flag),
                             FUN=min)
autoHostStart$start_ts <- as.POSIXlt(autoHostStart$ts, tz="America/Los_Angeles", origin = "1970-01-01")
autoHostStart <- autoHostStart[order(autoHostStart$ts),]
write.table(autoHostStart, paste(resultsDir, "/autoAndroid_host_times.txt", sep=""), 
            sep="\t", quote=F, col.names=TRUE, row.names=FALSE)

