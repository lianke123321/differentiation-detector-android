# This script is used to assign the signature and the label we can identify based on the user agent field. 
# This file only annotates the http.log.* file with the signature that we identify based on the user agent. 

baseDir<-"/user/arao/home/proj-work/meddle/"
scriptsDir<-"/home/arao/proj-work/meddle/arao-meddle/meddle/code/PcapProcessing/bro-analysis/gen-analysis-logs/"
setwd(scriptsDir);
#broLogsDir<-paste(baseDir, "bro-results/", sep="");
broLogsDir<-"/user/arao/home/proj-work/meddle/projects/app-identification/bro-results/"

unknownAppLabel="unknown"

#library(RecordLinkage); # for string comparison this was required for edit distance (levensteinSim)

source(paste(scriptsDir, "readLogFiles.R", sep=""))

# This function is not very useful for final processing but was used to get insights on the 
# building blocks and what elements to stip while clustering the user agents. 
getUserAgentElems <- function (uniqueUserAgents) {  
  #allUserAgents <- paste(httpData$user_agent, collapse=" ")
  #allUserAgents <- gsub("  +", " ", allUserAgents)
  # Collapse all the unique entries in the user_agent column and split 
  # based on the delimiters: ' ' or '/' or ';' or ','
  elemsUserAgents <- tolower(unlist(strsplit(paste(uniqueUserAgents, collapse=" "), " |/|;|,|%|@|-|:|=|\\*|\\+|_")))
  # Remove the parenthesis -- this is important to allow the use of gsub
  elemsUserAgents<- gsub("\\(|\\)|\\[|\\]|\\{|\\}", "", elemsUserAgents)
  # Now remove the digits
  elemsUserAgents<- gsub("\\d", "", elemsUserAgents)
  # Remove dots
  elemsUserAgents<- gsub("\\.", "", elemsUserAgents)
  # Now remove the spaces if any
  elemsUserAgents<- gsub(" ", "", elemsUserAgents)
  # Now remove strings that has only digits with a dot
  # Now remove 
  uniqueElems <- unique(elemsUserAgents)
  # Remove all entries that have a length less than 2
  elemString <- unique(unlist(lapply(uniqueElems, function(x) if (nchar(x) > 2) x else NULL)))
  # Count how many times each of this elemen appears in the set of user_agents 
  count <- unlist(lapply(elemString, function(x) length(grep(x, uniqueUserAgents, ignore.case=TRUE))))
  elemsTable <- data.frame(elemString, count)  
  elemsTable<-elemsTable[order(elemsTable$count, decreasing=TRUE),]
  elemsTable
}

