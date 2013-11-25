# Issues with ODBC and R
### First get the arguments 
library(RMySQL)

# First read the command line arguments
cmdArgs <- commandArgs(trailingOnly=TRUE)
if (length(cmdArgs) < 4) {
  print (paste("Insufficient args in ", cmdArgs))
  print (paste("R -f AssignSignatures.R --args <meddle.config> <http.log> <startTime> <stopTime>", cmdArgs))
  quit(save="no")
}

# The first argument is meddleConfigName
meddleConfigName <- cmdArgs[1]
# while the second is the httpLogName
httpLogName <- cmdArgs[2]
startTime <- as.numeric(cmdArgs[3])
stopTime <- as.numeric(cmdArgs[4])

#### All the helper functions used by this script
# Get the credentials to contact the database server 
getDBConn <- function(meddleConfigName) {
  configData <- read.table(meddleConfigName, sep="=", header=FALSE, quote="\"",
                           col.names=c("variable", "value"), fill=FALSE, stringsAsFactors=FALSE,
                           comment.char="#")   
  dbName   <- configData[configData$variable=="dbName",]$value
  dbServer <- configData[configData$variable=="dbServer",]$value
  dbUser   <- configData[configData$variable=="dbUserName",]$value
  dbPasswd <- configData[configData$variable=="dbPassword",]$value  
  dbConn <- dbConnect(MySQL(), user=dbUser, password=dbPasswd, dbname=dbName, host=dbServer,
                      client.flag=CLIENT_MULTI_STATEMENTS)  
  dbSendQuery(dbConn, "SET NAMES 'utf8'");
  dbSendQuery(dbConn, "SET CHARACTER SET 'utf8'");
  return (dbConn)
}

# Read the UserAgentSignatures Table
# Assumption here is that the user agent table is small 
# There were less than 10k unique user agents in the two datasets 
# so the memory footprint should be small 
readUserAgentSignatureTable <- function(dbConn) {  
  dbSendQuery(dbConn, "SET NAMES 'utf8'");
  dbSendQuery(dbConn, "SET CHARACTER SET 'utf8'");  
  x <- dbSendQuery(dbConn, "SELECT * FROM UserAgentSignatures;");
  dbAgentSignatureTable <- fetch(x, n=-1);   
  #dbAgentSignatureTable <- dbReadTable(dbConn, "UserAgentSignatures")
  userAgentSignatureTable <- data.frame(agent_id = as.numeric(dbAgentSignatureTable$agentID), 
                                        app_id = as.numeric(dbAgentSignatureTable$appID), 
                                        user_agent = dbAgentSignatureTable$userAgent,
                                        agent_signature = dbAgentSignatureTable$agentSignature,
                                        stringsAsFactors = FALSE)                               
 return (userAgentSignatureTable)
}

readAppMetaDataTable <- function(dbConn) {  
  # Not using dbReadTable for UTF issues -- this seems to work
  dbSendQuery(dbConn, "SET NAMES 'utf8'");
  dbSendQuery(dbConn, "SET CHARACTER SET 'utf8'");    
  x <- dbSendQuery(dbConn, "SELECT * FROM AppMetaData;");
  dbAppDataTable <- fetch(x, n=-1);    
  appDataTable <- data.frame(app_id = as.numeric(dbAppDataTable$appID),
                             agent_signature = tolower(dbAppDataTable$appName),  
                             stringsAsFactors = FALSE)                               
  return (appDataTable)
}

