# This script is used to assign the signature and the label we can identify based on the user agent field. 
# This file only annotates the http.log.* file with the signature that we identify based on the user agent. 

baseDir<-"/user/arao/home/meddle_data/"
#baseDir <- "/user/arao/home/china_meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
setwd(scriptsDir);
#broLogsDir<-paste(baseDir, "bro-results/", sep="");
broLogsDir<-paste(baseDir, "/bro-aggregate-data/", sep="")

unknownSslLabel="-"

source(paste(scriptsDir, "readLogFiles.R", sep=""))
fName <- paste(broLogsDir, "conn.log.info", sep="");

connData <- readConnData(fName)
connData <- labelProtoService()


sslData <- connData[connData$service=="ssl",]
#### Get the fqdn of the IP based on the dns information in the files
#fName <- paste(broLogsDir, "ssl.log.info", sep="");
#sslData <- readSslData(fName)
sslData <- sslData[order(sslData$ts),]
write.table(sslData, paste(broLogsDir, "/filter.conn.ssl.info", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(sslData)), row.names=FALSE)
sslData <- readConnData(paste(broLogsDir, "/filter.conn.ssl.info", sep=""))
dnsLookupTable <- readTable(paste(broLogsDir, "lookup.dns.log.info", sep=""))

# convertion makes sort faster and iteration checks faster
dnsLookupTable$ts <- convertStringColsToDouble(dnsLookupTable$ts)
dnsLookupTable$ttl <- convertStringColsToDouble(dnsLookupTable$ttl)
dnsLookupTable <- dnsLookupTable [order(dnsLookupTable$ts),]

sslData$dns_latest_fqdn <- "-"
sslData$dns_latest_ttl <- 0
sslData$dns_latest_ts <- 0
sslData$dns_first_fqdn <- "-"
sslData$dns_first_ts <- 0
sslData$dns_first_ttl <- 0
sslData$dns_unique_cnt <- 0
dnsTtlLimit<-36000 # 10 hours

