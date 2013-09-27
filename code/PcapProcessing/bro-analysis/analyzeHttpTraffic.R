baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/bro-aggregate-data/", sep="");
miscDataDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "/paperData/", sep="");
cexVal<-1.6
source(paste(scriptsDir, "/readLogFiles.R", sep=""))


###########################################
### Compute Aggregates ####################
###########################################
removeHttpDuplicates <- function(inpHttp) {
  return(inpHttp[!duplicated(inpHttp$uid),])
}

httpData <- readHttpData(paste(broAggDir, 'http.log.info.app',sep=""))
httpData$tot_bytes <- convertStringColsToDouble(httpData$orig_ip_bytes) + convertStringColsToDouble(httpData$resp_ip_bytes)
httpData$num_flows <- 1
sortOrderTable <-readTable(paste(broAggDir, 'devices.sortorder.txt', sep=""))
numIOS <- nrow(sortOrderTable[sortOrderTable$operating_system=="i",])

httpSummary <- removeHttpDuplicates(httpData)
### There is an issue with the number of flows in conn.log and the flows in the http.log.
### Use the http.log to get the number of flows - and try to maximise the number of flows
### that can be categorized.
connHttpAggr <- aggregate(httpSummary[c("tot_bytes","num_flows")],
                          by=list(operating_system=httpSummary$operating_system),
                          FUN=sum)

###########################################
### Compute Word Clouds ###################
###########################################
x <- httpData[httpData$operating_system=="i", ]
x <- aggregate(x[c("tot_bytes")],
               by=list(user_agent_signature=x$user_agent_signature,
                       user_id=x$user_id),
               FUN=sum)      
x$tot_bytes <- 1
x <- aggregate(x[c("tot_bytes")],
               by=list(user_agent_signature=x$user_agent_signature),
               FUN=sum)      
#x <- c(x, httpData[httpData$operating_system=="i", ]$app_label)
#write(x, paste(resultsDir, "/wordcloud_useragentsignature_ios.txt", sep=""), sep="\n")
x <- x[order(x$tot_bytes, decreasing=TRUE),]
write.table(x, paste(resultsDir, "/wordcloud_useragentsignature_ios.txt", sep=""), 
            sep="\t", quote=F, col.names=FALSE, row.names=FALSE)


x <- httpData[httpData$operating_system=="a", ]
x <- aggregate(x[c("tot_bytes")],
               by=list(user_agent_signature=x$user_agent_signature,
                       user_id=x$user_id),
               FUN=sum)      
x$tot_bytes <- 1
x <- aggregate(x[c("tot_bytes")],
               by=list(user_agent_signature=x$user_agent_signature),
               FUN=sum)      
#x <- c(x, httpData[httpData$operating_system=="i", ]$app_label)
#write(x, paste(resultsDir, "/wordcloud_useragentsignature_ios.txt", sep=""), sep="\n")
x <- x[order(x$tot_bytes, decreasing=TRUE),]
write.table(x, paste(resultsDir, "/wordcloud_useragentsignature_android.txt", sep=""), 
            sep="\t", quote=F, col.names=FALSE, row.names=FALSE)

### 
# Old filtering when no aggregate was performed
#sed -i '/googleanalytics/d' wordcloud_useragentsignature_android.txt
#sed -i '/GoogleAnalytics/d' wordcloud_useragentsignature_android.txt
#sed -i 's/mail//g' wordcloud_useragentsignature_android.txt
#sed -i 's/Mail//g' wordcloud_useragentsignature_android.txt 
#sed -i 's/nemesis//g' wordcloud_useragentsignature_android.txt
#sed -i 's/mail //g' wordcloud_useragentsignature_android.txt

#sed -i 's/mail/mail darwin cfnetwork/g' wordcloud_useragentsignature_ios.txt
#http://user-agent-string.info/?Fuas=Mail%2F53+CFNetwork%2F548.1.4+Darwin%2F11.0.0%2C+Mozilla%2F5.0+%28iPad%3B+CPU+OS+5_1_1+like+Mac+OS+X%29+AppleWebKit.534.46+%28KHTML%2C+like+Gecko%29+Version%2F5.1+Mobile%2F9B206+Safari%2F7534.48.3&test=6351&action=analyze
#sed -i 's/Status/StatusBoard/g' wordcloud_useragentsignature_ios.txt
#######



###########################################
### Compute Classification Data for Table #
###########################################

computeHttpOSShare <- function(httpCondData) {
  httpCondData$num_flows<-1
  x <- aggregate(httpCondData[c("tot_bytes", "num_flows")],
                 by=list(operating_system=httpCondData$operating_system),
                 FUN=sum)                                                     
  colnames(x) <- gsub("tot_bytes", "tot_bytes_cond", colnames(x))
  colnames(x) <- gsub("num_flows", "num_flows_cond", colnames(x))
  tmp<-merge(x=x, y=connHttpAggr, all.y=TRUE)
  tmp[is.na(tmp)]<-0
  tmp$frac_http_bytes <- tmp$tot_bytes_cond/tmp$tot_bytes;
  tmp$frac_http_flows <- tmp$num_flows_cond/tmp$num_flows;
  colnames(tmp) <- gsub("tot_bytes", "tot_bytes_http", colnames(tmp))
  colnames(tmp) <- gsub("num_flows", "num_flows_http", colnames(tmp))  
  #tmp <- merge(x=tmp, y=sortOrderTable, by=c("user_id", "operating_system"))
  #tmp <- tmp[(order(tmp$sort_order)),]
  return(tmp)
}