readUserIpMap <- function(dbConn, startTime, stopTime) {
  # Get the last time the IP address was used to create the tunnel before the start time
  # This is done to ensure that we have the user ID if the tunnel was created before 
  # the current log file was created.  
  query <- paste("SELECT a.userID, UNIX_TIMESTAMP(a.timestamp) as timestamp, a.clientTunnelIpAddress from UserTunnelInfo a JOIN (select max(rowID) as maxRowID from UserTunnelInfo WHERE startStopFlag = 1 AND timeStamp < FROM_UNIXTIME(", startTime, ") GROUP BY clientTunnelIpAddress) b ON a.rowID = b.maxRowID;", sep="");  
  lastTimeTable <- dbGetQuery(dbConn, query);    
  print(query);
  
  # Now get the ids for flows created from the time the bro logs were created. 
  query <- paste("SELECT userID, UNIX_TIMESTAMP(timestamp) as timestamp, clientTunnelIpAddress from UserTunnelInfo WHERE startStopFlag = 1 AND timeStamp >= FROM_UNIXTIME(", startTime, ")  AND timeStamp <= FROM_UNIXTIME(", stopTime, ");", sep="");  
  print(query);
  UserIpMap <- dbGetQuery(dbConn, query)
  tmpIpMap <- rbind(lastTimeTable, UserIpMap)  
  UserIpMap <- data.frame(timestamp = tmpIpMap$timestamp, 
                          tunnel_ip = tmpIpMap$clientTunnelIpAddress, 
                          user_id = tmpIpMap$userID, 
                          stringsAsFactors=FALSE)  
  UserIpMap <- UserIpMap[order(UserIpMap$timestamp, decreasing=FALSE), ];  
  #print(UserIpMap)
  return (UserIpMap)
}

# Again assuming a small file
readHttpLogSignatureElems <- function(httpLogName) {
  # 5*6 + 1 = 31 columns
  colNames <- c("ts", "uid","orig_h", "orig_p", "resp_h", 
                "resp_p", "trans_depth", "method", "host", "uri", 
                "referrer", "user_agent", "request_body_len", "response_body_len", "status_code", 
                "status_msg", "info_code", "info_msg", "filename", "tags", 
                "username", "password", "proxied", "mime_type", "md5",
                "extraction_file", "content_length", "content_encoding", "content_type", "transfer_encoding", 
                "post_body")
  tmpHttpData <- read.table(httpLogName, header=FALSE, sep="\t", fill=TRUE, stringsAsFactors=FALSE, 
                         quote="", row.names=NULL, comment.char="#");  
  colnames(tmpHttpData) <- colNames
  httpData <- data.frame(ts=tmpHttpData$ts, uid=tmpHttpData$uid, 
                         orig_h=tmpHttpData$orig_h, resp_h=tmpHttpData$resp_h,
                         user_agent=tmpHttpData$user_agent, referrer=tmpHttpData$referrer, 
                         request_body_len=tmpHttpData$request_body_len, 
                         host = tmpHttpData$host,                         
                         uri = tmpHttpData$uri,
                         response_body_len=tmpHttpData$response_body_len,
                         stringsAsFactors=FALSE)
  httpData$ts <- as.numeric(httpData$ts)
  print(paste("The current bro logs has ", nrow(httpData), " rows"))
  httpData <- httpData[!duplicated(httpData[c("uid", "orig_h", "resp_h", "host")]), ];
  # REMOVE THE PREVIOUS LINE IS YOU NEED TO DO SOME SERIOUS PII ANALYSIS
  print(paste("The current bro logs has ", nrow(httpData), " unique rows - after removing pipeling"))
  return (httpData)
}

### Helper functions for assigning signatures
# * handle encoding
handleUserAgentEncoding <- function(signatureList) {  
  ret_val <- unlist(lapply(signatureList, function(x) { y <- URLdecode(x); y<-enc2utf8(y); return(y)}));
  return(ret_val)
}

