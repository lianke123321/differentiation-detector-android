CREATE TABLE `AppMetaData` (
  `appID` int(11) NOT NULL,
  `appName` varchar(128) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`appID`),
  UNIQUE KEY `appName_UNIQUE` (`appName`),
  UNIQUE KEY `appID_UNIQUE` (`appID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `CDNAppMap` (
  `appID` int(11) NOT NULL,
  `cdnHostSignature` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`appID`),
  UNIQUE KEY `cdnHostSignature_UNIQUE` (`cdnHostSignature`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `HttpFlowData` (
  `ts` double NOT NULL,
  `broFlowID` varchar(15) COLLATE utf8_unicode_ci NOT NULL,
  `userID` int(11) NOT NULL,
  `agentID` int(11) NOT NULL,
  `appID` int(11) NOT NULL,
  `trackerFlag` tinyint(1) NOT NULL DEFAULT '0',
  `piiFlag` tinyint(1) NOT NULL DEFAULT '0',
  `remoteHost` varchar(256) COLLATE utf8_unicode_ci DEFAULT NULL,
  `remoteOrg` varchar(128) COLLATE utf8_unicode_ci DEFAULT NULL,
  KEY `userID` (`userID`),
  KEY `ts` (`ts`),
  KEY `userID_2` (`userID`,`ts`,`trackerFlag`),
  KEY `userID_3` (`userID`,`ts`),
  KEY `agentID` (`agentID`),
  KEY `appID` (`appID`),
  KEY `remoteOrg` (`remoteOrg`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `PackageDetails` (
  `appID` int(11) NOT NULL DEFAULT '0',
  `revPkgName` varchar(128) COLLATE utf8_unicode_ci NOT NULL,
  `pkgOrgDomain` varchar(128) COLLATE utf8_unicode_ci NOT NULL,
  `pkgAppDomain` varchar(128) COLLATE utf8_unicode_ci NOT NULL,
  `pkgTitle` varchar(128) COLLATE utf8_unicode_ci NOT NULL,
  `pkgCreator` varchar(128) COLLATE utf8_unicode_ci NOT NULL,
  `domainTested` tinyint(1) NOT NULL DEFAULT '0',
  KEY `appID` (`appID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


CREATE TABLE `TrackerDomains` (
  `domain` varchar(128) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`domain`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


CREATE TABLE `UserAgentSignatures` (
  `agentID` int(11) NOT NULL,
  `appID` int(11) NOT NULL,
  `userAgent` varchar(512) COLLATE utf8_unicode_ci NOT NULL,
  `agentSignature` varchar(512) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`agentID`),
  KEY `userAgent_2` (`userAgent`(255)),
  KEY `appID` (`appID`),
  KEY `agentSignature` (`agentSignature`(255))
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `UserConfigChange` (
  `userID` int(11) NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `configVariable` varchar(512) COLLATE utf8_unicode_ci DEFAULT NULL,
  `newValue` varchar(512) COLLATE utf8_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `UserConfigs` (
  `userID` int(11) NOT NULL AUTO_INCREMENT,
  `userName` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  `filterAdsAnalytics` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userID`),
  UNIQUE KEY `userName` (`userName`)
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `UserTunnelInfo` (
  `rowID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `userID` int(11) NOT NULL,
  `clientTunnelIpAddress` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  `clientRemoteIpAddress` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  `serverIpAddress` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `startStopFlag` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`rowID`),
  UNIQUE KEY `indexRowID` (`rowID`),
  KEY `indexTimeFlag` (`timestamp`,`startStopFlag`),
  KEY `indexTimestamp` (`timestamp`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
























