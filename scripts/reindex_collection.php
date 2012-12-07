#!/usr/bin/php -q

/** This script requires the tuque API which can be downloaded from:
 *  https://github.com/jonathangreen/tuque
 * 
 * Basic instructions on using the API are here: 
 *  https://github.com/Islandora/islandora/wiki/Build,-Access,-Modify-and-Delete-Fedora-objects-with-theTuque-interface
 *
 *  This script will only work with fedora commons and you need to have the correct path to the fedoragsearch client 
 *  runRestClient.sh
 *
 *  I have developed this on Redhat EL 6.  Success on other platforms is up to you.
 */


<?php
require_once 'tuque/HttpConnection.php';
require_once 'tuque/FedoraApi.php';
require_once 'tuque/Repository.php';
require_once 'tuque/RepositoryConnection.php';
require_once 'tuque/Object.php';
require_once 'tuque/Cache.php';
require_once 'tuque/FedoraApiSerializer.php';


/**
 * Make a connection to the repository 
 */
$fedoraUrl = "http://islandora.usask.ca:8080/fedora";
$username = "fedoraUsername";
$password = "fedoraPassword";
$connection = new RepositoryConnection($fedoraUrl, $username, $password);
$connection->reuseConnection = TRUE;
$repository = new FedoraRepository(
       new FedoraApi($connection),
    new SimpleCache());

/**
 *This section is where I grab the list of pids from a collection using itql query
 */
$pid = $argv[1];
$format = 'select $object from <#ri> where $object <info:fedora/fedora-system:def/relations-external#isMemberOfCollection> <info:fedora/%s>';
$query = sprintf($format, $pid);
$objects = $repository->ri->itqlQuery($query, 'unlimited', '0'); // for itql
//print_r($objects);

/**
 *This bit is for reindexing a specific collection
 */
$start = date("Y-m-d H:i:s");
foreach ($objects as $k => $v) {
  $p = $v['object']['value'];
  print $p ."\n";
  reindexCollection($p);
}
updateIndex();
print "Start time: ". $start ." End time". date("Y-m-d H:i:s") ."\n";


function updateIndex(){
 chdir('/usr/fedora/tomcat/webapps/fedoragsearch/client');
  $res = exec("./runRESTClient.sh \"http://localhost:8080/fedoragsearch/rest updateIndex optimize\"");
}


function reindexCollection($pid){
  $here = getcwd();
  chdir('/usr/fedora/tomcat/webapps/fedoragsearch/client');
  $res = exec("./runRESTClient.sh \"http://localhost:8080/fedoragsearch/rest updateIndex fromPid $pid\"");
  chdir($here);
}


?>
