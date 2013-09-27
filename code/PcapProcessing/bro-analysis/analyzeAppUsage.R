baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/bro-aggregate-data/", sep="");
miscDataDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "/paperData/", sep="");
cexVal<-1.5
source(paste(scriptsDir, "/readLogFiles.R", sep=""))


###################################################################################
###################################################################################
############## COMPUTE ALL THE AGGREGATES #########################################
###################################################################################

removeHttpDuplicates <- function(inpHttp) {
  return(inpHttp[!duplicated(inpHttp$uid),])
}

httpData <- readHttpData(paste(broAggDir, 'http.log.info.ads.app',sep=""))
httpData$tot_bytes <- convertStringColsToDouble(httpData$orig_ip_bytes) + convertStringColsToDouble(httpData$resp_ip_bytes)
httpData$num_flows <- 1
sortOrderTable <-readTable(paste(broAggDir, 'devices.sortorder.txt', sep=""))
numIOS <- nrow(sortOrderTable[sortOrderTable$operating_system=="i",])

httpSummary <- removeHttpDuplicates(httpData)
### There is an issue with the number of flows in conn.log and the flows in the http.log.
### Use the http.log to get the number of flows - and try to maximise the number of flows
### that can be categorized.
connHttpAggr <- aggregate(httpSummary[c("tot_bytes","num_flows")],
                          by=list(user_id=httpSummary$user_id, 
                                  operating_system=httpSummary$operating_system),
                          FUN=sum)

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


#sed -i '/googleanalytics/d' wordcloud_useragentsignature_android.txt
#sed -i '/GoogleAnalytics/d' wordcloud_useragentsignature_android.txt
#sed -i 's/mail//g' wordcloud_useragentsignature_android.txt
#sed -i 's/Mail//g' wordcloud_useragentsignature_android.txt 
#sed -i 's/nemesis//g' wordcloud_useragentsignature_android.txt
#sed -i 's/mail //g' wordcloud_useragentsignature_android.txt

#sed -i 's/mail/mail darwin cfnetwork/g' wordcloud_useragentsignature_ios.txt
#http://user-agent-string.info/?Fuas=Mail%2F53+CFNetwork%2F548.1.4+Darwin%2F11.0.0%2C+Mozilla%2F5.0+%28iPad%3B+CPU+OS+5_1_1+like+Mac+OS+X%29+AppleWebKit.534.46+%28KHTML%2C+like+Gecko%29+Version%2F5.1+Mobile%2F9B206+Safari%2F7534.48.3&test=6351&action=analyze
#sed -i 's/Status/StatusBoard/g' wordcloud_useragentsignature_ios.txt

###################################################################################
###################################################################################
#### Define the functions that use these aggregates along with other filtered data
###################################################################################
###################################################################################
computeHttpHostAggr <- function (httpCondData) {
  aggrData <- aggregate(httpCondData[c("tot_bytes", "num_flows")],
                             by=list(host=httpCondData$host),
                             FUN=sum)
  tmpAggrData <- aggregate(httpCondData[c("num_flows")],
                           by=list(host=httpCondData$host,
                                   user_id=httpCondData$user_id),
                           FUN=sum)
  colnames(tmpAggrData) <- gsub("num_flows", "num_users", colnames(tmpAggrData))
  tmpAggrData$num_users<-1
  tmpAggrData <- aggregate(tmpAggrData[c("num_users")],
                           by=list(host=tmpAggrData$host),
                           FUN=sum)
  aggrData <- merge(x=aggrData, y=tmpAggrData, all.x=TRUE);
  tmpAggrData <- httpCondData[httpCondData$operating_system=="a",]
  tmpAggrData <- aggregate(tmpAggrData[c("num_flows")],
                           by=list(host=tmpAggrData$host,
                                   user_id=tmpAggrData$user_id),
                           FUN=sum)
  colnames(tmpAggrData) <- gsub("num_flows", "num_android_users", colnames(tmpAggrData))
  tmpAggrData$num_android_users<-1
  tmpAggrData <- aggregate(tmpAggrData[c("num_android_users")],
                           by=list(host=tmpAggrData$host),
                           FUN=sum)
  aggrData <- merge(x=aggrData, y=tmpAggrData, all.x=TRUE);
  aggrData[is.na(aggrData)] <- 0
  return(aggrData)
}

