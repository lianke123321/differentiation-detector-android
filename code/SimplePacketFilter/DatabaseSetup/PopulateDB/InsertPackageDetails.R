library(RMySQL)

cmdArgs <- commandArgs(trailingOnly=TRUE)
if (length(cmdArgs) < 2) {
  print (paste("Insufficient args in ", cmdArgs))
  print (paste("R -f AssignSignatures.R --args <meddle.config> <named.conf.adblock>"))
  quit(save="no")
}
meddleConfigFile <- cmdArgs[1];
packageFile <- cmdArgs[2];

meddleConfigFile <- "/home/arao/proj-work/meddle/arao-meddle/meddle/code/SimplePacketFilter/PktFilterModule/meddle.config"
packageFile <- "/home/arao/proj-work/meddle/arao-meddle/meddle/code/SimplePacketFilter/DatabaseSetup/apkListGooglePlay.txt"

getDBConn <- function(meddleConfigName) {
  configData <- read.table(meddleConfigName, sep="=", header=FALSE, quote="\"",
                           col.names=c("variable", "value"), fill=FALSE, stringsAsFactors=FALSE,
                           comment.char="#")   
  dbName   <- configData[configData$variable=="dbName",]$value
  dbServer <- configData[configData$variable=="dbServer",]$value
  dbUser   <- configData[configData$variable=="dbUserName",]$value
  dbPasswd <- configData[configData$variable=="dbPassword",]$value    
  dbConn <- dbConnect(MySQL(), user=dbUser, password=dbPasswd, dbname=dbName, host=dbServer,
                      client.flag=CLIENT_MULTI_STATEMENTS);
  dbSendQuery(dbConn, "SET NAMES 'utf8'");
  dbSendQuery(dbConn, "SET CHARACTER SET 'utf8'");  
  return (dbConn)
}



getPackageMeta <- function(packageFile) {
#dbConn <- getDBConn(meddleConfigFile)
  packageMeta <- read.table(packageFile, header=TRUE, sep="\t", fill=TRUE,                           
                            stringsAsFactors=FALSE, quote="",comment.char = "", )
  packageMeta <- packageMeta[!duplicated(packageMeta[c("Title", "Package.name","Creator")]),]
  packageMeta$domains <- unlist(lapply(packageMeta$Package.name, function(x) { y<-unlist(strsplit(x,"\\."));
                                                                               y <- rev(y);                                                                                                                                                             
                                                                               y <- y[(y!="android")&(y!="apps")&(y!="app")]
                                                                               y <- paste(y,collapse=".", sep="");                                                                             
                                                                               return(y);
                                                                              }))

  packageMeta$orgdomain <- unlist(lapply(packageMeta$domains, function(x) { y<-unlist(strsplit(x,"\\."));                 
                                                                            if (length(y)>1) {
                                                                              if ((nchar(tail(y,1))>2) | ((y[length(y)-1])!= "co")) {
                                                                                y<-tail(y,2);
                                                                              } else {
                                                                                #print(y)
                                                                                y<-tail(y,3);
                                                                              }
                                                                            }
                                                                            y <- paste(y,collapse=".", sep="");                                                                        
                                                                            return(y);
                                                                          }))

  packageMeta$appdomain <- unlist(lapply(packageMeta$domains, function(x) { y<-unlist(strsplit(x,"\\."));                 
                                                                            if (length(y)>1) {
                                                                              if ((nchar(tail(y,1))>2) | ((y[length(y)-1])!= "co")) {
                                                                                y<-tail(y,3);
                                                                              } else {
                                                                                #print(y)
                                                                                y<-tail(y,4);
                                                                              }
                                                                            }
                                                                            y <- paste(y,collapse=".", sep="");                                                                        
                                                                            return(y);
                                                                            }))
  packageMeta$appSigHint <- gsub("([[:blank:]]|[[:punct:]]|®|™|☆|★)", "",packageMeta$Title, perl=TRUE, ignore.case=TRUE)
  packageMeta$appSigHint <- gsub("forandroid(((app)|(beta)){0,})$", "", packageMeta$appSigHint, ignore.case=TRUE, perl=TRUE)  
  packageMeta$appSigHint <- gsub("(for)((google)|(facebook)|(twitter)|(instagram)|(flickr)).*$", "", packageMeta$appSigHint, ignore.case=TRUE, perl=TRUE)  
  packageMeta$appSigHint <- gsub("(mobile)((app){0,})$", "", packageMeta$appSigHint, ignore.case=TRUE, perl=TRUE)  
  return (packageMeta)
}

