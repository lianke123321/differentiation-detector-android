baseDir<-"/user/arao/home/meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="");
setwd(scriptsDir);
broAggDir<-paste(baseDir,"/bro-aggregate-data/", sep="");
miscDataDir<-paste(baseDir, "/miscData/", sep="")
resultsDir<-paste(baseDir, "/paperData/", sep="");
cexVal<-1.5
source(paste(scriptsDir, "/readLogFiles.R", sep=""))

# First plot the ads and analytics info
adData <- readHttpData(paste(broAggDir, "filter.ads.http.log.info.ads.app", sep=""))
# Select first such adData column when multiple http flows have same uid
# because of multiple redirections. This orig_ip_bytes will be the same 
# in the flows because they have the same uid.
adData <- adData[!duplicated(adData$uid),]
adData$upload_bytes <- adData$orig_ip_bytes
adData$download_bytes <- adData$resp_ip_bytes
adData[adData$id.orig_p==80,]$upload_bytes <- adData[adData$id.orig_p==80,]$resp_ip_bytes
adData[adData$id.orig_p==80,]$download_bytes <- adData[adData$id.orig_p==80,]$orig_ip_bytes

#adData <- adData[adData$ad_flag==1,];
#adData[is.na(adData$operating_system), ]$operating_system="i";
adData$num_flows <- 1
adData$tot_bytes <- adData$orig_ip_bytes + adData$resp_ip_bytes
aggrAdData <- aggregate(adData[c("tot_bytes", "num_flows")], 
                          by=list(user_id=adData$user_id, technology=adData$technology, 
                                  operating_system=adData$operating_system),
                          FUN=sum)
names(aggrAdData) <- sub("tot_bytes", "ad_bytes", names(aggrAdData))
names(aggrAdData) <- sub("num_flows", "ad_flows", names(aggrAdData))
connSummary <- readTable(paste(broAggDir, "summary.conn.log.info", sep=""))
# Filter only tcp flows
connSummary <- connSummary[connSummary$proto=="tcp", ]
connSummary$orig_ip_bytes <- convertStringColsToDouble(connSummary$orig_ip_bytes)
connSummary$resp_ip_bytes <- convertStringColsToDouble(connSummary$resp_ip_bytes)
connSummary$num_flows <- convertStringColsToDouble(connSummary$num_flows)
connSummary$tot_bytes <- connSummary$orig_ip_bytes + connSummary$resp_ip_bytes
aggrTechData <- aggregate(connSummary[c("tot_bytes", "num_flows")], 
                          by=list(user_id=connSummary$user_id, technology=connSummary$technology),
                          FUN=sum)
# Rename the columns for merge
names(aggrTechData) <- sub("tot_bytes", "tot_tech_bytes", names(aggrTechData))
names(aggrTechData) <- sub("num_flows", "tot_tech_flows", names(aggrTechData))
aggrAdData <- merge(x=aggrAdData, y=aggrTechData, 
                    by=c("user_id", "technology"))
aggrAdData$tech_ad_frac_bytes <- aggrAdData$ad_bytes/aggrAdData$tot_tech_bytes;
aggrAdData$tech_ad_frac_flows <- aggrAdData$ad_flows/aggrAdData$tot_tech_flows;

aggrUserData <- aggregate(connSummary[c("tot_bytes", "num_flows")], 
                          by=list(user_id=connSummary$user_id),
                          FUN=sum)
names(aggrUserData) <- sub("tot_bytes", "tot_user_bytes", names(aggrUserData))
names(aggrUserData) <- sub("num_flows", "tot_user_flows", names(aggrUserData))
aggrAdData <- merge(x=aggrAdData, y=aggrUserData, 
                    by=c("user_id"))
aggrAdData$user_ad_frac_bytes <- aggrAdData$ad_bytes/aggrAdData$tot_user_bytes;
aggrAdData$user_ad_frac_flows <- aggrAdData$ad_flows/aggrAdData$tot_user_flows;