for(userID in sort(unique(sslData$user_id), decreasing=TRUE)) {
  print(paste("Filtering for user", userID))
  sslUserData <- sslData[sslData$user_id==userID,]
  dnsUserData <- dnsLookupTable[dnsLookupTable$user_id == userID,]  
  ## Creating the vectors for fast iterations
  dnsTs <- dnsUserData$ts  
  sslTs <- sslUserData$ts
  dnsUserId <- dnsUserData$user_id
  sslUserId <- sslUserData$user_id
  dnsClientIP <- dnsUserData$client_ip
  dnsServerIP <- dnsUserData$server_ip
  sslOrigH <- sslUserData$id.orig_h
  sslRespH <- sslUserData$id.resp_h
  dnsFqdn <- dnsUserData$fqdn
  dnsRespOrder <- dnsUserData$resp_order
  dnsTTL <- dnsUserData$ttl
  sslFqdnLatest <- c()
  sslFqdnLatestTs <- c()
  sslFqdnLatestTTL <- c()
  sslFqdnFirstResp <- c()
  sslFqdnFirstRespTs <- c()
  sslFqdnFirstRespTTL <- c()
  sslFqdnCnt <- c()
  numSslRows <- nrow(sslUserData)
  numDnsRows <- nrow(dnsUserData)
  j<-as.numeric(2)
  i<-as.numeric(1)
  k<-as.numeric(j)
  while (i  <= numSslRows) {
    while ((j < numDnsRows) & (dnsTs[j] <= (sslTs[i]))) {
      j <- j+1;    
    }
    if (j>1) {
      j <- j-1 
    }
    k<-j
    # Todo:: can optimize by caching last result but its ok for now.
    latestHostName <- "-"
    latestHostNameTs <- 0
    latestHostNameTTL <- 0
    firstRespHostName <- "-"
    firstRespHostNameTs <- 0
    firstRespHostNameTTL <- 0
    dnsMatches <- c()
    respOrder <- c(1000)
    foundFirst <- FALSE
    while ((k > 1)) {
      if ((dnsUserId[k] == sslUserId[i])
          & ( ((dnsClientIP[k] == sslOrigH[i]) &(dnsServerIP[k] == sslRespH[i]))
              |((dnsClientIP[k] == sslRespH[i]) &(dnsServerIP[k] == sslOrigH[i])))) {
        dnsMatches <- c(dnsMatches, dnsFqdn[k])
        if (latestHostName == "-") {
          #print(paste("Found Latest", k))
          latestHostName <- dnsFqdn[k]
          latestHostNameTs<- dnsTs[k]
          latestHostNameTTL <- dnsTTL[k]
        }
        if ((firstRespHostName == "-") & (dnsRespOrder[k] == 1)) {
          #print(paste("Found First", k))
          firstRespHostName <- dnsFqdn[k]
          firstRespHostNameTs <- dnsTs[k]
          firstRespHostNameTTL <- dnsTTL[k]
          break
        }                
      }
      # This logic is incorrect because we do not know for sure if caching is IP specific
      #if ((!(dnsClientIP[k] == sslOrigH[i])) & (!(dnsClientIP[k] == sslOrigH[i]))) {
      #  print("Changing IP")
      #  break
      #}      
      k<-k-1;
      if (dnsTs[k]+dnsTtlLimit < sslTs[i]) {
        #print("Breaking")
        break
      } 
    }
    sslFqdnLatest <- c(sslFqdnLatest, latestHostName)  # pick the latest one
    sslFqdnLatestTs <- c(sslFqdnLatestTs, latestHostNameTs)
    sslFqdnLatestTTL <- c(sslFqdnLatestTTL, latestHostNameTTL)
    sslFqdnFirstResp <- c(sslFqdnFirstResp, firstRespHostName)
    sslFqdnFirstRespTs <- c(sslFqdnFirstRespTs, firstRespHostNameTs)
    sslFqdnFirstRespTTL <- c(sslFqdnFirstRespTTL, firstRespHostNameTs)
    sslFqdnCnt <- c(sslFqdnCnt, length(unique(dnsMatches)))    
    if (i %% 1000 == 1) {
      print(paste(i, "of ", numSslRows))
    }
    i<-i+1
  }
  sslData[sslData$user_id==userID,]$dns_latest_fqdn <- sslFqdnLatest
  sslData[sslData$user_id==userID,]$dns_latest_ts <- sslFqdnLatestTs
  sslData[sslData$user_id==userID,]$dns_latest_ttl <- sslFqdnLatestTTL
  sslData[sslData$user_id==userID,]$dns_first_fqdn <- sslFqdnFirstResp
  sslData[sslData$user_id==userID,]$dns_first_ts <- sslFqdnFirstRespTs
  sslData[sslData$user_id==userID,]$dns_first_ttl <- sslFqdnFirstRespTTL
  sslData[sslData$user_id==userID,]$dns_unique_cnt <- sslFqdnCnt
}
write.table(sslData, paste(broLogsDir, "/filter.conn.ssl.info.dns", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(sslData)), row.names=FALSE)

#filterSslData <- data.frame(sslData[c("ts", "uid", "user_id", 
#                                      "dns_latest_fqdn", "dns_latest_ts", "dns_latest_ttl",
#                                      "dns_first_fqdn", "dns_first_ts", "dns_first_ttl", 
#                                      "dns_unique_cnt")], stringsAsFactors=False)

sslData <- readSslData(paste(broLogsDir, "filter.conn.ssl.info.dns", sep="")) 
fName <- paste(broLogsDir, "ssl.log.info", sep="");
broSslData <- readSslData(fName)

mergeCols <- intersect(colnames(sslData), colnames(broSslData))

mergeSslData <- merge(sslData, broSslData, by=mergeCols, all.x=TRUE, all.y=TRUE)
write.table(mergeSslData, paste(broLogsDir, "/merge.conn.ssl.info.dns", sep=""), 
            sep="\t", quote=F, col.names=c(colnames(mergeSslData)), row.names=FALSE)

