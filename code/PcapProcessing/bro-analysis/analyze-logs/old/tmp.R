baseDir<-"/Users/ashwin/proj-work/meddle/meddle-data/"
scriptsDir<-"/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/analyze-logs/"
setwd(scriptsDir);
broAggDir<-paste(baseDir,"bro-aggregate-data/", sep="");
broLogsDir<-paste(baseDir, "bro-results/", sep="");
opar = par();

fName<-paste(broLogsDir, "arao-droid/http.log", sep="");
httpData<-read.table(fName, header=T, sep="\t", fill=TRUE, stringsAsFactors=FALSE, quote=""); # Note FILL causes silent padding
reqHosts<-httpData[(httpData$request_body_len+httpData$response_body_len)>(10*10^6),];
reqHosts$id.orig_h;
