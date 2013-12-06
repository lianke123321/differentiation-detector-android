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
removeSslDuplicates <- function(inpSsl) {
  return(inpSsl[!duplicated(inpSsl$uid),])
}

sslData <- readSslData(paste(broAggDir, "merge.conn.ssl.info.dns", sep=""));
#sslData <- readSslData(paste(broAggDir, 'ssl.log.info.dns',sep=""))
sslData$tot_bytes <- convertStringColsToDouble(sslData$orig_ip_bytes) + convertStringColsToDouble(sslData$resp_ip_bytes)
sslData$num_flows <- as.numeric(1)
sortOrderTable <-readTable(paste(broAggDir, 'devices.sortorder.txt', sep=""))
numIOS <- nrow(sortOrderTable[sortOrderTable$operating_system=="i",])

sslSummary <- removeSslDuplicates(sslData)
### There is an issue with the number of flows in conn.log and the flows in the http.log.
### Use the http.log to get the number of flows - and try to maximise the number of flows
### that can be categorized.
connSslAggr <- aggregate(sslSummary[c("tot_bytes","num_flows")],
                          by=list(user_id=sslSummary$user_id, 
                                  operating_system=sslSummary$operating_system),
                          FUN=sum)
###################################################################################
###################################################################################
############## Define Functions for Usage  ########################################
###################################################################################

computeSslCondTrafficShare <- function(sslCondData) {
  sslCondData$num_flows<-1
  x <- aggregate(sslCondData[c("tot_bytes", "num_flows")],
                 by=list(user_id=sslCondData$user_id, 
                         operating_system=sslCondData$operating_system),
                 FUN=sum)                                                     
  colnames(x) <- gsub("tot_bytes", "tot_bytes_cond", colnames(x))
  colnames(x) <- gsub("num_flows", "num_flows_cond", colnames(x))
  tmp<-merge(x=x, y=connSslAggr, all.y=TRUE)
  tmp[is.na(tmp)]<-0
  tmp$frac_ssl_bytes <- tmp$tot_bytes_cond/tmp$tot_bytes;
  tmp$frac_ssl_flows <- tmp$num_flows_cond/tmp$num_flows;
  colnames(tmp) <- gsub("tot_bytes", "tot_bytes_ssl", colnames(tmp))
  colnames(tmp) <- gsub("num_flows", "num_flows_ssl", colnames(tmp))  
  tmp <- merge(x=tmp, y=sortOrderTable, by=c("user_id", "operating_system"))
  tmp <- tmp[(order(tmp$sort_order)),]
  return(tmp)
}

combineSslBasedOnSessionID <- function(condSslData) {
  tmp <- condSslData
  # Find rows that have a valid subject with a session id
  tmp <- condSslData[(condSslData$subject!="" & condSslData$subject!="-"),]
  # Now get the subject field in the rows that have a valid session id
  tmp1 <- data.frame(id.resp_h=tmp$id.resp_h, session_subject=tmp$subject, user_id=tmp$user_id, stringsAsFactors=FALSE)
  tmp <- condSslData;
  # Now merge the newly found subject with the rows that have the same session id
  tmp2 <- merge(x=tmp, y=tmp1)
  tmp <- tmp2
  #tmp[is.na(tmp$session_subject), ]$session_subject<-"-"
  tmp[(tmp$subject=="-"), ]$subject <- tmp[(tmp$subject=="-"), ]$session_subject
  tmp$session_subject <- NULL 
  return(tmp)
}

filterBasedOnServerName <- function(condSslData) {
  return (condSslData[!((condSslData$server_name=="")|(condSslData$server_name=="-") |(length(condSslData$server_name)<2)),])
}