androidUsers <- unique(connSummary[connSummary$operating_system=="a",]$user_id);
iOSUsers <- unique(connSummary[connSummary$operating_system=="i",]$user_id);
# Now for dummy rows for entries that have zero adds for a given tech
wifiUsers <- unique(connSummary$user_id);
cellUsers <- unique(aggrAdData[aggrAdData$technology=="c",]$user_id);
tabUsers <- setdiff(wifiUsers, cellUsers)
# Add dummy rows for tablet users 
for(userID in tabUsers) {
  dummyRow <- data.frame(aggrAdData[1,])
  for (i in 1:ncol(dummyRow)) {
    dummyRow[,i] <- 0;
  }
  dummyRow$user_id = userID;
  dummyRow$operating_system = unique(connSummary[connSummary$user_id == userID, ]$operating_system)
  dummyRow$technology = "c"
  aggrAdData <- rbind(aggrAdData, dummyRow)
}
# Only cell no wifi
wifiUsers <- unique(aggrAdData[aggrAdData$technology=="w",]$user_id);
cellUsers <- unique(connSummary$user_id);
tabUsers <- setdiff(cellUsers, wifiUsers)
for(userID in tabUsers) {
  dummyRow <- data.frame(aggrAdData[1,])
  for (i in 1:ncol(dummyRow)) {
    dummyRow[,i] <- 0;
  }
  dummyRow$user_id = userID;
  dummyRow$operating_system = unique(connSummary[connSummary$user_id == userID, ]$operating_system)
  dummyRow$technology = "w"
  aggrAdData <- rbind(aggrAdData, dummyRow)
}

# Now sort the table for plotting
userTotAdShare <- aggregate(aggrAdData[c("user_ad_frac_bytes", "user_ad_frac_flows")], 
                            by=list(user_id=aggrAdData$user_id, operating_system=aggrAdData$operating_system),
                            FUN=sum)
userTotAdShare <- userTotAdShare[order(userTotAdShare$user_ad_frac_bytes, decreasing=TRUE),]
names(userTotAdShare) <- sub("user_ad_frac_bytes", "cumul_ad_frac_bytes", names(userTotAdShare))
names(userTotAdShare) <- sub("user_ad_frac_flows", "cumul_ad_frac_flows", names(userTotAdShare))
userTotAdShare$sort_order <- c(1:nrow(userTotAdShare))
#  Now order according to the OS; first iOS then Android
userTotAdShare[userTotAdShare$operating_system=="a",]$sort_order <- userTotAdShare[userTotAdShare$operating_system=="a",]$sort_order*1000;
numIOS <- nrow(userTotAdShare[userTotAdShare$operating_system=="i",])
userTotAdShare <- userTotAdShare[order(userTotAdShare$sort_order),]
userTotAdShare$sort_order <- c(1:nrow(userTotAdShare))
aggrAdData <- merge(x=aggrAdData, y=userTotAdShare, by="user_id")
# Put android devices in the end;
pdf(paste(resultsDir, "/ad_share_bytes.pdf", sep=""), height=10, width=16, pointsize=25)
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
plot(x=aggrAdData[aggrAdData$technology=="w", ]$sort_order,
     y=aggrAdData[aggrAdData$technology=="w", ]$cumul_ad_frac_bytes,
     xlim=c(0, length(aggrAdData[aggrAdData$technology=="w", ]$sort_order)+1),
     ylim=c(0,0.06),     
     pch=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xlab="Device ID (ordered by OS & share of ads & analytics flows)",
     ylab="Traffic share");
title("Traffic share of ads and analytics")
par(tcl=0.22)
axis(1, at=seq(0,max(aggrAdData$sort_order), 1), label=F)
axis(2, at=seq(0, 0.2, 0.01), label=F)
points(x=aggrAdData[aggrAdData$technology=="w", ]$sort_order, 
       y=aggrAdData[aggrAdData$technology=="w", ]$tech_ad_frac_bytes,
       pch=3,cex=cexVal)