## 13% of the flows now do not have a fqdn
# For the ssl label give priority to the SSL label
# Then give priority for the latest DNS label
# sslData <-readSslData(paste(broLogsDir, "ssl.log.info.dns", sep=""))
# sslData$ssl_label <- sslData$server_name
# print(paste("Number of rows in the Table", nrow(sslData)))
# print(paste("Number of undefined rows", nrow(sslData[sslData$ssl_label=="-",])))
# sslData[(sslData$ssl_label=="-")|(sslData$ssl_label==""),]$ssl_label <- sslData[(sslData$ssl_label=="-")|(sslData$ssl_label==""),]$dns_fqdn_latest
# sslData[(sslData$ssl_label=="-")|(sslData$ssl_label==""),]$ssl_label <- sslData[(sslData$ssl_label=="-")|(sslData$ssl_label==""),]$dns_fqdn_first
# print(paste("Number of rows in the Table", nrow(sslData)))
# print(paste("Number of undefined rows", nrow(sslData[sslData$ssl_label=="-",])))
# #sslData[(sslData$id.resp_p == 5228) | (sslData$id.orig_p==5228),]$ssl_label<-"gcm"
# #sslData[(sslData$id.resp_p == 5223) | (sslData$id.orig_p==5223),]$ssl_label<-"apns"
# ## Add the ports for mail
# #sslData[(sslData$id.resp_p == 993) | (sslData$id.orig_p==993),]$ssl_label<-"mail"
# #sslData[(sslData$id.resp_p == 465) | (sslData$id.orig_p==465),]$ssl_label<-"mail"
# # secure mqtt -- todo lookup IP address and dns queries here
# #sslData[((sslData$id.resp_p == 8883) | (sslData$id.orig_p==8883))
# #       &(sslData$operating_system=="a"), ]$ssl_label<-"facebook_message"
# 
# 
# 
# print(paste("Number of rows in the Table", nrow(sslData)))
# print(paste("Number of undefined rows", nrow(sslData[sslData$ssl_label=="-",])))
# print(paste("Number of unique IPs for which DNS was not found", length(unique(sslData[sslData$ssl_label=="-",]$id.resp_h))))

# unique(sslData[(sslData$ssl_label=="-"),]$subject)
# 
# dnsLookupTable$count <-1 
# 
# # The number of 
# dnsAggr <- aggregate(dnsLookupTable[c("count")],
#                      by=list(client_ip=dnsLookupTable$client_ip,
#                              server_ip=dnsLookupTable$server_ip,
#                              fqdn=dnsLookupTable$fqdn),
#                      FUN=sum)
# # 
# dnsMaxAggr <- aggregate(dnsLookupTable[c("count")],
#                         by=list(client_ip=dnsLookupTable$client_ip,
#                                 server_ip=dnsLookupTable$server_ip),
#                         FUN=max)
# # Now we have the entries with the max count .. most probable hosts
# dnsAggr <- merge(x=dnsAggr, y=dnsMaxAggr, by=c("client_ip", "server_ip", "count"))
# ## For Testing


