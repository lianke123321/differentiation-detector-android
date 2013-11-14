<?php
	error_reporting(E_ALL);
	ini_set('display_errors', '1');

	// Needs to be set by login or something
	$user = "arao";

	const OBJECT_POST_KEY = 'obj';

	// TODO checkSession and kick if not logged in

	if(!isset($_GET['action'])){
		fail("Action not set");
	}

	switch($_GET['action']){
		case "getDevices":
			echo getDevices($user);
			break;

		case "getRange":
			if(!isset($_GET['device'])){
				fail("Device not set");
			}
			echo getRange($user, $_GET['device']);
			break;

		case "getData":
			if(!isset($_GET['device']) || !isset($_GET['min']) || !isset($_GET['max'])){
				fail("Device, Min or Max not set");
			}
			echo getData($user, $_GET['device'], $_GET['min'], $_GET['max'],  isset($_GET['subdomainDepth']) ? $_GET['subdomainDepth'] : 0);
			break;

		case "banLink":
			if(!isset($_POST[OBJECT_POST_KEY])){
				fail("No object posted with key ".OBJECT_POST_KEY);
			}
			echo banLink($user, JSON_decode($_POST[OBJECT_POST_KEY], true));
			break;

		default:
			fail("Invalid action.");
	}

	function getData($user, $device, $min, $max, $subdLevels){
		try{
			// min and max are unix timestamps to return requests between. 
			// Banned results should be marked as such.

			// TODO Impliment
			// get all data from sqlite DB between a range of timestamps
			$banned = [];
			$appDb = connectToAppDb();
			$getName = $appDb->prepare("SELECT * FROM apps WHERE appId = ?");
			$result = $appDb->query("SELECT * FROM `banList` WHERE `userId` = ".$appDb->quote($user));
			while($row = $result->fetch()){
				if(!isset($banned[$row['appId']]))
					$banned[$row['appId']] = $row['hostDomain']."|";
				$banned[$row['appId']] += $row['hostDomain']."|";
			}

			$logDb = connectToLogDb($user);
			
			$result = $logDb->query("SELECT * FROM ".$logDb->quote($device)." WHERE timestamp BETWEEN ".$logDb->quote($min)." AND ".$logDb->quote($max).";");

			$obj = array();
			$apps = array();
			while($row = $result->fetch()){
				$hostname = subdomainToLevel($row['hostDomain'], $subdLevels);
				$appId = $row['appId'];
				if(!isset($apps[$appId])){
					//Grab app name
					$getName->execute(array($appId));
					$name = $getName->fetch()['appName'];

					//Create app record
					$apps[$appId] = array(
						'contacts' => array(),
						'uses' => 0,
						'name' => $name,
						'id'   => $appId
						);

					if(isset($banned[$appId]) && 1 === preg_match("/".$hostname."|/", $banned[$appId]))
						$apps[$appId]['banned'][$hostname] = 1;
				}

				// Increment the use count for the app
				$apps[$appId]['uses']++;

				if(!isset($apps[$appId]['contacts'][$hostname]))
					$apps[$appId]['contacts'][$hostname] = array(
						'hits' => 1
						);
				else
					$apps[$appId]['contacts'][$hostname]['hits']++;
			}

			$obj['apps'] = $apps;
			
			// Get from central mysql db
			$obj['phone'] = "Android";

			return json_encode($obj);
		} catch (Exception $e){
			fail($e);
		}
	}

	function banLink($user, $obj){
		// Adds this item to the ban list with 3 tuple
		// (userId, hostDomain, appId)

		$userId = $user;
		$appId = $obj['source']['appId'];
		$hostDomain = $obj['target']['name'];

		$mysql = connectToAppDb();
		$query = $mysql->prepare("SELECT count(*)  FROM `banList` WHERE `userId` = :userId AND `hostDomain` = :hostDomain AND `appId` = :appId");
		$query->bindParam(":userId", $userId);
		$query->bindParam(":hostDomain", $hostDomain);
		$query->bindParam(":appId", $appId);
		$query->execute();
		$count = $query->fetch(PDO::FETCH_NUM)[0];
		if($count == 0){
			if(!$mysql->query("INSERT INTO `meddleConVis`.`banList` (`userId`, `hostDomain`, `appId`) VALUES ('$userId', '$hostDomain', '$appId');"))
				fail("Could not ban");
			else
				return '{"success":"banned"}';
		} else if ($count == 1){
			if(!$mysql->query("DELETE FROM `meddleConVis`.`banList` WHERE `banList`.`userId` = '$userId' AND `banList`.`hostDomain` = '$hostDomain' AND `banList`.`appId` = '$appId' LIMIT 1;"))
				fail("Could not unban");
			else
				return '{"success":"unbanned"}';
		} else {
			fail("More than one entry in ban db");
		}
	}

	function getDevices($user){
		$logDb = connectToLogDb($user);

		try{
			$result = $logDb->query("SELECT name FROM sqlite_master WHERE type = 'table'");
		} catch (Exception $e){
			echo "Could not query: ".$e;
		}
		$tables = array();
		while($row = $result->fetch()){
			$tables[] = $row['name'];
		}
		//TODO get tables from logDb

		return json_encode($tables);
	}

	function getRange($user, $device){
		$logDb = connectToLogDb($user);

		try{
			$max = $logDb->query("SELECT MAX(timestamp) FROM ".$logDb->quote($device).";");
			$min = $logDb->query("SELECT MIN(timestamp) FROM ".$logDb->quote($device).";");
		} catch (Exception $e){
			fail("Could not query database: ".$e->getMessage());
		}
		
		$range['min'] = $min->fetch()[0];
		$range['max'] = $max->fetch()[0];
		return json_encode($range);
	}

	function fail($reason = "unset"){
		echo json_encode(array(
			'fail' => 'true',
			'reason' => $reason
			));
		exit(0);
	}

	function subdomainToLevel($domain, $subdLevels){
		if($subdLevels == 0)
			return $domain;

		$parts = explode('.', $domain);
		$levels = count($parts);
		$newDomain = $parts[$levels - 1];

		for($i = 1; $i < $subdLevels && $i < $levels; $i++)
			$newDomain = $parts[$levels - $i - 1].".".$newDomain;

		return $newDomain;
	}

	function connectToLogDb($user){
		if(!isset($user))
			fail("User not logged in.");

		$logFile = "./data/".$user.".logs.sqlite3";
		try{
			$logDb = new PDO("sqlite:$logFile");
			$logDb->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
		} catch (Exception $e){
			fail("Could not connect to sqlite db: $logFile \n\t".$e->getMessage());
		}
		return $logDb;
	}

	function connectToAppDb(){
		try{
			$appDb = new PDO('mysql:host=localhost;dbname=meddleConVis', "conVis", "snFH6e9bzaf46JEx");
			$appDb->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
		} catch (Exception $e){
			fail("Could not connect to mysql db.\n\t".$e->getMessage());
		}
		return $appDb;
	}
?>
