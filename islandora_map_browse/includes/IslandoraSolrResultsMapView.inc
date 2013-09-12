<?php
/*
error_reporting(E_ALL);
ini_set('display_errors', TRUE);
ini_set('display_startup_errors', TRUE);
*/

/**
 * @file
 * Contains methods to search solr and display results.  depends on Apache_Solr_Php client.
 */

module_load_include('inc', 'islandora_solr_search', 'IslandoraSolrResults');

/**
 * Extention of IslandoraSolrResults for templating purposes.
 * This overrides the displayResults function to provide an alternate display type.
 */

class IslandoraSolrResultsMapView extends IslandoraSolrResults {


/*
  function IslandoraSolrResultsMapView() {
    if (module_exists('apachesolr')) {
      module_load_include('php', 'apachesolr', 'SolrPhpClient/Apache/Solr/Service');
    }
    else {
      module_load_include('php', 'islandora_solr_search', 'SolrPhpClient/Apache/Solr/Service');
    }
  }
*/
  /**
   * Outputs results basically in the normal way, but with thumbnails pulled
   * from the Fedora repository.
   *
   * @param $results
   *   A solr resultset object.
   *
   * @return
   *   html output for the resultset. Note: we currently create this
   *   output manually, should refactor to use drupal forms api.
   */
  function mapResults($solrQueryProcessor) {

$withVal = 0;
$withoutVal = 0;

//drupal_set_message(var_dump($solrQueryProcessor));

/**
 * The solrQueryProcessor contains the response from solr.  This includes 
 * the original query doing a drupal_set_message(var_dump($solrQueryProcessor));
 * will allow you to see what you have to work with
 */
//drupal_set_message($solrQueryProcessor->islandoraSolrResult['response']['numFound']);
//drupal_set_message("processor: ". $solrQueryProcessor->solrQuery);

  $element = array(
'#type' => 'markup',
'#markup' => '<script type="text/javascript" src="https://maps.googleapis.com/maps/api/js?key=AIzaSyCzzh-hzjLBsi6n9J7VPGg-OmeTTtt2v8M&sensor=false"></script>',
);


drupal_add_html_head($element, 'google_api');
//drupal_add_js(drupal_get_path('module', 'islandora_map_browse') . '/js/map_inludes.js', 'file');
//drupal_add_js(drupal_get_path('module', 'islandora_map_browse') . '/js/markerclusterer.js', 'file');
drupal_add_js(drupal_get_path('module', 'islandora_map_browse') . '/js/open_map_includes.js', 'file');
drupal_add_js(drupal_get_path('module', 'islandora_map_browse') . '/js/OpenLayers-2.12/OpenLayers.js', 'file');


$queryInfoForJS = array();

$response_data = $solrQueryProcessor->islandoraSolrResult['response'];

//Dump the following into drupal set message to see what your dealing with
$res = $solrQueryProcessor;

//drupal_set_message(print_r($res));

$InfoForJS['qt'] = $solrQueryProcessor->solrQuery;
$InfoForJS['numFound'] = $solrQueryProcessor->islandoraSolrResult['response']['numFound'];
$InfoForJS['rows'] = $solrQueryProcessor->solrLimit;
//Need to query drupal for the fedora URL 
$InfoForJS['baseUrl'] = "http://islandorasev-dev.usask.ca";
$InfoForJS['fedoraPrefix'] = "/islandora/object/";
$InfoForJS['fedoraSuffix'] = "/datastream/TN/view";
$InfoForJS['objectPrefix'] = "/islandora/object/";


//This section resets the limits on the query and re-executes
$upperlimit = $solrQueryProcessor->islandoraSolrResult['response']['numFound'];
$lowerlimit = 0;
$increment = 5000;
$solrQueryProcessor->solrStart = $lowerlimit;
$solrQueryProcessor->solrLimit = $increment;

$solrQueryProcessor->resetResults();
$solrQueryProcessor->executeQuery();
$response_data = $solrQueryProcessor->islandoraSolrResult['response'];


$object_results = $response_data['objects'];
$newpins = array();
$nopins = array();
foreach ($response_data['objects'] as $object_result) {
	$doc = $object_result['solr_doc'];
	$thumb = $object_result['thumbnail_url'];
	$obj = $object_result['object_url'];
	$coordinatesLatLon = null;	
	//Need to put a check in here to avoid the undefined index error
      	if( isset($doc['mods_coordinates_p']) && $doc['mods_coordinates_p'] != '' && isset($doc['dc.title']) && isset($doc['dc.contributor'])){
              $withVal++;
	      if(array_key_exists($doc['mods_coordinates_p'], $newpins)){
			$tmpArr = $newpins[$doc['mods_coordinates_p']]; 
			$tmpArr[$doc['PID']] = array ("title" => $doc["dc.title"], "contrib" => $doc["dc.contributor"], "loc" => $doc["mods_physicalLocation_ms"],"desc" => $doc["dc.description"],"obj_url" => $obj,"thumb_url" => $thumb);
			$newpins[$doc['mods_coordinates_p']] = $tmpArr;
		} else {
		       if( isset($doc["mods_physicalLocation_ms"] )){
			$newpins[$doc['mods_coordinates_p']] = array( $doc['PID'] => array ("title" => $doc["dc.title"], "contrib" => $doc["dc.contributor"], "loc" => $doc["mods_physicalLocation_ms"],"desc" => $doc["dc.description"],"obj_url" => $obj,"thumb_url" => $thumb));
			}else{
			$newpins[$doc['mods_coordinates_p']] = array( $doc['PID'] => array ("title" => $doc["dc.title"], "contrib" => $doc["dc.contributor"] ,"desc" => $doc["dc.description"],"obj_url" => $obj,"thumb_url" => $thumb));
			}
			}
	  }else{
			$nopins[$doc['PID']] = array ("obj_url" => $obj,"thumb_url" => $thumb);
			if(isset($doc["dc.title"])){
				$nopins[$doc['PID']]["title"] = $doc["dc.title"]; 
			}			
			if(isset($doc["dc.contributor"])){
				$nopins[$doc['PID']]["contrib"] = $doc["dc.contributor"]; 
			}			
			if(isset($doc["dc.description"])){
				$nopins[$doc['PID']]["desc"] = $doc["dc.description"]; 
			}			
	  $withoutVal++; 
       	  }
}

$InfoForJS['pinsCount'] = $withVal;
$InfoForJS['nopinsCount'] = $withoutVal;


//drupal_set_message(print_r($newpins));
//Encode everything that goes to JS
$jsInfo = json_encode($InfoForJS);
$jnopins = json_encode($nopins);
$jpins = json_encode($newpins);
//drupal_set_message(print_r($nopins));
//drupal_set_message(print_r($jnopins));


drupal_add_js(array('islandora_map_browse_settings' => array('centre' => '52.1311, -106.6353')), 'setting');
drupal_add_js(array('islandora_map_browse_settings_pins' => $jpins), 'setting');
drupal_add_js(array('islandora_map_browse_settings_nopins' => $jnopins), 'setting');
drupal_add_js(array('islandora_map_browse_settings_jsInfo' => $jsInfo), 'setting');
//drupal_add_js(array('islandora_map_browse_settings_raw' => $res), 'setting');
    
    $output = '<div id="info_canvas" style="width:600px; height:60px;"></div><div id="map_canvas" style="width:600px; height:600px; float: left;"></div><div id="text_canvas" style="width:300px; height:600px; float: right; overflow: auto;"></div>';
   return $output;

  }

}

