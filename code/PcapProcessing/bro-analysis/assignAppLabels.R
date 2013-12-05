# This script is used to assign the signature and the label we can identify based on the user agent field. 
# This file only annotates the http.log.* file with the signature that we identify based on the user agent. 

baseDir<-"/user/arao/home/meddle_data/"
#baseDir<-"/user/arao/home/china_meddle_data/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="")
setwd(scriptsDir);
broLogsDir<-paste(baseDir, "/bro-aggregate-data/", sep="")

unknownAppLabel="-"

#library(RecordLinkage); # for string comparison this was required for edit distance (levensteinSim)

source(paste(scriptsDir, "readLogFiles.R", sep=""))

####### FIRST FOR IOS TRAFFIC 
assignIosAppSignatures <- function(iosHttpData) {  
  iosUserAgents <- unique(iosHttpData$user_agent)
  # Remove the text between parenthesis
  # First decode the URL encoded strings such as ABC%20%BYE
  iosSignatures <- iosUserAgents  
  iosSignatures <- sapply(iosSignatures, function(x) { y <- URLdecode(x); y<-enc2native(y); return(y)})
  unlist(lapply(iosSignatures, function(x) unlist(strsplit(x, "/"))[1]))
  iosSignatures<- gsub("\\([^)]*\\)", "", iosSignatures)  
  # Biggest exception of signature mapping is facebook so assign it a signature
  #iosSignatures[grepl("FBAN/FBIO", iosSignatures)] <- "facebook"
  iosSignatures[grepl("FBAN/", iosSignatures,ignore.case=TRUE)] <- "facebook"
  print("Assigned Facebook")
  # Also assign signatures for web browsers
  # First safari
  iosSignatures[grepl("version.*safari", iosSignatures, ignore.case=TRUE)] <- "safari"
  # Then chrome for ios
  iosSignatures[grepl("crios", iosSignatures, ignore.case=TRUE)] <- "chrome" #Note we remove ios later, hence chrome
  iosSignatures[grepl("firefox", iosSignatures, ignore.case=TRUE)] <- "firefox" 
  iosSignatures[grepl("scorecenter", iosSignatures, ignore.case=TRUE)] <- "scorecenter" 
  iosSignatures[grepl("weibo", iosSignatures, ignore.case=TRUE)] <- "weibo" 
  iosSignatures[grepl("itunes-", iosSignatures, ignore.case=TRUE)] <- "itunes"
  iosSignatures[grepl("admob", iosSignatures, ignore.case=TRUE)] <- "admob"
  iosSignatures[grepl("afma", iosSignatures,ignore.case=TRUE)] <- "afma"  
  iosSignatures[grepl("renren", iosSignatures, ignore.case=TRUE)] <- "renren"  
  print("Assigned Web browsers")
  # Now remove entries between square braces
  iosSignatures<- gsub("\\[[^]]*\\]", "", iosSignatures)
  # Now remove the / and _
  iosSignatures <-unlist(lapply(iosSignatures, function(x) unlist(strsplit(x, "/"))[1]))
  iosSignatures <-unlist(lapply(iosSignatures, function(x) unlist(strsplit(x, ";"))[1]))  
  iosSignatures <-unlist(lapply(iosSignatures, function(x) unlist(strsplit(x, ":"))[1]))  
  #iosSignatures <-unlist(lapply(iosSignatures, function(x) unlist(strsplit(x, "_"))[1]))  
  # Replace Apple Store with AppleStore 
  iosSignatures <- gsub("Apple ", "Apple", iosSignatures, ignore.case=TRUE)
  print("Got application name from first element")
  # Remove version information  
  #iosSignatures <- gsub("(_|-){0,1}((ios)|(iphone)|(ipod)|(ipad)|(android)|(dalvik))( OS){0,1}(/){0,1}", "", iosSignatures, ignore.case=TRUE)    
  #iosSignatures <- gsub("(_|-){0,1}((ios)|(iphone)|(ipod)|(ipad)|(android)|(dalvik))([0-9,.]*)( OS){0,1}(/([a-zA-Z]*[0-9][a-zA-Z0-9.;/]*)){0,1}", "", iosSignatures, ignore.case=TRUE)    
  iosSignatures <- gsub("(_|-){0,1}((ios)|(iphone)|(ipod)|(ipad)|(android)|(dalvik))( |_){0,1}([0-9,.]{0,})( OS){0,1}(/{0,1}([a-zA-Z]{0,}[0-9][a-zA-Z0-9,.;]{0,})){0,}", "", iosSignatures, ignore.case=TRUE)
  
  iosSignatures <- gsub("\\b((v{0,1})|((rv){0,1}))[^\\x]([0-9]+\\.{0,1})+[A-Za-z0-9]+\\b", "", iosSignatures)
  iosSignatures <-gsub("(\\b[a-zA-Z0-9]+\\=([a-zA-Z0-9]){0,}){0,}", "", iosSignatures)
  # Remove ios, ipad, ipod, iphone and all this information
  
  # For all .com.xxx.yyy.zzz. select the last entry after split 
  # For all abcd.com.facebook.Facebook and .com.google.Maps, select the last entry after splitting with .  
  iosMozilla <- unlist(lapply(iosUserAgents, function(x) { y<-x;
                                                           z<-gsub("\\([^)]*\\)", "", y)
                                                           z<-gsub("((Mozilla)|(AppleWebKit)|(Version)|((Mobile ){0,1}Safari)|(Mobile)|(Chrome))/[a-zA-Z0-9.\\+]+", "", z, ignore.case=TRUE)                                                           
                                                           z<-gsub("(gzip)|(;)","", z)
                                                           z<-gsub(" {2,}","", z)
                                                           z;}))
  print("Got signatures from those that suffix the Mozilla signature ")
  iosMozilla <-unlist(lapply(iosMozilla, function(x) unlist(strsplit(x, "/"))[1]))
  iosMozilla[is.na(iosMozilla)]<-"Mozilla"
  iosSignatures[is.na(iosSignatures)]<-iosUserAgents[is.na(iosSignatures)]
  iosSignatures[iosSignatures=="Mozilla"] <- iosMozilla[iosSignatures=="Mozilla"]
  
  iosSignatures <- unlist(lapply(iosSignatures, function(x) { y<-x
                                                              z<-y
                                                              #print(y)
                                                              if (grepl("(.*com.)|(.*org.)", y)) {
                                                                z <- unlist(strsplit(y, "\\."))
                                                                if (length(z)>0) {
                                                                  y <- tail(z,1)                                                                       
                                                                }
                                                              }
                                                              #print(paste(x,y,z))
                                                              y;}))  
  print("Handled app names such as app.google.ios.*")    
  # Finally cleanup and remove multiple spaces
  iosSignatures <- gsub(" {2,}", "", iosSignatures)
  iosSignatures <- gsub("-{2,}", "-", iosSignatures)
  iosSignatureTable <- data.frame(user_agent_signature=iosSignatures, user_agent=iosUserAgents,
                                  stringsAsFactors=FALSE)
  iosHttpData <- merge(iosHttpData, iosSignatureTable, by="user_agent")
  print("Merged table")
  return(iosHttpData)
}