# * Popular Signatures
assignPopularAppServiceSignatures <- function(signatureList) {
  signatureList[grepl("crios", signatureList, ignore.case=TRUE,perl=TRUE)] <- "googlechrome" #Note we remove ios later, hence chrome
  signatureList[grepl("firefox", signatureList, ignore.case=TRUE,perl=TRUE)] <- "firefox"; 
  
  #Services/apps
  signatureList[grepl("scorecenter", signatureList, ignore.case=TRUE,perl=TRUE)] <- "scorecenter";   
  signatureList[grepl("itunes-", signatureList, ignore.case=TRUE,perl=TRUE)] <- "itunes";
  signatureList[grepl("yelp", signatureList, ignore.case=TRUE,perl=TRUE)] <- "yelp";
  
  # Ad sites
  signatureList[grepl("admob", signatureList, ignore.case=TRUE,perl=TRUE)] <- "admob";
  signatureList[grepl("afma", signatureList,ignore.case=TRUE,perl=TRUE)] <- "afma";   
  
  signatureList[grepl("FBAN/", signatureList,ignore.case=TRUE,perl=TRUE)] <- "facebook";
  signatureList[grepl("weibo", signatureList, ignore.case=TRUE,perl=TRUE)] <- "weibo"; 
  #signatureList[grepl("renren", signatureList, ignore.case=TRUE,perl=TRUE)] <- "renren";
  
  #signatureList[grepl("Chrome", signatureList,ignore.case=TRUE,perl=TRUE)] <- "chrome";
  signatureList[grepl("stagefright", signatureList, ignore.case=TRUE,perl=TRUE)] <- "stagefright"  
  signatureList[grepl("miuibrowser", signatureList, ignore.case=TRUE,perl=TRUE)] <- "miuibrowser"  
  signatureList[grepl("miui", signatureList, ignore.case=TRUE,perl=TRUE)] <- "miui"    
  signatureList[grepl("lenovomagic", signatureList, ignore.case=TRUE,perl=TRUE)] <- "lenovomagic"
  
  signatureList[grepl("apple.*i.*stocks", signatureList, ignore.case=TRUE,perl=TRUE)] <- "applestocks"      
  signatureList[grepl("apple\\.maps", signatureList, ignore.case=TRUE,perl=TRUE)] <- "applemaps";
  signatureList[grepl("google\\.maps", signatureList, ignore.case=TRUE,perl=TRUE)] <- "googlemaps";
  
  signatureList[grepl("ip((od)|(hone)|(ad)).*cpu.*ip((od)|(hone)|(ad)).*version.*mobile.*safari", signatureList, ignore.case=TRUE,perl=TRUE)] <- "safari"      
  return (signatureList)  
}

removeDelimiters <- function(signatureList) {
  signatureList <-unlist(lapply(signatureList, function(x) unlist(strsplit(x, "/"))[1]))
  signatureList <-unlist(lapply(signatureList, function(x) unlist(strsplit(x, ";"))[1]))  
  signatureList <-unlist(lapply(signatureList, function(x) unlist(strsplit(x, ":"))[1]))  
  signatureList <-unlist(lapply(signatureList, function(x) unlist(strsplit(x, "="))[1]))  
}

# * remove parenthesis
removeStringBetweenParens <- function(signatureList) {
  signatureList<- gsub("\\([^)]*\\)", "", signatureList, perl=TRUE)    
  signatureList<- gsub("\\[[^]]*\\]", "", signatureList,perl=TRUE)
  return (signatureList)
}


# * get names from packages
extractPackageSignatures <- function(signatureList) { 
  signatureList <- unlist(lapply(signatureList, function(x) { y<-x;
                                                              z<-y;
                                                              #print(y)
                                                              if (grepl("(.*com.)|(.*org.)|([[:alnum:]]{5,}\\.[[:alnum:]]{3,})", y, perl=TRUE, ignore.case=TRUE)) {
                                                                y<- gsub("\\.ip(hone|ad|od)[[:alnum:]]*","",y, perl=TRUE)
                                                                y<- gsub("\\.android[[:alnum:]]*","",y, perl=TRUE)
                                                                y <- gsub("\\.([[:alpha:]]*[[:digit:]][[:alpha:]]*)", "", y, perl=TRUE)
                                                                y<- gsub("\\..*[[:digit:]].*","",y, perl=TRUE)
                                                                z <- unlist(strsplit(y, "\\."))
                                                                if (length(z)>0) {                                                                  
                                                                  y <- tail(z,1)                                                                       
                                                                }
                                                              }
                                                              #print(paste(x,y,z))
                                                              y;}))
  return(signatureList);
}