# This function assumes that a signature is present in the condSslData$sign_label column
# it then aggregates based on the given signature
computeSslSignAggr <- function (condSslData) {
  aggrData <- aggregate(condSslData[c("tot_bytes", "num_flows")],
                        by=list(sign_label=condSslData$sign_label),
                        FUN=sum)
  tmpAggrData <- aggregate(condSslData[c("num_flows")],
                           by=list(sign_label=condSslData$sign_label,
                                   user_id=condSslData$user_id),
                           FUN=sum)
  colnames(tmpAggrData) <- gsub("num_flows", "num_users", colnames(tmpAggrData))
  tmpAggrData$num_users<-1
  tmpAggrData <- aggregate(tmpAggrData[c("num_users")],
                           by=list(sign_label=tmpAggrData$sign_label),
                           FUN=sum)
  aggrData <- merge(x=aggrData, y=tmpAggrData, all.x=TRUE);
  tmpAggrData <- condSslData[condSslData$operating_system=="a",]
  tmpAggrData <- aggregate(tmpAggrData[c("num_flows")],
                           by=list(sign_label=tmpAggrData$sign_label,
                                   user_id=tmpAggrData$user_id),
                           FUN=sum)
  colnames(tmpAggrData) <- gsub("num_flows", "num_android_users", colnames(tmpAggrData))
  tmpAggrData$num_android_users<-1
  tmpAggrData <- aggregate(tmpAggrData[c("num_android_users")],
                           by=list(sign_label=tmpAggrData$sign_label),
                           FUN=sum)
  aggrData <- merge(x=aggrData, y=tmpAggrData, all.x=TRUE);
  aggrData[is.na(aggrData)] <- 0
  return(aggrData)
}

###################################################################################
###################################################################################
############## Look at flows with PortNumbers  ####################################
###################################################################################
sslPort <- sslData
sslPort <- removeSslDuplicates(sslPort)
osSslAggr <- aggregate(sslPort[c("tot_bytes","num_flows")],
                       by=list(operating_system=sslPort$operating_system),
                       FUN=sum)
sslPort$port_name <- "-"
sslPort[(sslPort$id.orig_p==443) | (sslPort$id.resp_p==443),]$port_name <- "https"
mailPorts <- c(993,995,465)
sslPort[(sslPort$id.orig_p %in% mailPorts) | (sslPort$id.resp_p %in% mailPorts),]$port_name <- "mail"
sslPort[(sslPort$operating_system=="i") &  
          ((sslPort$id.orig_p ==5223) | (sslPort$id.resp_p ==5223)),]$port_name <- "notification"
sslPort[(sslPort$operating_system=="a") &  
          ((sslPort$id.orig_p ==5228) | (sslPort$id.resp_p ==5228)),]$port_name <- "notification"

sslPortAggr <- aggregate(sslPort[c("tot_bytes", "num_flows")],
                         by=list(operating_system=sslPort$operating_system,
                                 port_name=sslPort$port_name),
                         FUN=sum)