assignAndroidAppSignatures <- function(androidHttpData) {
  androidUserAgents <- unique(androidHttpData$user_agent)  
  # majority of signatures match this -- like iOS
  androidSignatures <- androidUserAgents;
  androidSignatures <- sapply(androidSignatures, function(x) { y <- URLdecode(x); y<-enc2native(y); return(y)})
  #androidSignatures[grepl("FBAN/FB4A", androidUserAgents,ignore.case=TRUE)] <- "facebook"
  androidSignatures[grepl("FBAN/", androidSignatures,ignore.case=TRUE)] <- "facebook"
  androidSignatures[grepl("Chrome", androidSignatures,ignore.case=TRUE)] <- "chrome"
  androidSignatures[grepl("firefox", androidSignatures, ignore.case=TRUE)] <- "firefox"   
  androidSignatures[grepl("weibo", androidSignatures,ignore.case=TRUE)] <- "weibo"  
  androidSignatures[grepl("afma", androidSignatures,ignore.case=TRUE)] <- "afma"
  androidSignatures[grepl("itunes", androidSignatures, ignore.case=TRUE)] <- "itunes"
  androidSignatures[grepl("renren", androidSignatures, ignore.case=TRUE)] <- "renren"
  androidSignatures[grepl("admob", androidSignatures, ignore.case=TRUE)] <- "admob"  
  androidSignatures[grepl("stagefright", androidSignatures, ignore.case=TRUE)] <- "stagefright"
  #androidSignatures[grepl("version.*safari", androidSignatures, ignore.case=TRUE)] <- "safari" 
  #xiaomi
  androidSignatures[grepl("miuibrowser", androidSignatures, ignore.case=TRUE)] <- "miuibrowser"  
  androidSignatures[grepl("miui", androidSignatures, ignore.case=TRUE)] <- "miui"  
  #lenovo
  androidSignatures[grepl("lenovomagic", androidSignatures, ignore.case=TRUE)] <- "lenovomagic"
  print("assigned facebook chrome and afma")
  #androidSignatures <-unlist(lapply(androidSignatures, function(x) unlist(strsplit(x, " "))[1]))
  # Remove the text between parenthesis
  androidSignatures<- gsub("\\([^)]*\\)", "", androidSignatures)
  # TODO CHECK SIGNATURE FOR IOS
  androidSignatures <- gsub("(_|-){0,1}((ios)|(iphone)|(ipod)|(ipad)|(android)|(dalvik))( |_){0,1}([0-9,.]{0,})( OS){0,1}(/{0,1}([a-zA-Z]{0,}[0-9][a-zA-Z0-9,.;]{0,})){0,}", "", androidSignatures, ignore.case=TRUE)
  
  print("removed strings between parenthesis")
  androidSignatures <-unlist(lapply(androidSignatures, function(x) unlist(strsplit(x, "/"))[1]))
  androidSignatures <-unlist(lapply(androidSignatures, function(x) unlist(strsplit(x, ";"))[1]))
  #androidSignatures <-unlist(lapply(androidSignatures, function(x) unlist(strsplit(x, " "))[1]))
  #androidSignatures <-unlist(lapply(androidSignatures, function(x) unlist(strsplit(x, ";"))[1]))
  print("Used first element for signatures")  
  androidMozilla <- unlist(lapply(androidUserAgents, function(x) { y<-x
                                                                   z<-gsub("\\([^)]*\\)", "", y)
                                                                   z<-gsub("((Mozilla)|(AppleWebKit)|(Version)|((Mobile ){0,1}Safari)|(Mobile)|(Chrome))/[a-zA-Z0-9.\\+]+", "", z, ignore.case=TRUE)
                                                                   z<-gsub("(gzip)|(;)","", z)
                                                                   z<-gsub(" {2,}","", z)
                                                                   z;}))
  print("Got signatures from those that suffix the Mozilla signature ")
  androidMozilla <-unlist(lapply(androidMozilla, function(x) unlist(strsplit(x, "/"))[1]))
  androidMozilla[is.na(androidMozilla)]<-"Mozilla"
  androidSignatures[is.na(androidSignatures)]<-androidUserAgents[is.na(androidSignatures)]
  androidSignatures[androidSignatures=="Mozilla"] <- androidMozilla[androidSignatures=="Mozilla"]
  
  androidSignatures <- unlist(lapply(androidSignatures, function(x) { y<-x
                                                                      z<-y
                                                                      #print(y)
                                                                      if (grepl("(.*com.)|(.*org.)|(*.androidapp)", y)) {
                                                                        z <- unlist(strsplit(y, "\\."))
                                                                        if (length(z)>0) {
                                                                          y <- tail(z,1)                                                                       
                                                                        }
                                                                      }
                                                                      #print(paste(x,y,z))
                                                                      y;}))
  print("Found details from *.com.facebook.FACEBOOK type of signatures")
  
  
  print("Cleanup")
  androidSignatures <- gsub(" {2,}", "", androidSignatures)
  androidSignatureTable <- data.frame(user_agent_signature=androidSignatures, user_agent=androidUserAgents,
                                      stringsAsFactors=FALSE)
  androidHttpData <- merge(androidHttpData, androidSignatureTable, by="user_agent")
  #print("Merged")
  return(androidHttpData)
}

