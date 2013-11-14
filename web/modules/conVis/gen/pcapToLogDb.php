<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

// Get file name from args
if(array_key_exists(1, $argv)){
	$file = $argv[1];
} else {
	echo "No file set. Exiting.\n";
	exit(0);
}

// Get userName and device from filename
$fileParts = explode("-", $file);
if(array_key_exists(1, $fileParts) && array_key_exists(2, $fileParts)){
	$userName = $fileParts[1];
	$device = $fileParts[2];
} else {
	echo "Invalid log file name: ".$file."\n";
	exit(0);
}
// Connect to mysql appDb
$appDb = new mysqli("localhost", "conVis", "snFH6e9bzaf46JEx", "meddleConVis");

// Connect to sqlite db to store the app requests in
$logFile = "../data/".$userName.".logs.sqlite3";
try{
	$logDb = new PDO("sqlite:$logFile");
	$logDb->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (Exception $e){
	echo "Could not connect to sqlite db: $logFile \n\t".$e->getMessage()."\n";
}

//TODO create table for device if not exist


// Add all apps from trace file as a transaction
try {
	$logDb->beginTransaction();

	$logDb->exec('CREATE TABLE IF NOT EXISTS "main"."'.$device.'" 
			(
				"timestamp" INTEGER NOT NULL, 
				"appId" INTEGER NOT NULL, 
				"hostDomain" TEXT NOT NULL,
				UNIQUE ("timestamp", "appId", "hostDomain") ON CONFLICT IGNORE
			);');
	$addAppStmt = $logDb->prepare("INSERT INTO $device (timestamp, appId, hostDomain) VALUES (:time,:appId,:host)");

	$num = processFile($appDb, $addAppStmt, $file);

	echo "Added $num requests to logDb\n";
	$logDb->commit();
} catch (Exception $e) {
  $logDb->rollBack();
  echo "Failed: " . $e->getMessage()."\n";
}

function processFile($appDb, $addAppStmt, $file){
	$count = 0;
	$addAppStmt->bindParam(":time", $timestamp);
	$addAppStmt->bindParam(":appId", $appId);
	$addAppStmt->bindParam(":host", $hostname);
	$datalines = prepareHttpLogFile($file, "1,9,12");
	foreach($datalines as $line){
		$fields = explode("\t", $line);
		if(count($fields) != 3)
			continue;

		//Identify collumns
		$timestamp = $fields[0];
		$hostname = $fields[1];
		$userAgent = $fields[2];

		// UA to appId
		$appId = uaToAppId($appDb, $userAgent);

		// Put request into DB
		$addAppStmt->execute();
		$count++;
	}

	return $count;
}

function prepareHttpLogFile($filename, $collumns){
	global $path;
	$filename = substr($filename, strlen($path));
	$ok = shell_exec("bro -r $filename &> /dev/null; echo -n $?");
	if($ok !== '0'){
		echo "Bro could not read file. Exiting.\n";
		exit(0);
	}

	// Run bash script
	$data = shell_exec("tail -n+9 http.log | head -n -1 | cut -sf $collumns & rm *.log &> /dev/null");

	// Parse
	return explode("\n", $data);
}

function isBrowser($userAgent){
	if(stripos ($userAgent, "Mozilla") === false 
	|| stripos ($userAgent, "WebKit") === false 
	|| stripos ($userAgent, "MSIE") === false 
	|| stripos ($userAgent, "Opera") === false){
		return false;
	}
	return true;
}

function normalizeUa($userAgent){
	$normUa = preg_replace("/([0-9]+\.)+[0-9]+/", "[VER]", $userAgent);
	if(isBrowser($normUa)){
		$normUa = preg_replace("/[A-Z]{3}[0-9]{2}[A-Z]?/","[ANDVER]", $normUa);
		$normUa = preg_replace("/\(Linux[^\)]+Android[^\)]+\)/","[ANDDEV]", $normUa);
		//$normUa = preg_replace("/iOS Version Regex/","[IOSVER]", $normUa);
	} else {
		$normUa = explode(" ", $normUa)[0];
	}
	return $normUa;
}

function uaToAppId($appDb, $userAgent){
	$normUa = normalizeUa($userAgent);
	$uaHash = hash('sha256', $normUa);
	$result = $appDb->query("SELECT * FROM uaToAppId WHERE `userAgentHash` = '$uaHash'");
	$appId = -1;
	while($row = $result->fetch_array()){
		if($row['userAgent'] === $normUa)
			$appId = $row['appId'];
	}
	if($appId == -1){
		$appId = $appDb->query("SELECT COUNT(*) FROM uaToAppId;")->fetch_array()[0] + 1;
		$appDb->query("INSERT INTO `meddleConVis`.`uaToAppId` (`userAgentHash`, `userAgent`, `appId`) VALUES ('$uaHash', '".$appDb->escape_string($normUa)."', '$appId');");
		$appDb->query("INSERT INTO `meddleConVis`.`apps` (`appId`, `appName`) VALUES ('$appId', '".$appDb->escape_string(appNameFromUA($userAgent))."');");
	}
	return $appId;
}

function appNameFromUA($userAgent){
	$name = explode('/', $userAgent)[0];
	if($name == "" || 1 == preg_match('/^[^a-zA-Z0-9\w]$/', $name))
		return "Unknown App: ".$userAgent;
	return preg_replace('/([a-z])([A-Z][a-z])/', '$1 $2', $name);
}

?>