filterUnwantedSignatures <- function(signatureList) {
  signatureList <-gsub("([[:blank:]][[:alnum:]]+\\=([[:alnum:]]){0,}){0,}", "", signatureList, perl=TRUE)  
  signatureList <- gsub("(_|-){0,1}((ios)|(iphone)|(ipod)|(ipad)|(android)|(dalvik))([[:blank:]]|[[:punct:]]){0,1}(([[:digit:]]|[[:punct:]]){0,})( OS){0,1}(/{0,1}([[:alpha:]]{0,}[[:digit:]][[:graph:]]{0,})){0,}", "", signatureList, ignore.case=TRUE, perl=TRUE)  
  signatureList <- gsub("[[:blank:]]((v{0,1})|((rv){0,1}))[^\\x]([[:digit:]]+\\.{0,1})+[[:alnum:]]+\\b", "", signatureList, perl=TRUE)  
  return(signatureList)
}

extractMozillaSuffixSignature <- function(userAgentList, signatureList) {
  mozilla <- unlist(lapply(userAgentList, function(x) { y<-x;
                                                        z<-gsub("\\([^)]*\\)", "", y, perl=TRUE)
                                                        z<-gsub("((Mozilla)|(AppleWebKit)|(Version)|((Mobile ){0,1}Safari)|(Mobile)|(Chrome))/([[:graph:]]|(\\+))+", "", z, ignore.case=TRUE, perl=TRUE)
                                                        z<-gsub("(gzip)|(;)","", z, perl=TRUE, ignore.case=TRUE)
                                                        z<-gsub("[[:blank:]]{2,}","", z, perl=TRUE)
                                                        z;}));
  
  print("Got signatures from those that suffix the Mozilla signature ")
  mozilla <-unlist(lapply(mozilla, function(x) unlist(strsplit(x, "/"))[1]))
  mozilla[is.na(mozilla)]<-"mozilla"
  signatureList[is.na(signatureList)]<-userAgentList[is.na(signatureList)]
  signatureList[signatureList=="mozilla"] <- mozilla[signatureList=="mozilla"]
  return (signatureList);
}

performSignatureCleanup <- function (signatureList) {  
  signatureList <- gsub("(cfnetwork)|(dalvik)|(unused)|(user_agent)|(useragent)|(linux)|(apache-httpclient)|(iphone-version)", "", signatureList, perl=TRUE, ignore.case=TRUE)  
  signatureList <- gsub(" rv", "", signatureList, perl=TRUE)  
  signatureList <- gsub("([[:blank:]]|[[:punct:]]){2,}", "", signatureList, perl=TRUE)      
  signatureList <- gsub("[[:blank:]]([[:digit:]][[:punct:]]{0,1})+", "", signatureList, perl=TRUE)      
  signatureList <- gsub("[[:blank:]]", "", signatureList, perl=TRUE)  
  signatureList <- gsub("[[:blank:]]{0,}$", "", signatureList, perl=TRUE)
  signatureList <- gsub("ip((od)|(hone)|(ad))(([[:digit:]]{0,}[[:punct:]]{0,}){0,})$", "", signatureList, perl=TRUE)
  signatureList <- gsub("((android)|(ios)|(applewebkit))(([[:digit:]]{0,}[[:punct:]]{0,}){0,})$", "", signatureList, perl=TRUE)  
  # Cannot use punctuation here
  signatureList <- gsub("(-|_|\\.|;|!|'){0,}", "", signatureList, perl=TRUE)  
  # For hex encoded strings
  signatureList <- gsub("\\\\", "/", signatureList, perl=TRUE)  
  # For hexencoded strings Assuming / are not present in the signatures      
  signatureList[signatureList=="null"]<-"-";
  signatureList[signatureList==""] <- "-";  
  return(signatureList)
}


getAppSignatures <- function(userAgentList) {  
  userAgentList <- unique(userAgentList)
  signatureList <- tolower(userAgentList);    
  #print(signatureList)
  signatureList <- handleUserAgentEncoding(signatureList) 
  signatureList <- assignPopularAppServiceSignatures(signatureList)  
  signatureList <- removeStringBetweenParens(signatureList)
  signatureList <- removeDelimiters(signatureList)  
  signatureList <- extractMozillaSuffixSignature(tolower(userAgentList), signatureList)  
  signatureList <- extractPackageSignatures(signatureList);    
  signatureList <- performSignatureCleanup(signatureList);
  signatureTable <- data.frame(agent_signature=signatureList, user_agent=userAgentList,
                               stringsAsFactors=FALSE)
  return (signatureTable)
}