getWebServiceForHost <- function (host) { 
    strTokens <- unlist(strsplit(host, "\\."))
    if (length(intersect(c("netflix", "nflix", "nflximg", "nflx", "nflxvideo"), strTokens)) > 0) {
      return("netflix")
    } 
    if (length(grep("netflix",host))>0 | (length(grep("198\\.189",host))>0) | (length(grep("108\\.175",host))>0)) {
      return("netflix")
    }
    if (length(intersect(c("fbcdn", "facebook"), strTokens)) > 0) {
      return("facebook")
    } 
    if (length(intersect(c("youtube", "ytube"), strTokens)) > 0) {
      return("youtube")
    }
    if (length(intersect(c("pandora", "p-cdn"), strTokens)) > 0) {
      return("pandora")
    }
    if (length(intersect(c("vk"), strTokens)) > 0) {
      return("vk")
    }  
    if (length(intersect(c("twitter"), strTokens)) > 0) {
      return("twitter")
    }
    if (length(intersect(c("publicradio"), strTokens)) > 0) {
      return("publicradio")
    }
    if (length(intersect(c("npr"), strTokens)) > 0) {
      return("npr")
    }
    if (length(intersect(c("podcast"), strTokens)) > 0) {
      return("podcast")
    }
    # Note www.google. something is mainly for Google websearch
    if (length(grep("www.google.", host)) > 0) {
      return("GoogleSearch")
    }    
    return("-")  
}