assignServiceHosts <- function(httpCondData) {
  httpCondData[grep("xfinitytv",httpCondData$host),]$webservice <- "xfinitytv"
  httpCondData[grep("hbogo",httpCondData$host),]$webservice <- "hbo"  
  httpCondData[grep("hls.top.comcast", httpCondData$host),]$webservice <- "comcasttv"
  httpCondData[grep("graphics.*.nytimes", httpCondData$host),]$webservice <- "nytimes"
  httpCondData[grep("podcast", httpCondData$host),]$webservice <- "podcast"  
  httpCondData[grep("nbcvod", httpCondData$host),]$webservice <- "nbc"  
  httpCondData[grep("hls.*go", httpCondData$host),]$webservice <- "gotv"  
  httpCondData[grep("catfire*", httpCondData$host),]$webservice <- "castfire"  
  httpCondData[grep("stream.*gotv", httpCondData$host),]$webservice <- "gotv"  
  return(httpCondData)
}

assignCDNHosts <- function(httpCondData) {
  httpCondData[(httpCondData$app_label=="applecoremedia")&(httpCondData$webservice=="-"),]$webservice <- "cdn"
  httpCondData[(httpCondData$app_label=="stagefright")&(httpCondData$webservice=="-"),]$webservice <- "cdn"  
  return(httpCondData)
} 

httpClassData <- httpData;
httpClassData <- removeHttpDuplicates(httpClassData)
httpClassData <- assignServiceHosts(httpClassData)
httpWebServiceShare <- computeHttpOSShare(httpClassData[!(httpClassData$webservice=="-"),])
httpClassData <- assignCDNHosts(httpClassData)
httpAppData <- httpClassData[httpClassData$webservice=="-",]
#httpBrowserAggr <- computeHttpOSShare(httpAppData[(httpAppData$user_agent!="") & (httpAppData$user_agent_signature=="-"),])
httpAppAggr <-     computeHttpOSShare(httpAppData[(httpAppData$user_agent!=""),])
httpNoAppAggr <-   computeHttpOSShare(httpAppData[(httpAppData$user_agent==""),])


###########################################
### Compute Leaks in HTTP traffic #########
###########################################
httpData <- readHttpData(paste(broAggDir, 'http.log.info.ads.app',sep=""))
httpData <- removeHttpDuplicates(httpData)
httpData$tot_bytes <- convertStringColsToDouble(httpData$orig_ip_bytes) + convertStringColsToDouble(httpData$resp_ip_bytes)
httpData$num_flows <- 1
sortOrderTable <-readTable(paste(broAggDir, 'devices.sortorder.txt', sep=""))
numIOS <- nrow(sortOrderTable[sortOrderTable$operating_system=="i",])
                
# Location Flows
locationFlows <- httpData[grep("[^a-zA-Z]?lat([^a-zA-Z]|itude).*[0-9]+(\\.?)[0-9]+", httpData$uri,ignore.case=TRUE),]
locationFlows$detect="-"
locationFlows[(locationFlows$user_agent!="-")&(locationFlows$app_label=="-"),]$app_label<-"osbrowser"
locationFlows[grep("mozilla", locationFlows$user_agent, ignore.case=TRUE),]$detect<-"osbrowser"
locationFlows[grep("safari", locationFlows$user_agent, ignore.case=TRUE),]$detect<-"osbrowser"
locationFlows[(locationFlows$app_label=="osbrowser")&(locationFlows$detect!="osbrowser"),]$app_label<-"unknown"
locationFlows[(locationFlows$app_label=="-"),]$app_label<-"unknown"
locationFlows[(locationFlows$app_label=="unknown") & (locationFlows$host=="api.onebusaway.org"), ]$app_label<-"onebusaway"
locationFlows[(locationFlows$app_label=="unknown") & (locationFlows$host=="wxdata.weather.com"), ]$app_label<-"twc"
locationFlows[locationFlows$app_label=="twc"),]$app_label <- "twc"
#locationFlows[locationFlows$ad_flag==1,]$app_label<-paste(locationFlows[locationFlows$ad_flag==1,]$app_label,"-ads",sep="")
locationAggr <- aggregate(locationFlows[c("num_flows")],
                          by=list(app_label=locationFlows$app_label),
                          FUN=sum)
locationAggr[grep("fban", locationAggr$app_label),]$app_label <- "facebook"
locationAggr[grep("youtube", locationAggr$app_label),]$app_label <- "youtube"
locationAggr[grep("absolute", locationAggr$app_label),]$app_label <- "absoluteradio"                                  
#locationAggr[grep("twc", locationAggr$app_label),]$app_label <- "weatherchannel"
locationAggr$num_flows <- floor(log(locationAggr$num_flows,2)+1)
locationAggr <- locationAggr[order(locationAggr$num_flows, decreasing=TRUE),]
write.table(locationAggr, paste(resultsDir, "/wordcloud_useragentsignature_location.txt", sep=""), 
            sep="\t", quote=F, col.names=FALSE, row.names=FALSE)