points(x=aggrAdData[aggrAdData$technology=="c", ]$sort_order, 
       y=aggrAdData[aggrAdData$technology=="c", ]$tech_ad_frac_bytes,
       pch=2,cex=cexVal)
#points(x=aggrAdData[aggrAdData$technology=="w", ]$sort_order, 
#       y=aggrAdData[aggrAdData$technology=="w", ]$cumul_ad_frac_flows,
#       pch=0,cex=cexVal)
grid(lwd=2)
legend(5, 0.06, c("Total", "Cell", "Wi-fi"),
       cex=cexVal,
       pch=c(1,2,3))
abline(v=(numIOS+0.5), h=NULL, lty=2,lwd=5, col="black")
text(numIOS, 0.04, "iOS", cex=cexVal, adj=1)
text(numIOS+1, 0.04, "Android", cex=cexVal, adj=0)
dev.off()


# Now look at the popular sites that are responsible for the ads and analytics. 
#adData <- readHttpData(paste(broAggDir, "filter.ads.http.log.info.ads.app", sep=""))
#adData <- adData[!duplicated(adData$uid),]
#adData[is.na(adData$operating_system), ]$operating_system="i";
adData$num_flows <- 1
adData$tot_bytes <- adData$orig_ip_bytes + adData$resp_ip_bytes
adData$host_identifier <- sapply(adData$host,
                                 function(x) {
                                   y <- unlist(strsplit(x,"\\."))
                                   if ((nchar(y[length(y)]) > 2) & (nchar(y[length(y)-1]) > 2)) {
                                     y<-paste(tail(y,2), collapse=".")
                                   } else if (length(y) >= 3) {
                                     y <- paste(tail(y,3), collapse=".")
                                   }                                   
                                   y
                                 })
popularAds <- aggregate(adData[c("tot_bytes", "num_flows")], 
                        by=list(host_identifier=adData$host_identifier,
                                user_id=adData$user_id, technology=adData$technology, 
                                operating_system=adData$operating_system),
                        FUN=sum);
userTrackers <- aggregate(adData[c("num_flows")], 
                          by=list(host_identifier=adData$host_identifier,
                                  operating_system=adData$operating_system,
                                  user_id=adData$user_id),
                          FUN=sum);
userTrackers$num_users <- 1
allOsTrackers <- aggregate(userTrackers[c("num_users")], 
                          by=list(host_identifier=userTrackers$host_identifier),
                          FUN=sum);
allOsTrackers <- allOsTrackers[order(allOsTrackers$num_users, decreasing=TRUE),]
specificOsTrackers <- aggregate(userTrackers[c("num_users")], 
                           by=list(host_identifier=userTrackers$host_identifier,
                                   operating_system=userTrackers$operating_system),
                           FUN=sum);
names(specificOsTrackers) <- sub("num_users", "num_android_users", names(specificOsTrackers))
allOsTrackers <- merge(x=allOsTrackers, y=specificOsTrackers[specificOsTrackers$operating_system=="a",],
                       by=c("host_identifier"))
allOsTrackers$operating_system<-NULL
names(specificOsTrackers) <- sub("num_android_users", "num_ios_users", names(specificOsTrackers))
allOsTrackers <- merge(x=allOsTrackers, y=specificOsTrackers[specificOsTrackers$operating_system=="i",],
                       by=c("host_identifier"))
allOsTrackers$operating_system<-NULL
allOsTrackers <- allOsTrackers[order(allOsTrackers$num_users, decreasing=TRUE),]
write.table(allOsTrackers, paste(resultsDir, '/popular-ads-analytics.txt', sep=""),
            sep="\t", quote=F, col.names=c(colnames(allOsTrackers)), row.names=FALSE)