fName <- paste(broLogsDir, "http.log.info", sep="");
httpData <- readHttpData(fName)

# First assign ios Signatures
iosHttpData <- httpData[httpData$operating_system=="i",]
iosHttpData <- assignIosAppSignatures(iosHttpData)
# Then Android Signatures
androidHttpData <- httpData[httpData$operating_system!="i",]
androidHttpData <- assignAndroidAppSignatures(androidHttpData)
#### Now merge the tables
httpData <- rbind(iosHttpData, androidHttpData)

httpHosts <- unique(httpData$host)
webServiceSignature <- unlist(lapply(httpHosts, getWebServiceForHost))
webserviceTable <- data.frame(host=httpHosts, web_service_signature=webServiceSignature,
                              stringsAsFactors=FALSE)
print("Identified popular web service signatures, now merging table")
httpData <- merge(httpData, webserviceTable, by="host")
fName <- paste(fName, ".app", sep="");
print(fName)
write.table(httpData, fName, sep="\t", quote=F, col.names=c(colnames(httpData)), row.names=FALSE)
x<- data.frame(user_agent=httpData$user_agent, signature=httpData$user_agent_signature, stringsAsFactors=FALSE)
x<- x[!duplicated(x),]
x<-x[order(x$signature),]
write.table(x, paste(broLogsDir, "debug.http.signatures", sep=""), sep="\t", 
            quote=F, col.names=c(colnames(x)), row.names=FALSE, fileEncoding="utf-8")

### For debug

x <- unique(httpData$user_agent_signature)
length(x)
unique(httpData[httpData$user_agent_signature=="pro",]$user_agent)
unique(httpData[httpData$user_agent_signature=="ZTE",]$operating_system)


# NOT NEEDED FOR NOW
# The rest that has been detected mozilla we can keep as is.
#iosMozillaSignatures <- unlist(lapply(iosUserAgents, function(x) { #print(x);
#                                                                   y<- unlist(strsplit(x, " "))
#                                                                   #print(y)
#                                                                   #print(length(y))
#                                                                   if (length(y)>0) {
#                                                                     y <- tail(y,1)                                                                     
#                                                                     if (grepl("(mobile)|(darwin)|(os)|(safari)", y, ignore.case=TRUE)) {
#                                                                        y<-"mozilla";
#                                                                     }
#                                                                     if (grepl("/", y, ignore.case=TRUE) == FALSE) {
#                                                                       y<-"mozilla";
#                                                                     }
#                                                                   }
#                                                                   y;}))
#iosMozillaSignatures <-unlist(lapply(iosMozillaSignatures, function(x) unlist(strsplit(x, "/"))[1]))
#iosMozillaSignatures <-unlist(lapply(iosMozillaSignatures, function(x) unlist(strsplit(x, "_"))[1]))
#iosSignatures[grepl("mozilla", iosSignatures, ignore.case=TRUE)] <- iosMozillaSignatures[grepl("mozilla", iosSignatures, ignore.case=TRUE)]