appendUserAgentTable <- function(dbConn, lastAgentId, signatureTable) {
  startAgentId <- lastAgentId + 1;
  print(paste("Assigning ", nrow(signatureTable), " IDs from ID", startAgentId, "for ", nrow(signatureTable)))  
  dbAgentTable <- data.frame(agentID = seq(startAgentId, (startAgentId+nrow(signatureTable)-1), 1),
                             appID = signatureTable$app_id,
                             userAgent = signatureTable$user_agent,                             
                             agentSignature=signatureTable$agent_signature)
  dbWriteTable(dbConn, "UserAgentSignatures", dbAgentTable, append=TRUE, row.names=FALSE);
  print("Writing new entries to database");
  return(TRUE);                             
}

handleNewUserAgents <- function(dbConn, newUserAgents, lastAgentID, appSigTable, appMetaData) {    
  newSignatureTable <- getAppSignatures(newUserAgents)  
  print(paste("Number of entries of table with new user agent", nrow(newSignatureTable)))  
  # Assign the apps based on the signatures -- previously obtained ones
  newSignatureTable <- merge(newSignatureTable, appSigTable, by="agent_signature", all.x=TRUE)        
  print(paste("Number of Rows after Merge", nrow(newSignatureTable)))  
  if (TRUE %in% is.na(newSignatureTable$app_id)) {
    # If the app id is not found then assign unknown
    newSignatureTable[is.na(newSignatureTable$app_id), ]$app_id <- 0;
  }  
  
  # Now Trying to match the application names with the user agent signatures if app ID is not found
  newApps <- data.frame(agent_signature=newSignatureTable[newSignatureTable$app_id == 0,]$agent_signature,
                        stringsAsFactors=FALSE);  
  newApps <- merge(newApps, appMetaData, by="agent_signature", all.x=TRUE)
  if (TRUE %in% is.na(newApps$app_id)) {
    # If the app id is not found then assign unknown
    newApps[is.na(newApps$app_id), ]$app_id <- 0;
  }  
  # Rename the column name to avoid problems during merge
  newApps$app_id_1 <- newApps$app_id;
  newApps$app_id <- NULL;
  newSignatureTable <- merge(newSignatureTable, newApps, by="agent_signature", all.x=TRUE)  
  newSignatureTable[newSignatureTable$app_id== 0,]$app_id <- newSignatureTable[newSignatureTable$app_id== 0,]$app_id_1
  newSignatureTable$app_id_1 <- NULL;  
  
  # Saving the results to DB
  newSignatureTable <- newSignatureTable[!duplicated(newSignatureTable[c("user_agent")]), ];
  print(paste("Dumping new signatures to DB", nrow(newSignatureTable)))
  appendUserAgentTable(dbConn, max(userAgentSignatureTable$agent_id), newSignatureTable);
}


### Assigning the labels to the flows
assignUserId <- function (httpData, UserIpMap) {
  CurrentIpMapTable <- data.frame(ip_address=unique(UserIpMap$tunnel_ip), user_id=rep(1, length(unique(UserIpMap$tunnel_ip))), stringsAsFactors=FALSE);  
  httpData$user_id <- -1;  
  j<-1;
  i<-1;
  ipAddresses <- c(unique(httpData$orig_h), unique(httpData$resp_h))
  UserIpMap <- UserIpMap[UserIpMap$tunnel_ip %in% ipAddresses, ]
  if (nrow(UserIpMap) < 1) {
    print("No IP addresses found in DB");
    return(httpData);
  }
  for(i in 1:nrow(httpData)) {        
    currTs <- httpData[i,]$ts    
    if (i %% 500 == 0) {
      print(paste("Done", i, "rows of http"))
    }
    while (UserIpMap[j, ]$timestamp < currTs ) {      
      # Update the Mapping Table
      # First invalidate the current entry if an entry exists
      if (UserIpMap[j,]$user_id %in% CurrentIpMapTable$user_id) {
        CurrentIpMapTable[CurrentIpMapTable$user_id == UserIpMap[j,]$user_id,]$user_id <- -1;
      }
      # Add the new ip for this user
      CurrentIpMapTable[CurrentIpMapTable$ip_address == UserIpMap[j,]$tunnel_ip, ]$user_id <- UserIpMap[j,]$user_id;
      j <- j+1;
      if (j %% 500 == 0) {
        print(paste("Done", j, "rows of ipmap"))
      }      
    }    
    orig_h <- httpData[i,]$orig_h
    resp_h <- httpData[i,]$resp_h
    if (orig_h %in% CurrentIpMapTable$ip_address) {
      httpData[i, ]$user_id <- CurrentIpMapTable[CurrentIpMapTable$ip_address==orig_h,]$user_id
    } else{
      if (resp_h %in% CurrentIpMapTable$ip_address) {
        httpData[i, ]$user_id <- CurrentIpMapTable[CurrentIpMapTable$ip_address==resp_h,]$user_id
      }
    }
  }
  print("Assigned Device Id");
  return (httpData)
}