# Returns the identifiers for the entries in user_agent_list
getUserAgentSignature <- function (uniqueUserAgents) {  
  identifiers <- uniqueUserAgents
  identifiers<- gsub("\\(|\\)|\\[|\\]|\\{|\\}", " ", identifiers)
  # Remove the digits -- version related information note \b is for boundary
  identifiers<- gsub("\\b\\d", " ", identifiers)
  # Remove localestrings
  identifiers<- gsub("\\b(en(.{0,1})us)|(en(.{0,1})gb)|(fr(.{0,1})fr)|(ko(.{0,1})kr)\\b", " ", identifiers, ignore.case=TRUE)
  # Remove the delimiters
  identifiers <- gsub("/|;|,|%|@|-|:|=|\\*|\\+|_|\'|\"", " ", identifiers)
  # Remove single characters and replace them with a space!
  identifiers <- gsub("\\.", " ", identifiers)
  # Remove OS specific Information (Get this list by manually inspecting the userAgentElems)
  #\b(i(phone|pad|pod|os)(touch){0,1}(\d\w{0,2}){0,1})\b for iDevices
  identifiers <- gsub("\\b(i(phone|pad|pod|os)(touch|os|unknown){0,1}(\\d\\w{0,2}){0,1})\\b", " ", identifiers, ignore.case=TRUE)
  # Remove Android and remaining OS signatures
  identifiers <- gsub("\\b(apple|android|androidapp|dalvik|darwin|cfnetwork|linux|os)\\b", " ", identifiers, ignore.case=TRUE)
  # Remove build manufacturer specific Information (Get this list by manually inspecting the userAgentElems)
  identifiers <- gsub("\\b(build|htc|mac|intel|galaxy|nexus|samsung|gsmart|gigabyte|sony)\\b", " ", identifiers, ignore.case=TRUE)
  identifiers <- gsub("\\b(soju|crespo|maguro|mako|(ice(\ b{0,1})cream(\ {0,1})sandwich)|takju|st15i|(sony(\\w*)))\\b", " ", identifiers, ignore.case=TRUE)
  #  Remove popular sdk specific info 
  # afma - adsence for mobile apps
  identifiers <- gsub("\\b(afma)\\b", " ", identifiers, ignore.case=TRUE)
  # Remove carrier specific information .. problem with free and simple mobile
  identifiers <- gsub("\\b((t-mob(\\w*))|(at&t)|(simple\ mobile)|orange|free|verizon)\\b", " ", identifiers, ignore.case=TRUE)
  # Remove browser engine specific information
  identifiers <- gsub("\\b(gecko|webkit|applewebkit|khtml|like|sdk|androidsdk)\\b", " ", identifiers, ignore.case=TRUE)
  # Remover browser specific information -- We use browser as default!
  identifiers <- gsub("\\b(mozilla|safari|chrome)\\b", " ", identifiers, ignore.case=TRUE)
  # Remove misc strings
  identifiers <- gsub("\\b(app|unknown|unused|unavailable|none|empty|client|type|default|httpclient|http|carrier|com|cpu|gzip|sdk|\\w\\d+)\\b", " ", identifiers, ignore.case=TRUE)
  identifiers <- gsub("\\b(java|full|on|null|api|pro|httpclient|http|carrier|com|cpu|gzip|sdk|portal|\\w\\d+)\\b", " ", identifiers, ignore.case=TRUE)
  identifiers <- gsub("\\b(gsm|release|version|phone|tablet|touch|model|mobile|screen|osbuild|scale|density|height|width)\\b", " ", identifiers, ignore.case=TRUE)
  # Remove version strings like vxxx or exxxx 
  identifiers <- gsub("\\b(\\w|\\d)\\b", " ", identifiers)
  # Remove strings with one or two characters
  identifiers <- gsub("\\b\\w{1,2}\\b", " ", identifiers)
  # This one is tricky UPPERCASE CHARACTERS WITH NUMBERS -- used for build Note this must not remove FBAN and other such strings
  identifiers<- gsub("\\b((([A-Z]|[0-9])*)([0-9]+)([A-Z]*)+)\\b"," ", identifiers, ignore.case=FALSE)
  # Remove multiple spaces
  identifiers <- gsub(" {2,}", " ", identifiers)
  # Remove trailing and starting spaces
  identifiers <- gsub("(\ $)|(^\ )", "", identifiers)
  
  # Sort each identifier based on string tokens,
  # This step is done for LCS matching
  identifiers <- sapply(identifiers, function(x) paste(sort(unlist(strsplit(x, " "))), collapse=" "))
  # Massage variable names for the table
  signature <- identifiers
  #retFrame <- data.frame(user_agent, user_agent_signature=signature,stringsAsFactors=FALSE)  
  signature  
}

# A very crude way of finding the length of the LCS.
# I was not able to find some library that does this efficiently using suffix trees.
longestCommonSubstringLen <- function(str1, str2) {
  if (nchar(str1) == 0 || nchar(str2) == 0) {
    return(0)
  } 
  s1 <- unlist(strsplit(str1,split="")) 
  s2 <- unlist(strsplit(str2,split=""))
  num <- matrix(0,nchar(str1),nchar(str2) )  
  maxlen <- 0
  for (i in 1:nchar(str1)) {
    for (j in 1:nchar(str2)) {
      if (s1[i] == s2[j]) {
        if ((i==1) || (j==1)) {
          num[i,j] <- 1
        } else {
          num[i,j] <- 1+num[i-1,j-1]
        }
        if (num[i,j] > maxlen) {
          maxlen <- num[i,j]
        }
      }
    }
  } 
  maxlen
}

getSimilarityMatrix<- function (uniqueSigs) {    
  matrixDim <- length(uniqueSigs)
  simMatrix <- matrix (0, nrow=matrixDim, ncol=matrixDim)
  uniqueSigs <-tolower(uniqueSigs)
  i<-1; 
  j<-1;
  for (i in 1:matrixDim) {
    print(i)
    j<-i;
    simMatrix[i,j] <- 1;    
    if (i+1 > matrixDim) {
      break;
    }    
    s1 <- uniqueSigs[i];
    tokens1 <- unique(unlist(strsplit(s1, " ")))
    for (j in (i+1):matrixDim) { 
      s2 <- uniqueSigs[j];
      tokens2 <- unique(unlist(strsplit(s2, " ")))
      lmin <- min(nchar(s1), nchar(s2)); #we use min to get best case
      tokenlmin <- min(length(tokens1), length(tokens2));
      lcsLen <- longestCommonSubstringLen(s1, s2)
      simMatrix[i,j] <- max(lcsLen/lmin, length(intersect(tokens2, tokens1))/tokenlmin)
      simMatrix[j,i] <- simMatrix[i,j];
    }
  }   
  simMatrix[is.na(simMatrix)] <- 0
  simMatrix
}