# Now for signatures such as "Apple iPhone v6.0.1 Stocks v3.0.10A523"
# Ignore this for now
#iosAppleSignatures <-unlist(lapply(iosUserAgents, function(x) { y<- unlist(strsplit(x, " "))
#                                                                if (length(y)>0) {
#                                                                  if(length(y)>4) {
#                                                                    if (y[1] == "Apple") {                                                                    
#                                                                     y <- y[4]
#                                                                   }
#                                                                  } else {
#                                                                    y <- y[1]
#                                                                  }
#                                                                }
#                                                                y;}))
#iosSignatures[grepl("apple", iosSignatures, ignore.case=TRUE)] <- iosAppleSignatures[grepl("apple", iosSignatures, ignore.case=TRUE)]
# This function is not very useful for final processing but was used to get insights on the 
# building blocks and what elements to stip while clustering the user agents. 









############# OLD CODE COMES HERE
# getUserAgentElems <- function (uniqueUserAgents) {  
#   #allUserAgents <- paste(httpData$user_agent, collapse=" ")
#   #allUserAgents <- gsub("  +", " ", allUserAgents)
#   # Collapse all the unique entries in the user_agent column and split 
#   # based on the delimiters: ' ' or '/' or ';' or ','
#   elemsUserAgents <- tolower(unlist(strsplit(paste(uniqueUserAgents, collapse=" "), " |/|;|,|%|@|-|:|=|\\*|\\+|_")))
#   # Remove the parenthesis -- this is important to allow the use of gsub
#   elemsUserAgents<- gsub("\\(|\\)|\\[|\\]|\\{|\\}", "", elemsUserAgents)
#   # Now remove the digits
#   elemsUserAgents<- gsub("\\d", "", elemsUserAgents)
#   # Remove dots
#   elemsUserAgents<- gsub("\\.", "", elemsUserAgents)
#   # Now remove the spaces if any
#   elemsUserAgents<- gsub(" ", "", elemsUserAgents)
#   # Now remove strings that has only digits with a dot
#   # Now remove 
#   uniqueElems <- unique(elemsUserAgents)
#   # Remove all entries that have a length less than 2
#   elemString <- unique(unlist(lapply(uniqueElems, function(x) if (nchar(x) > 2) x else NULL)))
#   # Count how many times each of this elemen appears in the set of user_agents 
#   count <- unlist(lapply(elemString, function(x) length(grep(x, uniqueUserAgents, ignore.case=TRUE))))
#   elemsTable <- data.frame(elemString, count)  
#   elemsTable<-elemsTable[order(elemsTable$count, decreasing=TRUE),]
#   elemsTable
# }
# 
# # Returns the identifiers for the entries in user_agent_list
# getUserAgentSignature <- function (uniqueUserAgents) {  
#   identifiers <- uniqueUserAgents
#   identifiers<- gsub("\\(|\\)|\\[|\\]|\\{|\\}", " ", identifiers)
#   # Remove the digits -- version related information note \b is for boundary
#   identifiers<- gsub("\\b\\d", " ", identifiers)
#   # Remove localestrings
#   identifiers<- gsub("\\b(en(.{0,1})us)|(en(.{0,1})gb)|(fr(.{0,1})fr)|(ko(.{0,1})kr)\\b", " ", identifiers, ignore.case=TRUE)
#   # Remove the delimiters
#   identifiers <- gsub("/|;|,|%|@|\\$|-|:|=|\\*|\\+|_|\'|\"", " ", identifiers)
#   # Remove single characters and replace them with a space!
#   identifiers <- gsub("\\.", " ", identifiers)
#   # Remove OS specific Information (Get this list by manually inspecting the userAgentElems)
#   #\b(i(phone|pad|pod|os)(touch){0,1}(\d\w{0,2}){0,1})\b for iDevices
#   identifiers <- gsub("\\b(i(phone|pad|pod|os)(touch|os|unknown){0,1}(\\d\\w{0,2}){0,1})\\b", " ", identifiers, ignore.case=TRUE)
#   # Remove Android and remaining OS signatures
#   identifiers <- gsub("\\b(apple|android|androidapp|dalvik|darwin|cfnetwork|linux|os)\\b", " ", identifiers, ignore.case=TRUE)
#   # Remove build manufacturer specific Information (Get this list by manually inspecting the userAgentElems)
#   identifiers <- gsub("\\b(build|device|htc|mac|intel|galaxy|nexus|samsung|gsmart|gigabyte|sony)\\b", " ", identifiers, ignore.case=TRUE)
#   identifiers <- gsub("\\b(soju|crespo|maguro|mako|presto|(ice(\ b{0,1})cream(\ {0,1})sandwich)|takju|st15i|(sony(\\w*)))\\b", " ", identifiers, ignore.case=TRUE)
#   #  Remove popular sdk specific info 
#   # afma - adsence for mobile apps
#   # identifiers <- gsub("\\b(afma)\\b", " ", identifiers, ignore.case=TRUE)
#   # Remove carrier specific information .. problem with free and simple mobile
#   identifiers <- gsub("\\b((t-mob(\\w*))|(at&t)|(simple\ mobile)|orange|free|verizon)\\b", " ", identifiers, ignore.case=TRUE)
#   # Remove browser engine specific information
#   identifiers <- gsub("\\b(gecko|webkit|applewebkit|khtml|like|sdk|trident|androidsdk)\\b", " ", identifiers, ignore.case=TRUE)
#   # Remover browser specific information -- We use browser as default!
#   identifiers <- gsub("\\b(mozilla|safari|chrome|compatible|msie|win32|macintosh|windows)\\b", " ", identifiers, ignore.case=TRUE)
#   # Remove misc strings
#   identifiers <- gsub("\\b(app|unknown|unused|unavailable|none|empty|client|type|default|httpclient|http|carrier|com|cpu|gzip|sdk|\\w\\d+)\\b", " ", identifiers, ignore.case=TRUE)
#   identifiers <- gsub("\\b(java|full|on|kml|used|offline|rarely|null|api|apps|pro|org|lang|httpclient|http|net|generic|inapp|flg|carrier|com|cpu|gzip|sdk|portal|\\w\\d+)\\b", " ", identifiers, ignore.case=TRUE)
#   identifiers <- gsub("\\b(gsm|release|version|phone|tablet|touch|model|mobile|screen|osbuild|scale|density|height|width|size|agent|dpi)\\b", " ", identifiers, ignore.case=TRUE)
#   # Remove version strings like vxxx or exxxx 
#   identifiers <- gsub("\\b(\\w|\\d)\\b", " ", identifiers)
#   # Remove strings with one or two characters
#   identifiers <- gsub("\\b\\w{1,2}\\b", " ", identifiers)
#   # This one is tricky UPPERCASE CHARACTERS WITH NUMBERS -- used for build Note this must not remove FBAN and other such strings
#   identifiers<- gsub("\\b((([A-Z]|[0-9])*)([0-9]+)([A-Z]*)+)\\b"," ", identifiers, ignore.case=FALSE)
#   # Remove multiple spaces
#   identifiers <- gsub(" {2,}", " ", identifiers)
#   # Remove trailing and starting spaces
#   identifiers <- gsub("(\ $)|(^\ )", "", identifiers)
#   
#   # Sort each identifier based on string tokens,
#   # This step is done for LCS matching
#   identifiers <- sapply(identifiers, function(x) paste(sort(unlist(strsplit(x, " "))), collapse=" "))
#   # Massage variable names for the table
#   signature <- identifiers
#   #retFrame <- data.frame(user_agent, user_agent_signature=signature,stringsAsFactors=FALSE)  
#   signature  
# }
# A very crude way of finding the length of the LCS.
# I was not able to find some library that does this efficiently using suffix trees.
# longestCommonSubstringLen <- function(str1, str2) {
#   if (nchar(str1) == 0 || nchar(str2) == 0) {
#     return(0)
#   } 
#   s1 <- unlist(strsplit(str1,split="")) 
#   s2 <- unlist(strsplit(str2,split=""))
#   num <- matrix(0,nchar(str1),nchar(str2) )  
#   maxlen <- 0
#   for (i in 1:nchar(str1)) {
#     for (j in 1:nchar(str2)) {
#       if (s1[i] == s2[j]) {
#         if ((i==1) || (j==1)) {
#           num[i,j] <- 1
#         } else {
#           num[i,j] <- 1+num[i-1,j-1]
#         }
#         if (num[i,j] > maxlen) {
#           maxlen <- num[i,j]
#         }
#       }
#     }
#   } 
#   maxlen
# }
# 
# getSimilarityMatrix<- function (uniqueSigs) {    
#   matrixDim <- length(uniqueSigs)
#   simMatrix <- matrix (0, nrow=matrixDim, ncol=matrixDim)
#   uniqueSigs <-tolower(uniqueSigs)
#   i<-1; 
#   j<-1;
#   for (i in 1:matrixDim) {
#     print(i)
#     j<-i;
#     simMatrix[i,j] <- 1;    
#     if (i+1 > matrixDim) {
#       break;
#     }    
#     s1 <- uniqueSigs[i];
#     tokens1 <- unique(unlist(strsplit(s1, " ")))
#     for (j in (i+1):matrixDim) { 
#       s2 <- uniqueSigs[j];
#       tokens2 <- unique(unlist(strsplit(s2, " ")))
#       lmin <- min(nchar(s1), nchar(s2)); #we use min to get best case
#       tokenlmin <- min(length(tokens1), length(tokens2));
#       lcsLen <- longestCommonSubstringLen(s1, s2)
#       simMatrix[i,j] <- max(lcsLen/lmin, length(intersect(tokens2, tokens1))/tokenlmin)
#       simMatrix[j,i] <- simMatrix[i,j];
#     }
#   }   
#   simMatrix[is.na(simMatrix)] <- 0
#   simMatrix
# }
# 
# getTopSimilarityValues <- function(simMatrix, count) {
#   topSims <- matrix(0, nrow=nrow(simMatrix), ncol=count+1) 
#   i<-1
#   for (i in 1:nrow(simMatrix)) {
#     x <- simMatrix[i,]
#     x<-sort(x, decreasing=TRUE)
#     topSims[i, ] <- c(sum(x[1:count]), x[1:count])
#   }
#   topSims
# }
# 
# assignLabelsToSignatures <- function(uniqueSigs, simMatrix, threshold, defaultLabel) {
#   matrixDim <- length(uniqueSigs)
#   labelVector <- matrix (defaultLabel, nrow=matrixDim, ncol=1)
#   i<-1
#   for (i in 1:matrixDim) {
#     if (labelVector[i] == defaultLabel) {
#       labelVector[i] <- paste(unique(unlist(strsplit(tolower(uniqueSigs[i]), " "))), collapse=" ") 
#       if (i+1 > matrixDim) {
#         break;
#       }
#       for (j in (i+1):matrixDim) {
#         if (simMatrix[i,j] > threshold) {
#           labelVector[j] <- labelVector[i]
#         }
#       }
#     }
#   }  
#   labelVector
# }
# 
# # Note there might be overlap but fine
# getWebServiceForHost <- function (host) { 
#   strTokens <- unlist(strsplit(host, "\\."))
#   if (length(intersect(c("netflix", "nflix", "nflximg", "nflx", "nflxvideo"), strTokens)) > 0) {
#     return("netflix")
#   } 
#   if (length(grep("netflix",host))>0 | (length(grep("198\\.189",host))>0) | (length(grep("108\\.175",host))>0)) {
#     return("netflix")
#   }
#   if (length(intersect(c("fbcdn", "facebook"), strTokens)) > 0) {
#     return("facebook")
#   } 
#   if (length(intersect(c("youtube"), strTokens)) > 0) {
#     return("youtube")
#   }
#   if (length(intersect(c("pandora", "p-cdn"), strTokens)) > 0) {
#     return("pandora")
#   }
#   if (length(intersect(c("vk"), strTokens)) > 0) {
#     return("vk")
#   }  
#   if (length(intersect(c("twitter"), strTokens)) > 0) {
#     return("twitter")
#   }
#   if (length(intersect(c("publicradio"), strTokens)) > 0) {
#     return("publicradio")
#   }
#   if (length(intersect(c("publicradio"), strTokens)) > 0) {
#     return("publicradio")
#   }
#   if (length(intersect(c("npr"), strTokens)) > 0) {
#     return("npr")
#   }
#   if (length(intersect(c("podcast"), strTokens)) > 0) {
#     return("podcast")
#   }
#   # Note www.google. something is mainly for Google websearch
#   if (length(grep("www.google.", host)) > 0) {
#     return("GoogleSearch")
#   }    
#   return("-")  
# }
# 
# assignWebServiceToHosts <- function(hostList) {
#   webserviceName <- unlist(lapply(hostList, getWebServiceForHost))
#   return(data.frame(host=hostList, webservice=webserviceName,stringsAsFactors=FALSE))
# }
# 
# #userAgentElems <- getUserAgentElems(uniqueUserAgents)
# 
# assignHttpSignature <- function(fName) {
#   #global unknownAppLabel 
#   httpData <- readHttpData(fName)
#   unique_user_agent = unique(httpData$user_agent)
#   user_agent_signature <- getUserAgentSignature(unique_user_agent)  
#   unique_signatures <- sort(unique(user_agent_signature))
#   # The similarities between 'n' signatures in a nxn matrix. The similarity is measured from 0 to 1
#   # where 1 is identical and 0 implies least similarity
#   simMatrix <- getSimilarityMatrix(unique_signatures)
#   # All user_agent_signatures that have a similarity value above 0.75 grouped under a given label/tag
#   app_label <- assignLabelsToSignatures(unique_signatures, simMatrix, 0.75, unknownAppLabel)
#   # The signature table contains two columns, signature and the app_label
#   signatureTable <- data.frame(user_agent_signature=unique_signatures, app_label=app_label, stringsAsFactors=FALSE)
#   # UserAgenttable contains two columns :the user_agent and the user_agent_signature
#   userAgentTable <- data.frame(user_agent=unique_user_agent, user_agent_signature=user_agent_signature)
#   # We now assign the app_label to the list of unique user_agent 
#   userAgentSignatureLabels <- merge(x=userAgentTable, y=signatureTable, by="user_agent_signature")
#   # Assign an app_label of "unknown" to ones having an empty user_agent_signature
#   userAgentSignatureLabels[userAgentSignatureLabels$user_agent_signature=="",]$app_label=unknownAppLabel
#   # Now merge the httpData based on user_agent. This ensures that the appropriate signature and app_label is 
#   # assigned to the flows. 
#   httpDataLabeled <- merge(x=httpData, y=userAgentSignatureLabels, by="user_agent")  
#   print("Performing the merge")
#   userAgentSignatureLabels[userAgentSignatureLabels$user_agent_signature=="",]$app_label=unknownAppLabel
#   print("Assigning popular service signatures for other flows")     
#   webServiceName <- assignWebServiceToHosts(unique(httpDataLabeled$host))   
#   httpDataLabeled <- merge(x=httpDataLabeled, y=webServiceName, by="host")
#   return (httpDataLabeled)
# }
# 
# #fName <- paste(broLogsDir, "http.log.info.ads", sep="");
# fName <- paste(broLogsDir, "http.log.info", sep="");
# httpData <- assignHttpSignature(fName)
# fName <- paste(fName, ".app", sep="")
# print(fName)
# write.table(httpData, fName, sep="\t", quote=F, col.names=c(colnames(httpData)), row.names=FALSE)
# httpSigs <- data.frame(uid=httpData$uid, app_label=httpData$app_label, stringsAsFactors=FALSE)
# rm(httpData) # Free the memory for connData