getNewAgents <- function (logAgents, dbAgents) {
  # The Database screws up the hex encoded strings so we need to be carful
  dbAgents <- gsub("\\\\", "", dbAgents, perl=TRUE)  
  logAgents <- gsub("\\\\", "", dbAgents, perl=TRUE)
  return(setdiff(logAgents, dbAgents))
}


assignAgentSignature <- function(httpData, userAgentTable) {
  print(paste("Number of rows in http log", nrow(httpData), "before merge"));
  httpData <- merge(httpData, userAgentTable, by="user_agent", all.x=TRUE)  
  # This copies the appID and the agentID based on the user_agent
  print(paste("Number of rows in http log", nrow(httpData), "after merge"));
  # Handle unknowns if exists and also these agents in a log file  
  return (httpData)
}




assignTrackerFlag <- function(dbConn, httpData) {  
  # TODO:: Read from Database the list of trackers and assign a tracker based on httpData
  print("Assigning Tracker Flags")
  trackerTable <- dbReadTable(dbConn, "TrackerDomains"); 
  # Assuming that number of http flows are larger than the tracker rows~3k
  trackerRows <- unique(unlist(lapply(trackerTable$domain,  function(x) {grep(x, httpData$host)})))  
  httpData$tracker_flag <- FALSE;
  httpData[trackerRows, ]$tracker_flag <- TRUE;
  print("Completed Tracker Flags")
  return(httpData)  
}

assignPIIFlag <- function(dbConn, httpData) {  
  # TODO:: Read from Database the list of trackers and assign a tracker based on httpData
  httpData$pii_flag <- FALSE;
  return(httpData)  
}


appendDatabaseHttpData <- function (dbConn, httpData)  {  
  # The database schema is 
  # ts, bro_flowid, device_id, agent_id, remote_host, tracker_flag, pii_flag  
  print(colnames(httpData)) 
  dbData <- data.frame(ts = httpData$ts, broFlowID = httpData$uid, 
                       userID = httpData$user_id,                        
                       agentID = httpData$agent_id,                         
                       appID = httpData$app_id,
                       remoteHost = httpData$host, 
                       trackerFlag = httpData$tracker_flag,
                       piiFlag = httpData$pii_flag);
  print(paste("Number of rows in http log", nrow(dbData), "before removal of pipelining"));  
  # THIS REMOVAL IS REDUNDANT IF THE DUPLICATES ARE REMOVED WHILE READING THE FILE
  dbData <- dbData[!duplicated(dbData[c("broFlowID", "userID", "agentID", "remoteHost")]), ];
  print(paste("Number of rows in http log", nrow(dbData), "after removal of pipelining"));    
  dbWriteTable(dbConn, "HttpFlowData", dbData, append=TRUE, row.names=FALSE);   
}


readPackageDetails <- function(dbConn) {
  dbSendQuery(dbConn, "SET NAMES 'utf8'");
  dbSendQuery(dbConn, "SET CHARACTER SET 'utf8'");  
  x <- dbSendQuery(dbConn, "SELECT * from PackageDetails;");
  currPackageDetails <- fetch(x, n=-1)
  return(currPackageDetails)
}