#xvals <- 1:10
#plot(x=xvals, y=allOsTrackers[xvals,]$num_users,
#     xlim=c(1, length(xvals)+1),
#     ylim=c(0,max(allOsTrackers$num_users)+1),
#     pch=0,
#     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,     
#     xlab="Tracker",
#     ylab="Number of users");
#axis(1, at=1:10, labels=letters[1:10])

# The above table has the top trackers we observe that were able to track all our users
# Now ad which sites are top uploaders per flow

########################################################################
########################################################################
##### Who are the top uploaders ########################################
########################################################################
########################################################################
# The maximum data uploaded by the sites


#adData$bytes_per_flow <- adData$orig_ip_bytes/adData$num_flows

### Assumes the host identifier is computed
topAdUploadersAds <- aggregate(adData[c("upload_bytes", "num_flows")], 
                        by=list(host_identifier=adData$host_identifier),
                        FUN=sum);
topAdUploadersAds <- topAdUploadersAds[order(topAdUploadersAds$upload_bytes, decreasing=TRUE),]
#topAdUploadersAds <- topAdUploadersAds[order(topAdUploadersAds$orig_ip_bytes/topAdUploadersAds$num_flows), decreasing=TRUE),]
allUploads <- adData$upload_bytes
top1 <- adData[(adData$host_identifier==topAdUploadersAds[1,]$host_identifier),]$upload_bytes
top2 <- adData[(adData$host_identifier==topAdUploadersAds[2,]$host_identifier),]$upload_bytes
top3 <- adData[(adData$host_identifier==topAdUploadersAds[3,]$host_identifier),]$upload_bytes
top4 <- adData[(adData$host_identifier==topAdUploadersAds[4,]$host_identifier),]$upload_bytes
top5 <- adData[(adData$host_identifier==topAdUploadersAds[4,]$host_identifier),]$upload_bytes

pdf(paste(resultsDir,"distrib_ad_uploads.pdf", sep=""), height=10, width=16, pointsize=25) 
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
x<-knots(ecdf(top1))
y<-(1:length(x))/length(x)
plot(x,y, type="l", lwd=5, log="x", lty=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xaxt="n", yaxt="n",     
     xlim=c(min(adData$orig_ip_bytes), max(adData$orig_ip_bytes)*1.2),
     xlab="Amount of data uploaded per flow",
     ylab="CDF");     
axis(1, at=c(1000, 10*1000, 100*1000, 400*1000), las=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     labels=c("1KB","10KB", "100KB","400KB"))
axis(2, at=seq(0, 1, 0.2), las=1     ,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     labels=seq(0, 1, 0.2))
x<-knots(ecdf(top2))
y<-(1:length(x))/length(x)
lines(x,y,lwd=2,lty=2)

x<-knots(ecdf(top3))
y<-(1:length(x))/length(x)
lines(x,y,lwd=5,lty=3)

x<-knots(ecdf(top4))
y<-(1:length(x))/length(x)
lines(x,y,lwd=5,lty=4)

x<-knots(ecdf(allUploads))
y<-(1:length(x))/length(x)
lines(x,y,lwd=5,lty=5)

grid(lwd=2)
legend(10*1000, 0.8, c(topAdUploadersAds[1,]$host_identifier, 
                    topAdUploadersAds[2,]$host_identifier, 
                    topAdUploadersAds[3,]$host_identifier,
                    topAdUploadersAds[4,]$host_identifier,
                    "All Trackers"),
       cex=cexVal,
       lwd=5,
       lty=c(1,2,3,4,5))
#axis(1, at=c(500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000), 
#     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
#     labels=c("500", "1KB", "2KB", "5KB", "10KB", "20KB", "50KB", "100KB", "200KB", "500KB"))
par(tcl=0.22)
axis(1, at=c(seq(100, 1000, 100), seq(2*1000, 10*1000, 1000), seq(20*1000,100*1000, 10*1000), seq(200*1000,400*1000,100*1000)),
     labels=F)