computeHttpAppAggr <- function (httpCondData) {
  aggrData <- aggregate(httpCondData[c("tot_bytes", "num_flows")],
                        by=list(app_label=httpCondData$app_label),
                        FUN=sum)
  tmpAggrData <- aggregate(httpCondData[c("num_flows")],
                           by=list(app_label=httpCondData$app_label,
                                   user_id=httpCondData$user_id),
                           FUN=sum)
  colnames(tmpAggrData) <- gsub("num_flows", "num_users", colnames(tmpAggrData))
  tmpAggrData$num_users<-1
  tmpAggrData <- aggregate(tmpAggrData[c("num_users")],
                           by=list(app_label=tmpAggrData$app_label),
                           FUN=sum)
  aggrData <- merge(x=aggrData, y=tmpAggrData, all.x=TRUE);
  tmpAggrData <- httpCondData[httpCondData$operating_system=="a",]
  tmpAggrData <- aggregate(tmpAggrData[c("num_flows")],
                           by=list(app_label=tmpAggrData$app_label,
                                   user_id=tmpAggrData$user_id),
                           FUN=sum)
  colnames(tmpAggrData) <- gsub("num_flows", "num_android_users", colnames(tmpAggrData))
  tmpAggrData$num_android_users<-1
  tmpAggrData <- aggregate(tmpAggrData[c("num_android_users")],
                           by=list(app_label=tmpAggrData$app_label),
                           FUN=sum)
  aggrData <- merge(x=aggrData, y=tmpAggrData, all.x=TRUE);
  aggrData[is.na(aggrData)] <- 0
  return(aggrData)
}

computeHttpCondTrafficShare <- function(httpCondData) {
  httpCondData$num_flows<-1
  x <- aggregate(httpCondData[c("tot_bytes", "num_flows")],
                 by=list(user_id=httpCondData$user_id, 
                        operating_system=httpCondData$operating_system),
                 FUN=sum)                                                     
  colnames(x) <- gsub("tot_bytes", "tot_bytes_cond", colnames(x))
  colnames(x) <- gsub("num_flows", "num_flows_cond", colnames(x))
  tmp<-merge(x=x, y=connHttpAggr, all.y=TRUE)
  tmp[is.na(tmp)]<-0
  tmp$frac_http_bytes <- tmp$tot_bytes_cond/tmp$tot_bytes;
  tmp$frac_http_flows <- tmp$num_flows_cond/tmp$num_flows;
  colnames(tmp) <- gsub("tot_bytes", "tot_bytes_http", colnames(tmp))
  colnames(tmp) <- gsub("num_flows", "num_flows_http", colnames(tmp))  
  #tmp<-merge(x=tmp, y=connTcpAggr, all.y=TRUE)
  #tmp$frac_tcp_bytes <- tmp$tot_bytes_cond/tmp$tot_bytes;
  #tmp$frac_tcp_flows <- tmp$num_flows_cond/tmp$num_flows;
  tmp <- merge(x=tmp, y=sortOrderTable, by=c("user_id", "operating_system"))
  tmp <- tmp[(order(tmp$sort_order)),]
  return(tmp)
}

clusterAppsAndServices <- function(app_label) {  
  app_label <- gsub("*fban.*", "facebook", app_label)
  ## Group VK
  app_label <- gsub(".*vkandroid.*", "vk", app_label)
  ## Group ebay
  app_label <- gsub(".*ebay.*", "ebay", app_label)
  ## group for twitter
  app_label <- gsub(".*twitter.*", "twitter", app_label) 
  return(app_label)
}
###################################################################################
###################################################################################
############## Look at flows with Empty User Agents ###############################
###################################################################################
# How much HTTP traffic did the user generate?