readCDNMap <- function(dbConn) {
  dbSendQuery(dbConn, "SET NAMES 'utf8'");
  dbSendQuery(dbConn, "SET CHARACTER SET 'utf8'");  
  x <- dbSendQuery(dbConn, "SELECT * from CDNAppMap;");
  cdnMap <- fetch(x, n=-1)
  return(cdnMap)
}
  
assignHostSignature <- function(dbConn, httpData) { 
  packageDetails <- readPackageDetails(dbConn)  
  cdnMap <- readCDNMap(dbConn)
  appIdHostMap <- data.frame(host_app_id = packageDetails$appID,
                             host = packageDetails$pkgAppDomain,
                             stringsAsFactors=FALSE);
  httpData <- merge(httpData, appIdHostMap, by="host", all.x=TRUE)  
  print(paste("Searching for host in package names", (TRUE %in% is.na(httpData$host_app_id))));    
  if (TRUE %in% is.na(httpData$host_app_id)) {
    httpData[is.na(httpData$host_app_id),]$host_app_id <- 0;
  }
  httpData$cdn_app_id <- unlist(lapply(httpData$host, 
                                       function(x) {
                                           #print(x)
                                           for (i in 1:nrow(cdnMap)) {
                                             if (TRUE %in% grepl(cdnMap[i,]$cdnHostSignature, x, ignore.case=TRUE,perl=TRUE)) {
                                                return(cdnMap[i,]$appID)  
                                             }
                                           }                                         
                                           return(0);
                                         }))
  print(paste("Assigning Signatures based on package names", (TRUE %in% (httpData$app_id == 0))))
  if (TRUE %in% (httpData$app_id == 0)) {
    reqRows <- which(httpData$app_id == 0)
    reqData <- httpData[reqRows,]$host_app_id
    httpData[reqRows,]$app_id <- reqData ;
  }
  print(paste("Assigning Signatures based on cdn names", (TRUE %in% (httpData$app_id == 0))))
  if (TRUE %in% (httpData$app_id == 0)) {
    reqRows <- which(httpData$app_id == 0)
    reqData <- httpData[reqRows,]$cdn_app_id
    httpData[reqRows,]$app_id <- reqData;
  }
  httpData$host_app_id <- NULL
  httpData$cdn_app_id <- NULL
  return (httpData);
}

#meddleConfigName <- "/home/arao/proj-work/meddle/arao-meddle/meddle/code/SimplePacketFilter/PktFilterModule/meddle.config"
#httpLogName <- "/home/arao/tmp/http.log"

# First get the configuration 
dbConn <- getDBConn(meddleConfigName)
# Read the UserAgent and IP mapping tables present in the Database
userAgentSignatureTable <- readUserAgentSignatureTable(dbConn)
UserIpMap <- readUserIpMap (dbConn, startTime, stopTime);
AppMetaData <- readAppMetaDataTable(dbConn);
# Read the http log generated by bro
httpData <- readHttpLogSignatureElems(httpLogName)
# Get the signatures for the User Agents not present in DB and save them to DB
newUserAgents <- getNewAgents(unique(httpData$user_agent),unique(userAgentSignatureTable$user_agent))
if (length(newUserAgents) > 0) {
  print(newUserAgents)
  appSigTable <- data.frame(agent_signature=userAgentSignatureTable$agent_signature, app_id = userAgentSignatureTable$app_id)  
  appSigTable <- appSigTable[!duplicated(appSigTable[c("agent_signature", "app_id")]), ];    
  handleNewUserAgents(dbConn, newUserAgents, max(userAgentSignatureTable$agent_id), appSigTable, AppMetaData)  
  userAgentSignatureTable <- readUserAgentSignatureTable(dbConn)
} else {
  print(paste("All", length(unique(httpData$user_agent)), "user agents found in DB"))
}
# Assign the device ID to the flows. 
httpData <- assignUserId(httpData, UserIpMap)
httpData <- assignAgentSignature(httpData, userAgentSignatureTable)
httpData <- assignTrackerFlag(dbConn, httpData)
httpData <- assignPIIFlag(dbConn, httpData)
httpData <- assignHostSignature(dbConn, httpData)
# Save flow Logs
appendDatabaseHttpData(dbConn, httpData)
dbDisconnect(dbConn)