axis(2, at=seq(0, 1, 0.02), labels=F)
dev.off()


topAdDownloaderAds <- aggregate(adData[c("download_bytes", "num_flows")], 
                        by=list(host_identifier=adData$host_identifier),
                        FUN=sum);
topAdDownloaderAds <- topAdDownloaderAds[order(topAdDownloaderAds$download_bytes, decreasing=TRUE),]
#topAdUploadersAds <- topAdUploadersAds[order(topAdUploadersAds$orig_ip_bytes/topAdUploadersAds$num_flows), decreasing=TRUE),]
allDownloads <- adData$download_bytes
top1 <- adData[(adData$host_identifier==topAdDownloaderAds[1,]$host_identifier),]$download_bytes
top2 <- adData[(adData$host_identifier==topAdDownloaderAds[2,]$host_identifier),]$download_bytes
top3 <- adData[(adData$host_identifier==topAdDownloaderAds[3,]$host_identifier),]$download_bytes
top4 <- adData[(adData$host_identifier==topAdDownloaderAds[4,]$host_identifier),]$download_bytes
top5 <- adData[(adData$host_identifier==topAdDownloaderAds[4,]$host_identifier),]$download_bytes

pdf(paste(resultsDir,"distrib_ad_downloads.pdf", sep=""), height=10, width=16, pointsize=25) 
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
x<-knots(ecdf(top1))
y<-(1:length(x))/length(x)
plot(x,y, type="l", lwd=5, log="x", lty=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xaxt="n", yaxt="n",     
     xlim=c(100, 10*1000*1000),
     xlab="Amount of data downloaded per flow",
     ylab="CDF");     
axis(1, at=c(1000, 10*1000, 100*1000, 1000*1000, 10*1000*1000), las=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     labels=c("1KB","10KB", "100KB","1 MB", "10 MB"))
axis(2, at=seq(0, 1, 0.2), las=1     ,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     labels=seq(0, 1, 0.2))
x<-knots(ecdf(top2))
y<-(1:length(x))/length(x)
lines(x,y,lwd=2,lty=2)

x<-knots(ecdf(top3))
y<-(1:length(x))/length(x)
lines(x,y,lwd=5,lty=3)

x<-knots(ecdf(top4))
y<-(1:length(x))/length(x)
lines(x,y,lwd=5,lty=4)

x<-knots(ecdf(allDownloads))
y<-(1:length(x))/length(x)
lines(x,y,lwd=5,lty=5)

grid(lwd=2)
legend(20*1000, 0.65, c(topAdDownloaderAds[1,]$host_identifier, 
                    topAdDownloaderAds[2,]$host_identifier, 
                    topAdDownloaderAds[3,]$host_identifier,
                    topAdDownloaderAds[4,]$host_identifier,
                    "All Trackers"),
       cex=cexVal,
       lwd=5,
       lty=c(1,2,3,4,5))
#axis(1, at=c(500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000), 
#     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
#     labels=c("500", "1KB", "2KB", "5KB", "10KB", "20KB", "50KB", "100KB", "200KB", "500KB"))
par(tcl=0.22)
axis(1, at=c(seq(100, 1000, 100), seq(2*1000, 10*1000, 1000), 
             seq(20*1000,100*1000, 10*1000), 
             seq(200*1000,1000*1000,100*1000),
             seq(2000*1000, 10000*1000, 1000*1000)),             
     labels=F)
axis(2, at=seq(0, 1, 0.02), labels=F)
dev.off()



#######################################################################
#######################################################################
########## How many trackers upload more than specific amount of bytes
#######################################################################
#######################################################################

byteSeq <- c(seq(0, 10*1000, 100),
             seq(11*1000, 100*1000, 1*1000),
             seq(110*1000, 500*1000, 10*1000))
numTrackers = rep(0, length(byteSeq))
for(i in 1:length(numTrackers)) {
  print(byteSeq[i])
  numTrackers[i] <- length(unique(adData[adData$upload_bytes>byteSeq[i],]$host_identifier))
}