readAppMetaDataTable <- function(dbConn) {    
  # Not using dbReadTable for UTF issues -- this seems to work
  dbSendQuery(dbConn, "SET NAMES 'utf8'");
  dbSendQuery(dbConn, "SET CHARACTER SET 'utf8'");  
  x <- dbSendQuery(dbConn, "SELECT * from AppMetaData;");
  dbAppDataTable <- fetch(x, n=-1);    
  #print(dbAppDataTable)
  appDataTable <- data.frame(app_id = dbAppDataTable$appID,
                             app_signature = dbAppDataTable$appName,  
                             stringsAsFactors = FALSE)                               
  return (appDataTable)
}

getPackages <- function(dbConn, packageFile) {
  # Read from file
  packageMeta <- getPackageMeta(packageFile)
  # read from DB
  appMetaData <- readAppMetaDataTable(dbConn)
  
  # Make list of existing and new packages
  tmpPackage <- data.frame(app_signature=unique(packageMeta$appSigHint))
  tmpPackage <- merge(tmpPackage, appMetaData, by="app_signature", all.x=TRUE);
  existingPackages <- tmpPackage[!is.na(tmpPackage$app_id),]
  newPackages <- tmpPackage[is.na(tmpPackage$app_id),]
  newPackages <- newPackages[!duplicated(tolower(newPackages$app_signature)),]
  newPackages$app_id <- seq((max(appMetaData$app_id)+1), (max(appMetaData$app_id)+nrow(newPackages)))
  dbAppMetaData <- data.frame(appID = newPackages$app_id, 
                              appName = newPackages$app_signature,
                              stringsAsFactors=FALSE);
  print("Are you sure you want to write!")
  #dbWriteTable(dbConn, "AppMetaData", dbAppMetaData, append=TRUE, row.names=FALSE);
  # Combine :)
  tmpPackage <- rbind(existingPackages, newPackages)
  tmpPackage$appSigHint <- tmpPackage$app_signature
  tmpPackage$app_signature <- NULL;
  return(tmpPackage);  
}

writePackageDetails <- function(dbConn, packageMeta) {
  dbSendQuery(dbConn, "SET NAMES 'utf8'");
  dbSendQuery(dbConn, "SET CHARACTER SET 'utf8'");  
  x <- dbSendQuery(dbConn, "SELECT * from PackageDetails;");
  currPackageDetails <- fetch(x, n=-1)
  dbPackageDetails <- data.frame(appID = packageMeta$app_id,
                                 revPkgName = packageMeta$domains,
                                 pkgOrgDomain = packageMeta$orgdomain,
                                 pkgAppDomain = packageMeta$appdomain,
                                 pkgTitle = packageMeta$Title,
                                 pkgCreator = packageMeta$Creator,
                                 domainTested = FALSE,
                                 stringsAsFactors=FALSE)
  dbPackageDetails <- rbind(currPackageDetails, dbPackageDetails);
  # Placing db entries first ensures that the ones in DB are given preference
  dbPackageDetails <- dbPackageDetails[!duplicated(dbPackageDetails[c("appID", "revPkgName", "pkgTitle", "pkgCreator")]),]
  dbWriteTable(dbConn, "PackageDetails", dbPackageDetails, append=TRUE, row.names=FALSE);
  print(paste("The package table now has ", nrow(dbPackageDetails), " packages in the table"));
  return (TRUE)
}

# CREATE BACKUP OF TABLES BEFORE RUNNING THIS

dbConn <- getDBConn(meddleConfigFile)
allPackages <- getPackages (dbConn, packageFile)
packageMeta <- getPackageMeta(packageFile)
print(nrow(packageMeta))
packageMeta <- merge(packageMeta, allPackages, by="appSigHint")
packageMeta <- packageMeta[order(packageMeta$app_id, decreasing=FALSE),]
print("Check before you want to write to DB");
#writePackageDetails(dbConn, packageMeta)
dbDisconnect(dbConn);