getTopSimilarityValues <- function(simMatrix, count) {
  topSims <- matrix(0, nrow=nrow(simMatrix), ncol=count+1) 
  i<-1
  for (i in 1:nrow(simMatrix)) {
    x <- simMatrix[i,]
    x<-sort(x, decreasing=TRUE)
    topSims[i, ] <- c(sum(x[1:count]), x[1:count])
  }
  topSims
}

assignLabelsToSignatures <- function(uniqueSigs, simMatrix, threshold, defaultLabel) {
  matrixDim <- length(uniqueSigs)
  labelVector <- matrix (defaultLabel, nrow=matrixDim, ncol=1)
  i<-1
  for (i in 1:matrixDim) {
    if (labelVector[i] == defaultLabel) {
      labelVector[i] <- paste(unique(unlist(strsplit(tolower(uniqueSigs[i]), " "))), collapse=" ") 
      if (i+1 > matrixDim) {
          break;
      }
      for (j in (i+1):matrixDim) {
        if (simMatrix[i,j] > threshold) {
          labelVector[j] <- labelVector[i]
        }
      }
    }
  }  
  labelVector
}

#userAgentElems <- getUserAgentElems(uniqueUserAgents)

assignHttpSignature <- function(httpLogName) {
  global unknownAppLabel 

  httpData <- readHttpData(fName)
  unique_user_agent = unique(httpData$user_agent)
  user_agent_signature <- getUserAgentSignature(unique_user_agent)  
  unique_signatures <- sort(unique(user_agent_signature))
  # The similarities between 'n' signatures in a nxn matrix. The similarity is measured from 0 to 1
  # where 1 is identical and 0 implies least similarity
  simMatrix <- getSimilarityMatrix(unique_signatures)
  # All user_agent_signatures that have a similarity value above 0.75 grouped under a given label/tag
  app_label <- assignLabelsToSignatures(unique_signatures, simMatrix, 0.75, unknownAppLabel)
  # The signature table contains two columns, signature and the app_label
  signatureTable <- data.frame(user_agent_signature=unique_signatures, app_label=app_label, stringsAsFactors=FALSE)
  # UserAgenttable contains two columns :the user_agent and the user_agent_signature
  userAgentTable <- data.frame(user_agent=unique_user_agent, user_agent_signature=user_agent_signature)
  # We now assign the app_label to the list of unique user_agent 
  userAgentSignatureLabels <- merge(x=userAgentTable, y=signatureTable, by="user_agent_signature")
  # Assign an app_label of "unknown" to ones having an empty user_agent_signature
  userAgentSignatureLabels[userAgentSignatureLabels$user_agent_signature=="",]$app_label=unknownAppLabel
  # Now merge the httpData based on user_agent. This ensures that the appropriate signature and app_label is 
  # assigned to the flows. 
  httpDataLabeled <- merge(x=httpData, y=userAgentSignatureLabels, by="user_agent")
}

fName <- paste(broLogsDir, "http.log.info", sep="");
httpData <- assignHttpSignature(httpData)
fName <- paste(fName, ".app", sep="")
print(fName)
write.table(httpData, fName, sep="\t", quote=F, col.names=c(colnames(httpData)), row.names=FALSE)
httpSigs <- data.frame(uid=httpData$uid, app_label=httpData$app_label, stringsAsFactors=FALSE)
rm(httpData) # Free the memory for connData

### TODO:: All the code for other logs such as ssl and conn comes here. For the time being we just add stuff for conn.log
### for some tests.
fName <- paste(broLogsDir, "conn.log.info", sep="");
connData <- readConnData(fName)
connData <- merge(x=connData, y=httpSigs, by="uid", all.x=TRUE)
connData[is.na(connData$app_label),]$app_label=unknownAppLabel
fName <- paste(fName, ".app", sep="")
print(fName)
write.table(connData, fName, sep="\t", quote=F, col.names=c(colnames(connData)), row.names=FALSE, stringsAsFactors=FALSE)


 