#fName <- paste(broLogsDir, "http.log.info.ads", sep="");
#httpDataLabeled <- readHttpData(fName)
#print("Number of rows where we have a valid subject but no session id was seen")
#nrow(sslData[sslData$subject!="-" & sslData$session_id=="-",])
#sslSignatures <- getSslSignatures()
#sslSignData <- merge(x=sslData, y=sslSignatures, all.x=TRUE)
#sslSignData[is.na(sslSignData$ssl_label),]$ssl_label=unknownSslLabel
# Assign label on port numbers
# sslData$ssl_label <- unknownSslLabel
# sslData[!((sslData$server_name=="-") | (sslData$server_name=="")),]$ssl_label  <- sslData[!((sslData$server_name=="-") | (sslData$server_name=="")),]$server_name
# sslData[(sslData$id.resp_p == 5228) | (sslData$id.orig_p==5228),]$ssl_label<-"gcm"
# sslData[(sslData$id.resp_p == 5223) | (sslData$id.orig_p==5223),]$ssl_label<-"apns"
# sslData[(sslData$id.resp_p == 993) | (sslData$id.orig_p==993),]$ssl_label<-"mail"
# sslData[(sslData$id.resp_p == 465) | (sslData$id.orig_p==465),]$ssl_label<-"mail"
# # secure mqtt -- todo lookup IP address and dns queries here
# sslData[((sslData$id.resp_p == 8883) | (sslData$id.orig_p==8883))
#         &(sslData$operating_system=="a"), ]$ssl_label<-"facebook_message"
# 
# print("Number of SSL Flows")
# nrow(sslData)
# print("Number of SSL Flows for which no label was found")
# nrow(sslData[sslData$ssl_label==unknownSslLabel,])
# tmp <- sslData[(sslData$ssl_label!=unknownSslLabel & sslData$session_id!="-"),]
# tmp <- tmp[!duplicated(tmp$session_id),]
# tmp <- data.frame(session_id=tmp$session_id, session_ssl_label=tmp$ssl_label, stringsAsFactors=FALSE)
# sslData <- merge(x=sslData, y=tmp, by="session_id", all.x=TRUE)
# sslData[is.na(sslData$session_ssl_label),]$session_ssl_label <- unknownSslLabel
# sslData[sslData$ssl_label==unknownSslLabel, ]$ssl_label <- sslData[sslData$ssl_label==unknownSslLabel, ]$session_ssl_label;
# sslData$session_ssl_label <- NULL
# 
# ### TODO:: All the code for other logs such as ssl and conn comes here. For the time being we just add stuff for conn.log
# ### for some tests.
# #fName <- paste(broLogsDir, "conn.log.info.ads", sep="");
# #connData <- readConnData(fName)
# #connData <- merge(x=connData, y=httpSigs, by="uid", all.x=TRUE)
# #connData[is.na(connData$app_label),]$app_label=unknownSslLabel
# #fName <- paste(fName, ".app", sep="")
# #print(fName)
# #write.table(connData, fName, sep="\t", quote=F, col.names=c(colnames(connData)), row.names=FALSE)
# 
# getSslSignatures <- function() { 
#   tmp <- sslData
#   # Find rows that have a valid subject with a session id
#   tmp <- sslData[(sslData$subject!="-" & sslData$session_id!="-"),]
#   # Now get the subject field in the rows that have a valid session id
#   tmp1 <- data.frame(session_id=tmp$session_id, session_subject=tmp$subject, stringsAsFactors=FALSE)
#   tmp <- sslData;
#   # Now merge the newly found subject with the rows that have the same session id
#   tmp <- merge(x=tmp, y=tmp1)
#   # Assign this subject to rows that do not have a valid subject field
#   tmp[(tmp$subject=="-") & (tmp$session_subject!="-"),]$subject = tmp[(tmp$subject=="-") & (tmp$session_subject!="-"),]$session_subject
#   # Remove the added column
#   tmp$session_subject<-NULL
#   sslSubjects <- unique(tmp$subject)
#   cnStrings <- sapply(sslSubjects, function(x) {
#     y<- regexpr("CN=.*?(\b|,|$)", x);
#     if (y != -1) {
#       # #+3 for CN=
#       signature<-unlist(strsplit(substring(x, y+3, y+attr(y, "match.length")-1), ","))
#     } else {            
#       signature <- unknownSslLabel
#     }
#     # Remove the preceding *.
#     #signature <- gsub("\\*\\.", "", signature)      
#     signature
#   }, USE.NAMES=FALSE)
#   x <- data.frame(subject=sslSubjects, ssl_label=cnStrings, stringsAsFactors=FALSE)
#   return(x);
# }
 