unique(httpData[httpData$app_label=="onebusaway",]$user_id)
(424 + 2553 + 1000 + 118)/sum(locationAggr$num_flows)

springboardLoc <- locationFlows[locationFlows$app_label=="springboard",];
springboardLoc$num_flows <- 1
springboardAggr <- aggregate(springboardLoc[c("num_flows")],
                             by=list(user_id=springboardLoc$user_id,
                                     day=springboardLoc$day,
                                     year=springboardLoc$year,
                                     mon=springboardLoc$mon),
                             FUN=sum)
springboardAggrDevices <- aggregate(springboardAggr[c("num_flows")],
                                    by=list(user_id=springboardAggr$user_id),        
                                    FUN=max)
springboardAggrDevices <- springboardAggrDevices[order(springboardAggrDevices$num_flows, decreasing=TRUE),]
springboardAggrDevices$sort_order <- 1:nrow(springboardAggrDevices)

pdf(paste(resultsDir, "/piileaks_locclearspringboard.pdf", sep=""), height=8, width=16, pointsize=25)
mar <- par()$mar
mar[2] <- mar[2]+0.5
mar[3] <- 0.75
mar[4] <- 0.25
par(mar=mar)
plot(springboardAggrDevices$sort_order, springboardAggrDevices$num_flows,
     xlab="Device ID (ordered by number of leaks by Springboard)",
     ylab="Number of leaks per day",las=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlim=c(1, nrow(springboardAggrDevices)),
     ylim=c(0, max(springboardAggrDevices$num_flows)))
grid(lwd=3)
par(tcl=0.22)
axis(1, at=seq(1,nrow(springboardAggrDevices),1), labels=F)
axis(2, at=seq(1,max(springboardAggrDevices$num_flows),1), labels=F)
legend(5, 12, c("Max leaks"), pch=c(1), cex=cexVal)
dev.off()


     
     




# Search for imei numbers 
imeiGetFlows <- httpData[grep("([^a-zA-Z]?((IMEI)|(udid)|(uuid)|(user)|(-Id))[^a-zA-Z]?([:=])+(\"?)[0-9]{15,16}(\\b|[^0-9]))",httpData$uri, ignore.case=TRUE),]
imeiPostFlows <- httpData[grep("([^a-zA-Z]?((IMEI)|(udid)|(uuid)|(user)|(-Id))[^a-zA-Z]?([:=])+(\"?)[0-9]{15,16}(\\b|[^0-9]))",httpData$post_body, ignore.case=TRUE),]
imeiFlows <- rbind(imeiGetFlows, imeiPostFlows)
rm(imeiGetFlows)
rm(imeiPostFlows)
# 
imeiUserGet <- httpData[grep("(355031040945699)|(358217041235969)|(013331001603996)|(012544006057510)|(357194041324492)|(357194041329939)|(358699012073919)|(358699012073927)", httpData$uri),]
imeiUserPost <- httpData[grep("(355031040945699)|(358217041235969)|(013331001603996)|(012544006057510)|(357194041324492)|(357194041329939)|(358699012073919)|(358699012073927)", httpData$post_body),]
imeiUser <- rbind(imeiUserGet, imeiUserPost)
rm(imeiUserGet)
rm(imeiUserPost)
imeiAggr <- aggregate(imeiUser[c("num_flows")],
                      by=list(host=imeiUser$host, 
                              ad_flag=imeiUser$ad_flag,
                              app_label=imeiUser$app_label),
                      FUN=sum) 
imeiAggr <- imeiAggr[order(imeiAggr$num_flows, decreasing=TRUE),]
unique(imeiFlows$app_label)
unique(imeiFlows$user_agent)


deviceIdGet <- httpData[grep("(81663a0c12ccd363)|(2e48a517675953b8)|(2b9bde887ce35cfb)", httpData$uri),]
deviceIdPost<- httpData[grep("(81663a0c12ccd363)|(2e48a517675953b8)|(2b9bde887ce35cfb)", httpData$post_body),]
deviceIdFlow <- rbind(deviceIdGet, deviceIdPost)
deviceIdAggr <- aggregate(deviceIdFlow[c("num_flows")],
                      by=list(host=deviceIdFlow$host, 
                              ad_flag=deviceIdFlow$ad_flag,
                              app_label=deviceIdFlow$app_label),
                      FUN=sum)
userLeakGet <- httpData[grep("(ashwin)", httpData$uri),]
userLeakPost<- httpData[grep("(ashwin)", httpData$post_body),]
userLeakFlows <- rbind(userLeakGet, userLeakPost)
unique(userLeakFlows$app_label)
x<-userLeakFlows[userLeakFlows$app_label="mail"]

###########################################
### Compute QQ Flows for China #########
###########################################
qqData <- httpData
qqData <- qqData[grep("qq", qqData$user_agent, ignore.case=TRUE), ];