# How much HTTP traffic was the user agent empty?
httpSomeUserAgent <- httpData[!(httpData$user_agent==""),]
httpSomeUserAgent <- removeHttpDuplicates(httpSomeUserAgent)
#httpSomeUserAgent <- httpSomeUserAgent[httpData$trans_depth==1,]
# What is the distribution of traffic with an empty user agent?
someAgentShare <- computeHttpCondTrafficShare(httpSomeUserAgent)
pdf(paste(resultsDir, "/appusage_someuseragent_traffic.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[3] <-0.5
mar[4] <- 0.5
par(mar=mar)
plot(someAgentShare$sort_order, someAgentShare$frac_http_bytes, pch=0, xlim=c(1,max(someAgentShare$sort_order)), las=1,
     ylim=c(0.88,1), cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     yaxt="n",
     xlab="Device ID (ordered by OS & total traffic volume from device)",
     ylab="HTTP Traffic Share")
axis(2, at=seq(0.88,1,0.04), labels=seq(0.88,1,0.04),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(1, at=seq(1,nrow(someAgentShare),1), labels=F)
axis(2, at=seq(0.88,1,0.005), labels=F)
points(someAgentShare$sort_order, someAgentShare$frac_http_flows, pch=1, cex=cexVal)
grid(lwd=3)
legend(1,0.94, c("Volume", "Flows"),
       pch=c(0,1,2), cex=cexVal)
abline(v=(numIOS+0.5), h=NULL, lty=2,lwd=5, col="black")
text(numIOS-1, 0.93, "iOS", cex=cexVal, adj=1)
text(numIOS+1.5, 0.93, "Android", cex=cexVal, adj=0)
dev.off()
# To whom is the traffic sent to across users. 

emptyHostAggr <- computeHttpHostAggr(httpSomeUserAgent)
emptyHostAggr$bytes_per_flow = emptyHostAggr$tot_bytes/emptyHostAggr$num_flows
emptyHostAggr <- emptyHostAggr[order(emptyHostAggr$num_users, decreasing=TRUE), ]
write.table(emptyHostAggr, paste(resultsDir, "/appusage_emptyuseragent_tophosts.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(emptyHostAggr)), row.names=FALSE)
###################################################################################
###################################################################################
############## Look at flows with some app signature ##############################
###################################################################################

httpSigsData <- httpData[!(httpData$app_label=="-"),]
httpSigsData <- removeHttpDuplicates(httpSigsData)
# What is the distribution of traffic with an empty user agent?
someSigShare <- computeHttpCondTrafficShare(httpSigsData)
pdf(paste(resultsDir, "/appusage_someappsig_traffic.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[3] <-0.5
mar[4] <- 0.5
par(mar=mar)
plot(someSigShare$sort_order, someSigShare$frac_http_bytes, pch=0, xlim=c(1,max(someSigShare$sort_order)), las=1,
     ylim=c(0,1), cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlab="Device ID (ordered by OS & total traffic volume from device)",
     ylab="HTTP Traffic Share")
points(someSigShare$sort_order, someSigShare$frac_http_flows, pch=1, cex=cexVal)
#lines(someSigShare$sort_order, someSigShare$frac_http_bytes, lwd=1, lty=3)
#lines(someSigShare$sort_order, someSigShare$frac_http_flows, lwd=1, lty=3)
par(tcl=0.22)
axis(2, at=seq(0,1,0.05), labels=F)
axis(1, at=seq(1,nrow(someSigShare),1), labels=F)
grid(lwd=3)
legend(1,0.3, c("Volume", "Flows"),
       pch=c(0,1), cex=cexVal)
abline(v=(numIOS+0.5), h=NULL, lty=2,lwd=5, col="black")
text(numIOS-1, 0.05, "iOS", cex=cexVal, adj=1)
text(numIOS+1.5, 0.05, "Android", cex=cexVal, adj=0)       
dev.off()

httpEmptySigsData <- httpData[(httpData$app_label=="-"),]
emptySigAggr <- computeHttpHostAggr(httpEmptySigsData)
emptySigAggr <- emptySigAggr[order(emptySigAggr$num_users, decreasing=TRUE), ]
write.table(emptySigAggr, paste(resultsDir, "/appusage_noappsig_tophosts_orderedusers.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(emptySigAggr)), row.names=FALSE)
emptySigAggr <- emptySigAggr[order(emptySigAggr$tot_bytes, decreasing=TRUE), ]
write.table(emptySigAggr, paste(resultsDir, "/appusage_noappsig_tophosts_orderedbytes.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(emptySigAggr)), row.names=FALSE)

###################################################################################
###################################################################################
############## Look at flows with valid app signature #############################
###################################################################################                     
# THIS IS USELESS
httpSigsData <- httpData[!(httpData$app_label=="-"),]
httpSigsData <- removeHttpDuplicates(httpSigsData)
#
httpSigsData$app_label <- clusterAppsAndServices(httpSigsData$app_label)
appLabelAggr <- computeHttpAppAggr(httpSigsData)
write.table(appLabelAggr, paste(resultsDir, "/appusage_topapps_orderedusers.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(appLabelAggr)), row.names=FALSE)
appLabelAggr <- appLabelAggr[order(appLabelAggr$tot_bytes, decreasing=TRUE), ]
write.table(appLabelAggr, paste(resultsDir, "/appusage_topapps_orderedbytes.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(appLabelAggr)), row.names=FALSE)

###################################################################################
###################################################################################
############## Look at flows with valid app signature and webservice ##############
###################################################################################  

httpWebServiceData <- httpData;
httpWebServiceData <- removeHttpDuplicates(httpWebServiceData)
# Copy webservice as app_label for flows where we did not find a valid app label but we found a webservice
httpWebServiceData[!(httpWebServiceData$webservice=="-"),]$app_label = httpWebServiceData[!(httpWebServiceData$webservice=="-"),]$webservice
# Now filter for incomplete app label
httpSomeServiceData <- httpWebServiceData[!(httpWebServiceData$app_label=="-"),]
# httpSomeServiceData$app_label <- clusterAppsAndServices(httpSomeServiceData$app_label) 
webserviceAggr <- computeHttpAppAggr(httpSomeServiceData)
tmp <- computeHttpCondTrafficShare(httpSomeServiceData)
pdf(paste(resultsDir, "/appusage_someappservicesig_traffic.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[3] <-0.5
mar[4] <- 0.5
par(mar=mar)
plot(tmp$sort_order, tmp$frac_http_bytes, pch=0, xlim=c(1,max(tmp$sort_order)), las=1,
     ylim=c(0,1), cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlab="Device ID (ordered by OS & total traffic volume from device)",
     ylab="HTTP Traffic Share")
points(tmp$sort_order, tmp$frac_http_flows, pch=1, cex=cexVal)
par(tcl=0.22)
axis(2, at=seq(0,1,0.05), labels=F)
axis(1, at=seq(1,nrow(tmp),1), labels=F)
grid(lwd=3)
legend(1,0.3, c("Volume", "Flows"),
       pch=c(0,1,2,3), cex=cexVal)
abline(v=(numIOS+0.5), h=NULL, lty=2,lwd=5, col="black")
text(numIOS-1, 0.05, "iOS", cex=cexVal, adj=1)
text(numIOS+1.5, 0.05, "Android", cex=cexVal, adj=0)    
dev.off()

httpNoServiceAggr <- httpWebServiceData[httpWebServiceData$app_label=="-",]
httpNoServiceAggr <- computeHttpHostAggr(httpNoServiceAggr)
httpNoServiceAggr <- httpNoServiceAggr[order(httpNoServiceAggr$num_users, decreasing=TRUE), ]
write.table(httpNoServiceAggr, paste(resultsDir, "/appusage_noappservice_orderedusers.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(httpNoServiceAggr)), row.names=FALSE)
httpNoServiceAggr <- httpNoServiceAggr[order(httpNoServiceAggr$tot_bytes, decreasing=TRUE), ]
write.table(httpNoServiceAggr, paste(resultsDir, "/appusage_noappservice_orderedbytes.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(httpNoServiceAggr)), row.names=FALSE)
###################################################################################
###################################################################################
# Compare the difference between iOS and Android for media content ################
###################################################################################
###################################################################################

youtubeRows <- httpData[grep("youtube", httpData$host), ];
youtubeAggr <- aggregate(youtubeRows[c("tot_bytes", "num_flows")],
                         by=list(app_label=youtubeRows$app_label, operating_system=youtubeRows$operating_system),
                         FUN=sum)

youtubeAggr <- aggregate(youtubeRows[c("tot_bytes", "num_flows")],
                         by=list(user_agent=youtubeRows$user_agent, operating_system=youtubeRows$operating_system),
                         FUN=sum)
youtubeAggr <- youtubeAggr[order(youtubeAggr$tot_bytes, decreasing=TRUE),];
