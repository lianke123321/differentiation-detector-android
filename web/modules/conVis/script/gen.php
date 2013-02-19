<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

$phoneType = "Android";

function shortname($host){
	$hostChunks = explode(".", $host);
	$len = count($hostChunks);
	return $hostChunks[$len - 2].".".$hostChunks[$len - 1];
}

function appFromUA($userAgent){
	// Make more interesting when we have more data
	return explode('/', $userAgent)[0];
}

// Run bash script
$data = shell_exec("tail -n+9 http.log | head -n -1 | cut -sf 5-6,9,12");

// Parse
$dataLines = explode("\n", $data);

$json = new stdClass();

$json->maxHits = 0;

$apps = [];
foreach($dataLines as $line){
	$fields = explode("\t", $line);
	if(count($fields) != 4)
		continue;
	$ip = $fields[0];
	$port = $fields[1];
	$hostname = $fields[2];
	$shortname = shortname($hostname);
	$userAgent = $fields[3];
	$appName = appFromUA($userAgent);
	
	if(array_key_exists($appName, $apps)){
		$app = $apps[$appName];
	} else {
		$app = new stdClass();
		$app->shortname = $appName;
		$app->hits = 0;
		$app->requests = [];
		$app->visited = true;
		$app->type = "app".$phoneType;
		$app->userAgents[$userAgent] = 1;
		$apps[$appName] = $app;
	}
	
	$app->hits += 1;

	if(array_key_exists($shortname, $app->requests)){
		$host = $app->requests[$shortname];
	} else {
		$host = new stdClass();
		$host->shortname = $shortname;
		$host->hits = 0;
		$host->type = "host".$phoneType;
		$host->referrers = [];
		$app->requests[$shortname] = $host;
	}

	// Use keys of array to make a 'set' structure
	$host->hits += 1;
	$host->fullnames[$hostname][$ip][$port] = 1;
	
	$json->maxHits = max($json->maxHits, $app->hits, $host->hits);
}

$json->apps = $apps;
/*
$phone = new stdClass();
$phone->requests = [];
$phone->hits = $json->maxHits = $json->maxHits * 1.2;
$phone->type = "phone".$phoneType;
$phone->shortname = "My ".$phoneType;
foreach($apps as $app){
	$phone->requests[$app->shortname] = $app;
}
$json->apps[$phone->shortname] = $phone;
*/

// Package as json
echo json_encode($json);

?>