colnames(sslPortAggr) <- gsub("tot_bytes", "port_tot_bytes", colnames(sslPortAggr))
colnames(sslPortAggr) <- gsub("num_flows", "port_num_flows", colnames(sslPortAggr))
sslPortAggr <- merge(osSslAggr, sslPortAggr)
sslPortAggr$frac_bytes <- 100*sslPortAggr$port_tot_bytes/sslPortAggr$tot_bytes
sslPortAggr$frac_flows <- 100*sslPortAggr$port_num_flows/sslPortAggr$num_flows
sslPortAggr
write.table(sslPortAggr, paste(resultsDir, "/sslanalysis_ssltrafficshare_by_port.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(sslPortAggr)), row.names=FALSE)
###################################################################################
###################################################################################
############## HTTPs Flows analysis  ##########################################
###################################################################################
###################################################################################
getSslSubjectCNs <- function(sslSubjects) {  
  cnStrings <- sapply(sslSubjects, function(x) {    
    #print(x)
    y<- regexpr("CN=.*?(\b|,|$)", x);
    #print(y)
    if (y != -1) {
      # #+3 for CN=
      signature<-unlist(strsplit(substring(x, y+3, y+attr(y, "match.length")-1), ","))
    } else {            
      signature <- "-"
    }
    # Remove the preceding *.
    #signature <- gsub("\\*\\.", "", signature)      
    signature
  }, USE.NAMES=FALSE)
  x <- data.frame(subject=sslSubjects, cn=cnStrings, stringsAsFactors=FALSE)
  return(x);
}

computeHttpsOSShare <- function(httpCondData) {
  httpCondData$num_flows<-1
  x <- aggregate(httpCondData[c("tot_bytes", "num_flows")],
                 by=list(operating_system=httpCondData$operating_system),
                 FUN=sum)                                                     
  colnames(x) <- gsub("tot_bytes", "tot_bytes_cond", colnames(x))
  colnames(x) <- gsub("num_flows", "num_flows_cond", colnames(x))
  tmp<-merge(x=x, y=sslHttpsAggr, all.y=TRUE)
  tmp[is.na(tmp)]<-0
  tmp$frac_http_bytes <- tmp$tot_bytes_cond/tmp$tot_bytes;
  tmp$frac_http_flows <- tmp$num_flows_cond/tmp$num_flows;
  colnames(tmp) <- gsub("tot_bytes", "tot_bytes_http", colnames(tmp))
  colnames(tmp) <- gsub("num_flows", "num_flows_http", colnames(tmp))  
  return(tmp)
}

sslCN <- sslData#[(sslData$id.orig_p == 443) | (sslData$id.resp_p==443),]
tmpSubject <- sslCN$subject
tmpSubject[is.na(tmpSubject)] <- "-"
sslCN$subject <- tmpSubject
rm(tmpSubject)
#sslCN <- removeSslDuplicates(sslCN)
#sslHttpsAggr <- aggregate(sslCN[c("tot_bytes","num_flows")],
#                          by=list(operating_system=sslCN$operating_system),
#                          FUN=sum)
sslCNSignatures <- getSslSubjectCNs(unique(sslCN$subject))
nrow(sslCN)
sslCN <- merge(x=sslCN, y=sslCNSignatures)
nrow(sslCN)
sslNoCN <- sslCN[sslCN$cn=="-",]
sslCN <- sslCN[sslCN$cn!="-",]
sslFqdnCN <- sslCN[grep("\\*", sslCN$cn, invert=TRUE),]
sslStarCN <- sslCN[grep("\\*", sslCN$cn),]
noCnShare <- computeHttpsOSShare(sslNoCN)
fqdnCnShare <- computeHttpsOSShare(sslFqdnCN)
starCnShare <- computeHttpsOSShare(sslStarCN)


# New aggregate for remainder of traffic
sslHttpsAggr <- aggregate(sslCN[c("tot_bytes","num_flows")],
                          by=list(operating_system=sslCN$operating_system),
                          FUN=sum)
# Flows with ambiguous
httpsServerName <- sslCN
httpsServerName <- removeSslDuplicates(httpsServerName)
httpsServerName <- httpsServerName[(httpsServerName$server_name!="-") & (httpsServerName$server_name!=""),]
httpsServerShare <- computeHttpsOSShare(httpsServerName)

sslSameDns <- sslCN
sslSameDns<- sslSameDns[sslSameDns$dns_first_fqdn == sslSameDns$dns_latest_fqdn,]
sslSameDnsShare <- computeHttpsOSShare(sslSameDns)

# Done again for all traffic
sslCN <- sslData[(sslData$id.orig_p == 443) | (sslData$id.resp_p==443),]
sslCN <- removeSslDuplicates(sslCN)
sslHttpsAggr <- aggregate(sslCN[c("tot_bytes","num_flows")],
                          by=list(operating_system=sslCN$operating_system),
                          FUN=sum)
sslSameDns <- sslCN
sslSameDns<- sslSameDns[sslSameDns$dns_first_fqdn == sslSameDns$dns_latest_fqdn,]
sslSameDnsShare <- computeHttpsOSShare(sslSameDns)


#sslDiffDNSServer <- sslCN[(sslCN$server_name!="-") &
#                            ((sslCN$server_name!=sslCN$dns_latest_fqdn) |
#                            (sslCN$server_name!=sslCN$dns_first_fqdn)),]
httpsServerName <- httpsServerName[(httpsServerName$server_name!="-") & (httpsServerName$server_name!=""),]
sslDiffDNSServer <- httpsServerName[(httpsServerName$server_name!="-") &
                            ((httpsServerName$server_name!=httpsServerName$dns_latest_fqdn)),]
sslHttpsAggr <- aggregate(httpsServerName[c("tot_bytes","num_flows")],
                          by=list(operating_system=httpsServerName$operating_system),
                          FUN=sum)
sslDiffDnsServerShare <- computeHttpsOSShare(sslDiffDNSServer)

###################################################################################
###################################################################################
############## HTTPs Service grouping  ##########################################
###################################################################################
###################################################################################

#sslData <- readSslData(paste(broAggDir, 'ssl.log.info.dns',sep=""))
#sslData$tot_bytes <- convertStringColsToDouble(sslData$orig_ip_bytes) + convertStringColsToDouble(sslData$resp_ip_bytes)
#sslData$num_flows <- 1
#sortOrderTable <-readTable(paste(broAggDir, 'devices.sortorder.txt', sep=""))
#uniqueDNS <- unique(sslData$dns_first_fqdn)
sslData <- removeSslDuplicates(sslData)
sslOSAggr <- aggregate(sslData[c("tot_bytes","num_flows")],
                         by=list(operating_system=sslData$operating_system),
                         FUN=sum)
computeSslShare <- function(sslCondData) {
  sslCondData$num_flows<-1
  x <- aggregate(sslCondData[c("tot_bytes", "num_flows")],
                 by=list(operating_system=sslCondData$operating_system),
                 FUN=sum)                                                     
  colnames(x) <- gsub("tot_bytes", "tot_bytes_cond", colnames(x))
  colnames(x) <- gsub("num_flows", "num_flows_cond", colnames(x))
  tmp<-merge(x=x, y=sslOSAggr, all.y=TRUE)
  tmp[is.na(tmp)]<-0
  tmp$frac_ssl_bytes <- tmp$tot_bytes_cond/tmp$tot_bytes;
  tmp$frac_ssl_flows <- tmp$num_flows_cond/tmp$num_flows;
  colnames(tmp) <- gsub("tot_bytes", "tot_bytes_ssl", colnames(tmp))
  colnames(tmp) <- gsub("num_flows", "num_flows_ssl", colnames(tmp))    
  return(tmp)
}

### Top hosts
hostAggr <- sslData[sslData$operating_system=="a",]
hostAggr <- aggregate(hostAggr[c("tot_bytes", "num_flows")],
                      by=list(dns_first_fqdn=hostAggr$dns_first_fqdn),
                      FUN=sum)
hostAggr <- hostAggr[order(hostAggr$tot_bytes, decreasing=TRUE),]
hostAggr[1:10,]
hostAggr <- sslData[sslData$operating_system=="i",]
hostAggr <- aggregate(hostAggr[c("tot_bytes", "num_flows")],
                      by=list(dns_first_fqdn=hostAggr$dns_first_fqdn),
                      FUN=sum)
hostAggr <- hostAggr[order(hostAggr$tot_bytes, decreasing=TRUE),]
hostAggr[1:10,]

sslData$ssl_service_label <- "-"
sslData[grep("messenger\\.live", sslData$dns_first_fqdn), ]$ssl_service_label <- "im"
sslData[grep("skype", sslData$dns_first_fqdn), ]$ssl_service_label <- "im"
sslData[grep("talk", sslData$dns_first_fqdn), ]$ssl_service_label <- "im"
sslData[grep("play.google", sslData$dns_first_fqdn), ]$ssl_service_label <- "os_store"
sslData[grep("apple", sslData$dns_first_fqdn), ]$ssl_service_label <- "os_store"
sslData[grep("market", sslData$dns_first_fqdn), ]$ssl_service_label <- "os_store"

sslData[grep("twitter", sslData$dns_first_fqdn), ]$ssl_service_label <- "social"
sslData[grep("twimg", sslData$dns_first_fqdn), ]$ssl_service_label <- "social"
sslData[grep("fbcdn", sslData$dns_first_fqdn), ]$ssl_service_label <- "social"
sslData[grep("fbstatic", sslData$dns_first_fqdn), ]$ssl_service_label <- "social"
sslData[grep("facebook", sslData$dns_first_fqdn), ]$ssl_service_label <- "social"
sslData[grep("picasa", sslData$dns_first_fqdn), ]$ssl_service_label <- "social"
sslData[grep("linked", sslData$dns_first_fqdn), ]$ssl_service_label <- "social"
sslData[grep("plus", sslData$dns_first_fqdn), ]$ssl_service_label <- "social"
sslData[grep("quora", sslData$dns_first_fqdn), ]$ssl_service_label <- "social"

sslData[grep("youtube", sslData$dns_first_fqdn), ]$ssl_service_label <- "media"
sslData[grep("video", sslData$dns_first_fqdn), ]$ssl_service_label <- "media"
sslData[grep("dailymotion", sslData$dns_first_fqdn), ]$ssl_service_label <- "media"
sslData[grep("dmcdn", sslData$dns_first_fqdn), ]$ssl_service_label <- "media"
sslData[grep("netflix", sslData$dns_first_fqdn), ]$ssl_service_label <- "media"

mailPorts <- c(993,995,465)
sslData[(sslData$id.orig_p %in% mailPorts) | (sslData$id.resp_p %in% mailPorts),]$ssl_service_label <- "mail"
sslData[grep("mail", sslData$dns_first_fqdn), ]$ssl_service_label <- "mail"
sslData[grep("imap", sslData$dns_first_fqdn), ]$ssl_service_label <- "mail"
sslData[grep("smtp", sslData$dns_first_fqdn), ]$ssl_service_label <- "mail"
sslData[grep("mail", sslData$server_name), ]$ssl_service_label <- "mail"


sslMailShare <- computeSslShare(sslData[sslData$ssl_service_label=="mail",])
sslMailAggr <- aggregate(sslData[c("tot_bytes","num_flows")],
                         by=list(ssl_service_label=sslData$ssl_service_label,
                                 user_id=sslData$user_id,
                                 technology=sslData$technology,
                                 operating_system=sslData$operating_system),
                         FUN=sum)
sslMailAggr <- sslMailAggr[sslMailAggr$ssl_service_label=="mail",]
sslCellMail <- sslMailAggr[sslMailAggr$technology=="c",]
colnames(sslCellMail) <- gsub("tot_bytes", "cell_tot_bytes", colnames(sslCellMail))
colnames(sslCellMail) <- gsub("num_flows", "cell_num_flows", colnames(sslCellMail))
colnames(sslCellMail) <- gsub("technology", "cell_technology", colnames(sslCellMail))
sslWifiMail <- sslMailAggr[sslMailAggr$technology=="w",]
colnames(sslWifiMail) <- gsub("tot_bytes", "wifi_tot_bytes", colnames(sslWifiMail))
colnames(sslWifiMail) <- gsub("num_flows", "wifi_num_flows", colnames(sslWifiMail))
sslDeviceMail <- merge(x=sslCellMail, y=sslWifiMail, all.x=TRUE, all.y=TRUE)




sslMailAggr$byte_share <- sslMailAggr$tot_bytes/sslMailAggr$num_flows


sslSocialShare <- computeSslShare(sslData[sslData$ssl_service_label=="social",])
sslStoreShare <- computeSslShare(sslData[sslData$ssl_service_label=="os_store",])
sslMediaShare <- computeSslShare(sslData[sslData$ssl_service_label=="media",])

sslData[grep("apple", sslData$dns_first_fqdn), ]$ssl_service_label <- "apple"
sslData[grep("itunes", sslData$dns_first_fqdn), ]$ssl_service_label <- "apple"

googleData <- sslData[grep("google", sslData$dns_first_fqdn),]
googleShare <- computeSslShare(googleData[googleData$ssl_service_label=="-",])

appleShare <- computeSslShare(sslData[sslData$ssl_service_label=="apple",])

###################################################################################
###################################################################################
############## Look subject in SSL flows  ####################################
###################################################################################
getSslSubjectCNs <- function(sslSubjects) { 
  cnStrings <- sapply(sslSubjects, function(x) {
    y<- regexpr("CN=.*?(\b|,|$)", x);
    if (y != -1) {
      # #+3 for CN=
      signature<-unlist(strsplit(substring(x, y+3, y+attr(y, "match.length")-1), ","))
    } else {            
      signature <- "-"
    }
    # Remove the preceding *.
    #signature <- gsub("\\*\\.", "", signature)      
    signature
  }, USE.NAMES=FALSE)
  x <- data.frame(subject=sslSubjects, cn=cnStrings, stringsAsFactors=FALSE)
  return(x);
}
sslCN <- sslData
sslCN <- removeSslDuplicates(sslCN)
sslCNSignatures <- getSslSubjectCNs(unique(sslCN$subject))


###################################################################################
###################################################################################
############## Look at flows with ServerName  ####################################
###################################################################################
# How much HTTP traffic can we use the server name?

# The last check makes the first two redundant but I believe it makes the code readable
sslSomeServerName <- sslData
sslSomeServerName <- removeSslDuplicates(sslSomeServerName)
sslSomeServerName <- filterBasedOnServerName(sslSomeServerName)
#httpSomeUserAgent <- httpSomeUserAgent[httpData$trans_depth==1,]
# What is the distribution of traffic with an empty user agent?
someServerNameShare <- computeSslCondTrafficShare(sslSomeServerName)
pdf(paste(resultsDir, "/sslanalysis_someservername_traffic.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[3] <-0.5
mar[4] <- 0.5
par(mar=mar)
plot(someServerNameShare$sort_order, someServerNameShare$frac_ssl_bytes, pch=0, xlim=c(1,max(someServerNameShare$sort_order)), las=1,
     ylim=c(0,1), cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     yaxt="n",
     xlab="Device ID (ordered by OS & total traffic volume from device)",
     ylab="SSL Traffic Share")
axis(2, at=seq(0,1,0.2), labels=seq(0,1,0.2),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(1, at=seq(1,nrow(someServerNameShare),1), labels=F)
axis(2, at=seq(0,1,0.05), labels=F)
points(someServerNameShare$sort_order, someServerNameShare$frac_ssl_flows, pch=1, cex=cexVal)
grid(lwd=3)
legend(20,0.8, c("Volume", "Flows"),
       pch=c(0,1,2), cex=cexVal)
abline(v=(numIOS+0.5), h=NULL, lty=2,lwd=5, col="black")
text(numIOS-1, 0.93, "iOS", cex=cexVal, adj=1)
text(numIOS+1.5, 0.93, "Android", cex=cexVal, adj=0)
dev.off()

sslSomeServerName$sign_label <- sslSomeServerName$server_name
someServerNameAggr <- computeSslSignAggr(sslSomeServerName)
someServerNameAggr <- someServerNameAggr[order(someServerNameAggr$num_users, decreasing=TRUE), ]
write.table(someServerNameAggr, paste(resultsDir, "/sslanalysis_someservername_topserver_ordereduser.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(someServerNameAggr)), row.names=FALSE)
someServerNameAggr <- someServerNameAggr[order(someServerNameAggr$tot_bytes, decreasing=TRUE), ]
write.table(someServerNameAggr, paste(resultsDir, "/sslanalysis_someservername_topserver_orderedbytes.txt", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(someServerNameAggr)), row.names=FALSE)
###################################################################################
###################################################################################
############## Look at flows with CN or matching CN ###############################
###################################################################################

sslSomeSubject <- sslData
sslSomeSubject <- removeSslDuplicates(sslSomeSubject)
#combineSslSubject <- combineSslBasedOnSessionID(sslSomeSubject);
#x <- rbind(combineSslSubject, sslSomeSubject[!(sslSomeSubject$uid %in% combineSslSubject$uid), ])
sslSomeSubject<- sslSomeSubject[grep("*CN=", sslSomeSubject$subject), ]
someSubjectShare <- computeSslCondTrafficShare(sslSomeSubject)

pdf(paste(resultsDir, "/sslanalysis_somesubject_traffic.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[3] <-0.5
mar[4] <- 0.5
par(mar=mar)
plot(someSubjectShare$sort_order, someSubjectShare$frac_ssl_bytes, pch=0, xlim=c(1,max(someSubjectShare$sort_order)), las=1,
     ylim=c(0,1), cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     yaxt="n",
     xlab="Device ID (ordered by OS & total traffic volume from device)",
     ylab="SSL Traffic Share")
axis(2, at=seq(0,1,0.2), labels=seq(0,1,0.2),
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(1, at=seq(1,nrow(someSubjectShare),1), labels=F)
axis(2, at=seq(0,1,0.05), labels=F)
points(someSubjectShare$sort_order, someSubjectShare$frac_ssl_flows, pch=1, cex=cexVal)
grid(lwd=3)
legend(20,0.2, c("Volume", "Flows"),
       pch=c(0,1,2), cex=cexVal)
abline(v=(numIOS+0.5), h=NULL, lty=2,lwd=5, col="black")
text(numIOS-1, 0.93, "iOS", cex=cexVal, adj=1)
text(numIOS+1.5, 0.93, "Android", cex=cexVal, adj=0)
dev.off()










###################################################################################
############## Look at DNS records ################################################
###################################################################################

sslDns <- sslData
sslDns <- removeSslDuplicates(sslDns)
pdf(paste(resultsDir, "/sslanalysis_dns_timediff_distrib.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[3] <-0.5
mar[4] <- 0.5
par(mar=mar)
latest_diff <- sslDns[sslDns$operating_system=="a",]$ts - sslDns[sslDns$operating_system=="a",]$dns_latest_ts
latest_diff <- latest_diff[(latest_diff<100000)& (latest_diff>0)]
x<-knots(ecdf(latest_diff))
y<-(1:length(x))/length(x)
plot(x,y, type="l", lwd=3, log="x", lty=4,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     xaxt="n", las=1,
     xlim=c(0.01, 10000),
     xlab="Time between DNS request and TCP SYN packet(seconds)",
     ylab="CDF");
latest_diff <- sslDns[sslDns$operating_system=="i",]$ts - sslDns[sslDns$operating_system=="i",]$dns_latest_ts
latest_diff <- latest_diff[(latest_diff<100000)& (latest_diff>0)]
x<-knots(ecdf(latest_diff))
y<-(1:length(x))/length(x)
lines(x,y, type="l", lwd=4, lty=4)
first_diff <- sslDns[sslDns$operating_system=="a",]$ts - sslDns[sslDns$operating_system=="a",]$dns_first_ts
first_diff <- first_diff[(first_diff<100000)&(first_diff>0)]
first_diff <- first_diff[first_diff>0]
x<-knots(ecdf(first_diff))
y<-(1:length(x))/length(x)
lines(x,y, type="l", lwd=5, lty=3)
first_diff <- sslDns[sslDns$operating_system=="i",]$ts - sslDns[sslDns$operating_system=="i",]$dns_first_ts
first_diff <- first_diff[(first_diff<100000)&(first_diff>0)]
first_diff <- first_diff[first_diff>0]
x<-knots(ecdf(first_diff))
y<-(1:length(x))/length(x)
lines(x,y, type="l", lwd=4, lty=5)
grid(lwd=3)
axis(1, at=c(0.01, 0.1,1, 10, 100, 1000, 10000), las=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     labels=c("0.01", "0.1", "1", "10", "100", "1000", "10000"))
par(tcl=0.22)
axis(1, at=c(seq(0.01, 0.1, 0.01), seq(0.2, 1, 0.1),
             seq(2,10,1), seq(20,100,10), seq(200, 1000, 100),
             seq(2000,10000,1000)), labels=F)
legend(5,0.42, c("Recent response (iOS.)", "First in response (iOS.)",
                 "Recent response (And.)", "First in response (And.)"),
       lty=c(4,5,2,3), lwd=4, cex=cexVal)
dev.off()

###################################################################################
###################################################################################
############## Flows with different first and last ################################
###################################################################################

sslSameDns <- sslData
sslSameDns <- removeSslDuplicates(sslSameDns)
sslSameDns<- sslSameDns[sslSameDns$dns_first_fqdn == sslSameDns$dns_latest_fqdn,]
sameDnsShare <- computeSslCondTrafficShare(sslSameDns)

pdf(paste(resultsDir, "/sslanalysis_samedns_traffic.pdf", sep=""), height=9, width=16, pointsize=25)
mar <- par()$mar
mar[3] <-0.5
mar[4] <- 0.5
par(mar=mar)
plot(sameDnsShare$sort_order, sameDnsShare$frac_ssl_bytes, pch=0, xlim=c(1,max(sameDnsShare$sort_order)),
     ylim=c(0,1), cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal,
     yaxt="n",
     xlab="Device ID (ordered by OS & total traffic volume from device)",
     ylab="SSL Traffic share")
axis(2, at=seq(0,1,0.2), labels=seq(0,1,0.2), las=1,
     cex.lab=cexVal, cex.axis=cexVal, cex.main=cexVal, cex.sub=cexVal, cex=cexVal)
par(tcl=0.22)
axis(1, at=seq(1,nrow(sameDnsShare),1), labels=F)
axis(2, at=seq(0,1,0.05), labels=F)
points(sameDnsShare$sort_order, sameDnsShare$frac_ssl_flows, pch=1, cex=cexVal)
grid(lwd=3)
legend(20,0.6, c("Volume", "Flows"),
       pch=c(0,1,2), cex=cexVal)
abline(v=(numIOS+0.5), h=NULL, lty=2,lwd=5, col="black")
text(numIOS-1, 0.2, "iOS", cex=cexVal, adj=1)
text(numIOS+1.5, 0.2, "Android", cex=cexVal, adj=0)
dev.off()


