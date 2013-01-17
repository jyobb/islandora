<?php

/*
 * @file
 * Contains methods to search solr and display results.  depends on Apache_Solr_Php client.
 */

module_load_include('inc', 'islandora_solr_search', 'IslandoraSolrResults');

/**
 * Extention of IslandoraSolrResults for templating purposes.
 * This overrides the displayResults function to provide an alternate display type.
 */

class IslandoraSolrGlenbowCustom extends IslandoraSolrResults {

  static $facetSeparator = '~';//used to separate facets in url
  static $slashReplacement = '~slsh~';// a pattern used to replace / in url's the slash breaks drupal clean url's
  public static $SEARCH_CLASS_ADVANCED_SEARCH_NUMBER_FIELDS = 5;
  function IslandoraSolrResultsTable() {
    parent::__construct();
  }


  /**
   * Outputs results in unified tabular format.
   *
   * This function collects all field names from all results in the
   * resultset and constructs a single table with said field names in
   * a unified header row, rather than outputting each result as a
   * miniature horizontal table.
   *
   * @param $results
   *   A solr resultset object.
   *
   * @return
   *   html output for the resultset. Note: we currently create this
   *   output manually, should refactor to use drupal forms api.
   */
  function printResults($results) {
    // set variables
    $results_array = array();
    $elements = array();
    
    // total
    $elements['solr_total'] = $results->response->numFound;

    // start
    $elements['solr_start'] = $results->response->start;
    
    // get prepared search results
    $docs = $this->prep_results($results);
    
    // optionally limit results to values given
    $limitResults = variable_get('islandora_solr_search_limit_result_fields', 0);

    // loop over results array
    foreach ($docs as $doc) {
      $rows = array();
      $row = 0; // keeping $row in there for now until the snippet issue is cleared out
      $snippet = NULL; // @TODO: how is this suposed to work if the $snippet always is set to NULL ?

      /**
      * This is where you check the pid to see if you need to link directly
      * add more pids to this list if you want to have them link to the url
      * in the mods_location_url_ms field
      */
      $link_to_source = 0;
      if(strcmp(substr($doc['PID'],0,7), 'glenbow') == 0){
         $link_to_source = 1;
         $solr_object_link = $doc['PID'];
      } 

      // loop over individual results to process fields
      foreach ($doc as $field => $value) {

      if($link_to_source){
	if(strcmp("mods_location_url_ms", $field) == 0){ 
		$rows['imageLink']['label'] = 'hidden';
		$rows['imageLink']['value'] = $value[0];
	}
      }

        // check if this field should be included
        if ($limitResults && empty($this->resultFieldArray[$field])) {
          continue;
        }

        // check for field label substitutions
        $translated_field_name = isset($this->allSubsArray[$field]) ? $this->allSubsArray[$field] : $field;

        // add label
        $rows[$field]['label'] = $translated_field_name;

        // add class: render solr field name to string that can be used as class name
        $rows[$field]['class'] = strtolower( preg_replace('/[^A-Za-z0-9]/', '-', $field));

        // split value if the result value is an array
        if (is_array($value)) {
          $value = implode(", ", $value);
        }
        // add value
        $rows[$field]['value'] = $value;

        $row++; // keeping $row in there for now until the snippet issue is cleared out
      }
      //print_r($rows);
      
      // @TODO: how is this suposed to work if the $snippet always is set to NULL ?
      if ($snippet) {
        $rows[$row][] = array(
          'data' => 'Full Text',
          'header' => TRUE,
        );
        $rows[$row][] = $snippet[0];
      }
      // append array to results array
      $results_array[] = $rows;
    }

    // return themed search results
    return theme('islandora_solr_config_glenbow', $results_array, $elements);
  }
}
