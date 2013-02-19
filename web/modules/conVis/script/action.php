<?php
	error_reporting(E_ALL);
	ini_set('display_errors', '1');

	const FAIL_REPLY = 'fail';
	const SUCCESS_REPLY = 'success';
	const OBJECT_POST_KEY = 'obj';

	if(!isset($_POST[OBJECT_POST_KEY])){
		echo FAIL_REPLY;
		exit(0);
	}

	$obj = JSON_decode($_POST[OBJECT_POST_KEY]);

	// TODO Attempt to add this to the ban list with 3 tuple
	// (userIp, hostIp, userAgent Regex)

	print_r($obj);
	echo SUCCESS_REPLY;

?>
