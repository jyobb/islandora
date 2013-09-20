<?php
/*
error_reporting(E_ALL);
ini_set('display_errors', TRUE);
ini_set('display_startup_errors', TRUE);
*/


module_load_include('inc', 'islandora_solr_search', 'IslandoraSolrResults');

/**
 * Extention of IslandoraSolrResults for templating purposes.
 * This overrides the displayResults function to provide an alternate display type.
 */

class IslandoraSolrResultsMapView extends IslandoraSolrResults {

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

	 $response_data = $solrQueryProcessor->islandoraSolrResult['response'];
	 //Dump the following into drupal set message to see what your dealing with
	 $res = $solrQueryProcessor;
	 
	 //Set up the variables that get passed to javascript
	 $this->prepareVariables($solrQueryProcessor);

	 //This section resets the limits on the query and re-executes
	 $upperlimit = $solrQueryProcessor->islandoraSolrResult['response']['numFound'];
	 $lowerlimit = 0;
	 $increment = 5000;
	 $solrQueryProcessor->solrStart = $lowerlimit;
	 $solrQueryProcessor->solrLimit = $increment;

	 $solrQueryProcessor->resetResults();
	 $solrQueryProcessor->executeQuery();
	 $response_data = $solrQueryProcessor->islandoraSolrResult['response'];

	 $out = $this->prepareSolrResults($response_data);

return $out;

}//End of mapResult


  /**
   * @param $results
   *   A solr resultset object.
   *
   * @return
   *   html output for the resultset.
   */
function mapPageResults($solrQueryProcessor) {

	 $page = 0;
	 $url_args = array();
	 $url_args = parse_str(parse_url($_SERVER['HTTP_REFERER'], PHP_URL_QUERY));
	 $increment = 20;
	 $lowerlimit = ((($page + 1)*$increment)-$increment);

	 //Set up the variables that get passed to javascript
	 $this->prepareVariables($solrQueryProcessor);

	 //$queryInfoForJS = array();
	 $response_data = $solrQueryProcessor->islandoraSolrResult['response'];

	 //Dump the following into drupal set message to see what your dealing with var_dump to debug
	 $res = $solrQueryProcessor;

	 //This section resets the limits on the query and re-executes
	 $upperlimit = $solrQueryProcessor->islandoraSolrResult['response']['numFound'];

	 $solrQueryProcessor->solrStart = $lowerlimit;
	 $solrQueryProcessor->solrLimit = $increment;

	 $solrQueryProcessor->resetResults();
	 $solrQueryProcessor->executeQuery();
	 $response_data = $solrQueryProcessor->islandoraSolrResult['response'];

	 $out = $this->prepareSolrResults($response_data);

return $out;

}//End of mapPageResults


/**
 * @param $solrQueryProcessor
 * A solr query object
 *
 * @return nothing
 * Passes information needed by javascript to process results 
 */
function prepareVariables($solrQueryProcessor){

	 drupal_add_js(drupal_get_path('module', 'islandora_map_browse') . '/js/open_map_includes.js', 'file');
	 drupal_add_js(drupal_get_path('module', 'islandora_map_browse') . '/js/OpenLayers-2.12/OpenLayers.js', 'file');
	 $InfoForJS['qt'] = $solrQueryProcessor->solrQuery;
	 $InfoForJS['numFound'] = $solrQueryProcessor->islandoraSolrResult['response']['numFound'];
	 $InfoForJS['rows'] = $solrQueryProcessor->solrLimit;
	 $InfoForJS['baseUrl'] = "http://islandorasev-dev.usask.ca";
	 $InfoForJS['fedoraPrefix'] = "/islandora/object/";
	 $InfoForJS['fedoraSuffix'] = "/datastream/TN/view";
	 $InfoForJS['objectPrefix'] = "/islandora/object/";
	 $jsInfo = json_encode($InfoForJS);
	 drupal_add_js(array('islandora_map_browse_settings_jsInfo' => $jsInfo), 'setting');
}

/**
 * @params $solrResultSet
 *
 * @return HTML output
 *
 * This functions dedups the results of the query and send them to javascript
 * it also passes some information about the result sets
 *
 */ 
function prepareSolrResults ($response_data) {
$withVal = 0;
$withoutVal = 0;

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

$pinInfo['pinsCount'] = $withVal;
$pinInfo['nopinsCount'] = $withoutVal;

//Encode everything that goes to JS
$jsPinInfo = json_encode($pinInfo);
$jnopins = json_encode($nopins);
$jpins = json_encode($newpins);

drupal_add_js(array('islandora_map_browse_settings' => array('centre' => '52.1311, -106.6353')), 'setting');
drupal_add_js(array('islandora_map_browse_settings_pininfo' => $jsPinInfo), 'setting');
drupal_add_js(array('islandora_map_browse_settings_pins' => $jpins), 'setting');
drupal_add_js(array('islandora_map_browse_settings_nopins' => $jnopins), 'setting');


if($withoutVal == 0){
	       $output = '<div id="info_canvas" style="width:800px; height:60px;"></div><div id="map_canvas" style="width:800px; height:800px; float: left;"></div><div id="text_canvas" style="width:30px; height:600px; float: right; overflow: auto;"></div>';
}else{
    $output = '<div id="info_canvas" style="width:600px; height:60px;"></div><div id="map_canvas" style="width:600px; height:600px; float: left;"></div><div id="text_canvas" style="width:300px; height:600px; float: right; overflow: auto;"></div>';

}
   return $output;

}

}