byteSeq <- byteSeq[numTrackers>0]
numTrackers<-numTrackers[numTrackers>0]

xvals <- numTrackers[length(byteSeq)]
yvals <- byteSeq[length(byteSeq)]
for (i in (length(byteSeq)-1):1) {
  #print(i)
  if (numTrackers[i] != numTrackers[i+1]) {
    xvals <- c(xvals, numTrackers[i])
    yvals <- c(yvals, byteSeq[i])
  }
}

pdf(paste(resultsDir,"num_uploading_trackers.pdf", sep=""), height=10, width=16, pointsize=25) 
mar <- par()$mar
mar[4] <- 0.5
par(mar=mar)
plot(xvals, yvals, lty=1, log="x",
     lwd=5,xaxt="n",yaxt="n", pch=3,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     ylab="Upload per flow (KB)", 
     xlab="Number of Ads and Analytics sites")     
axis(2, seq(0, 500*1000,100*1000),
     label=c("0", "100", "200", "300", "400", "500"),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
axis(1, at=c(1, 10, 100), label=c(1, 10, 100), 
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
grid(lwd=3)
axis(2, at=seq(0, 500*1000, 10*1000),
     labels=F)
axis(1, at=c(seq(1, 10, 1), seq(20, 100, 10), 200),
     labels=F)
dev.off()

###############################################################################################
########  TBD:: Reciprocation of Data download/upload distribution ############################
###############################################################################################


#adData <- readHttpData(paste(broAggDir, "filter.ads.http.log.info.ads.app", sep=""))
#adData <- adData[!duplicated(adData$uid),]
#adData$upload_bytes <- adData$orig_ip_bytes
#adData$download_bytes <- adData$resp_ip_bytes
#adData[adData$id.orig_p==80,]$upload_bytes <- adData[adData$id.orig_p==80,]$resp_ip_bytes
#adData[adData$id.orig_p==80,]$download_bytes <- adData[adData$id.orig_p==80,]$orig_ip_bytes
#adData$reciprocity <- adData$download_bytes/adData$upload_bytes

###########################################################################################
############# Ads to apps #################################################################
###########################################################################################
adData$num_flows <- 1
adData$tot_bytes <- adData$orig_ip_bytes + adData$resp_ip_bytes

#aggrApps <- aggregate(adData[c("num_flows", "tot_bytes", "upload_bytes")],
#                      by=list(user_id=adData$user_id, technology=adData$technology,
#                              app_label=adData$app_label),
#                     FUN=sum);




adData$app_identifiable <- 0
adData[adData$app_label!="-",]$app_identifiable=1
aggrApps <- aggregate(adData[c("num_flows", "tot_bytes", "upload_bytes")],
                      by=list(operating_system=adData$operating_system,
                              user_id=adData$user_id,
                              app_identifiable=adData$app_identifiable),
                      FUN=sum);

aggrApps <- aggrApps[order(aggrApps$num_flows, decreasing=TRUE),]
andAdFlows <- sum(adData[adData$operating_system=="a", ]$num_flows)
iOSAdFlows <- sum(adData[adData$operating_system=="i", ]$num_flows)
aggrApps$frac_os_flows <- 0
aggrApps[aggrApps$operating_system=="a", ]$frac_os_flows <- aggrApps[aggrApps$operating_system=="a", ]$num_flows/andAdFlows
aggrApps[aggrApps$operating_system=="i", ]$frac_os_flows <- aggrApps[aggrApps$operating_system=="i", ]$num_flows/iOSAdFlows

#plot(aggrApps[aggrApps$operating_system=="i" & aggrApps$app_label != "-", ]$frac_os_flows)
#plot(aggrApps[aggrApps$operating_system=="a" & aggrApps$app_label != "-", ]$frac_os_flows)
                        





     

