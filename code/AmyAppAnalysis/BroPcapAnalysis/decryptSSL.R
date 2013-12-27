baseDir<-"/user/arao/home/proj-work/meddle/projects/meddle_controlled_experiments/community_experiments/"
scriptsDir<-paste(baseDir, "/parsing-scripts/", sep="");
setwd(scriptsDir);
broDir<-paste(baseDir,"/bro-results/", sep="");
bumpCertDir <- paste(baseDir, "/BumpedCerts/", sep="")
resultsDir<-paste(baseDir, "/paperData/", sep="");
sslDumpPath <- "/opt/analyze-pcap/bin/ssldump"
decrSslPath <- paste(baseDir, "/decrSSL/", sep="")
pcapPath <- paste(baseDir, "/aggr-pcap-data/", sep="")

userList <- c("amy", "test1", "test2", "test3")
source(paste(scriptsDir, "/readLogFiles.R", sep=""))

getSslSignatures <- function(sslData) {
  sslSubjects <- unique(sslData$subject)  
  cnStrings <- sapply(sslSubjects, function(x) { 
    y<- regexpr("CN=.*?(\b|,|$)", x); 
      if (y != -1) {
        # #+3 for CN=
        signature<-unlist(strsplit(substring(x, y+3, y+attr(y, "match.length")-1), ","))
      } else { 
        signature <- "" 
      } 
      # Remove the preceding *.
      #signature <- gsub("\\*\\.", "", signature)      
      signature
    }, USE.NAMES=FALSE)
  x <- data.frame(subject=sslSubjects, cn=cnStrings, stringsAsFactors=FALSE)
  return(x);
}

getCertSignatures <- function(certData) {
  sslSubjects <- unique(certData$subject)  
  cnStrings <- sapply(sslSubjects, function(x) { 
    y<- regexpr("\\/CN=.*?(\b|,|\\+|\\/|$)", x);
    if (y != -1) {
      # #+3 for /CN=
      signature<-unlist(strsplit(substring(x, y+4, y+attr(y, "match.length")-1), "\\+"))
    } else { 
      signature <- "" 
    } 
    # Remove the preceding *.
    #signature <- gsub("\\*\\.", "", signature)      
    signature
  }, USE.NAMES=FALSE)
  certData$cn <- cnStrings  
  return(certData);
}

runSslDump <- function(sslInfo, userName) {
  i<-1
  certKey <- paste(scriptsDir, "/cert.key", sep="");
  pcapName <- paste(pcapPath, "/", userName, ".pcap", sep="")  
  for (i in 1:nrow(sslInfo)) {
#    if (i > 10 ) {
#      break
#    }
    x <- sslInfo[i, ]        
#    filterString <- paste("host", x$id.resp_h)
    filterString <- paste("host", x$id.orig_h, "and port", x$id.orig_p,     
                          "and host", x$id.resp_h, "and port", x$id.resp_p)
    certName <- paste(bumpCertDir, "/certs/", x$cert_file, ".pem", sep="")
    opensslCmd <- paste("openssl rsa -in", certName, "-out", certKey);         
    print(opensslCmd)
    system(opensslCmd)
    outName <- paste(decrSslPath, "/", userName, "/decrypted-",
                     userName, "-", x$ts,"-",gsub("\\*", "star", x$cn),
                     sep="");
    sslDumpCmd <- paste(sslDumpPath, "-k", certKey, "-r", pcapName,"-dn", filterString, 
                        " > ", outName); 
    print(sslDumpCmd)
    system(sslDumpCmd)
  }
}

userName <- "test3"  
fName <- paste(broDir, "/", userName, "/ssl.log", sep="")
sslData <- readSslData(fName)
sslSignatures <- getSslSignatures(sslData)
certData <- read.table(paste(bumpCertDir, "/index.txt", sep=""),                       
                       sep="\t",
                       col.names=c("valid", "ts", "blank", "fname", "na", "subject"),
                       header=FALSE);
certData <- getCertSignatures(certData);
certFNames <- data.frame(cn=certData$cn, cert_file=certData$fname, stringsAsFactors=FALSE)
sslInfo <- merge(x=sslData, y=sslSignatures, by="subject")
sslInfo <- merge(x=sslInfo, y=certFNames, by="cn")
write.table(sslInfo, paste(broDir, "/", userName,"/ssl.log.certs", sep=""), sep="\t",
            quote=FALSE,row.names=FALSE)

sslInfo <- readTable(paste(broDir, "/", userName,"/ssl.log.certs", sep=""))
runSslDump(sslInfo, userName)            



