library(RMySQL)

cmdArgs <- commandArgs(trailingOnly=TRUE)
if (length(cmdArgs) < 2) {
  print (paste("Insufficient args in ", cmdArgs))
  print (paste("R -f AssignSignatures.R --args <meddle.config> <named.conf.adblock>"))
  quit(save="no")
}
meddleConfigFile <- cmdArgs[1];
namedTrackerFile <- cmdArgs[2];

getDBConn <- function(meddleConfigName) {
  configData <- read.table(meddleConfigName, sep="=", header=FALSE, quote="\"",
                           col.names=c("variable", "value"), fill=FALSE, stringsAsFactors=FALSE,
                           comment.char="#")   
  dbName   <- configData[configData$variable=="dbName",]$value
  dbServer <- configData[configData$variable=="dbServer",]$value
  dbUser   <- configData[configData$variable=="dbUserName",]$value
  dbPasswd <- configData[configData$variable=="dbPassword",]$value  
  dbConn <- dbConnect(MySQL(), user=dbUser, password=dbPasswd, dbname=dbName, host=dbServer)  
  dbSendQuery(dbConn, "SET NAMES 'utf8'");
  dbSendQuery(dbConn, "SET CHARACTER SET 'utf8'");  
  return (dbConn)
}

dbConn <- getDBConn(meddleConfigFile)
namedTrackerTable <- read.table(namedTrackerFile, header=FALSE, sep="\"", fill=TRUE, 
                                col.names=c("zone", "domain", "misc1", "misc2", "misc3"),
                                stringsAsFactors=FALSE, quote="",comment.char = "/", )
trackerTable <- data.frame(domain=namedTrackerTable$domain, stringsAsFactors=FALSE)
dbWriteTable(dbConn,"TrackerDomains", trackerTable, append=TRUE, row.names=FALSE);
dbDisconnect(dbConn)