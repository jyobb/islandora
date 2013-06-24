<?xml version="1.0" encoding="UTF-8"?> 
<!-- $Id: foxmlToSolr.xslt $ -->
<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"   
		xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
		xmlns:islandora-exts="xalan://ca.upei.roblib.DataStreamForXSLT"
		exclude-result-prefixes="exts islandora-exts"
		xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
		xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
		xmlns:rel="info:fedora/fedora-system:def/relations-external#"
		xmlns:fedora-model="info:fedora/fedora-system:def/model#"
		xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
		xmlns:foxml="info:fedora/fedora-system:def/foxml#"
		xmlns:dc="http://purl.org/dc/elements/1.1/"
		xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
		xmlns:xalan="http://xml.apache.org/xalan"
		xmlns:mods="http://www.loc.gov/mods/v3">

<!-- 		xmlns:islandora-exts="xalan://ca.upei.roblib.DataStreamForXSLT" -->

	<xsl:output method="xml" indent="yes" encoding="UTF-8"/>
<!--mods declaration added by john -->
<!--		xmlns:mods="http://www.loc.gov/mods/v3"> -->
<!--
	 This xslt stylesheet generates the Solr doc element consisting of field elements
     from a FOXML record. 
     You must specify the index field elements in solr's schema.xml file,
     including the uniqueKey element, which in this case is set to "PID".
     Options for tailoring:
       - generation of fields from other XML metadata streams than DC
       - generation of fields from other datastream types than XML
         - from datastream by ID, text fetched, if mimetype can be handled.
-->

	<xsl:param name="REPOSITORYNAME" select="repositoryName"/>
	<xsl:param name="FEDORASOAP" select="repositoryName"/>
	<xsl:param name="FEDORAUSER" select="repositoryName"/>
	<xsl:param name="FEDORAPASS" select="repositoryName"/>
	<xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
	<xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>
	<xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>

	<!-- following added by john -->
<!--	<xsl:include href="/usr/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/islandora_transforms/MODS_to_solr.xslt"/> -->


	<xsl:template match="/">
		<!-- The following allows only active FedoraObjects to be indexed. -->
		<xsl:if test="foxml:digitalObject/foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state' and @VALUE='Active']">
			<xsl:if test="not(foxml:digitalObject/foxml:datastream[@ID='METHODMAP'] or foxml:digitalObject/foxml:datastream[@ID='DS-COMPOSITE-MODEL'])">
				<xsl:if test="starts-with($PID,'')">
					<xsl:apply-templates mode="activeFedoraObject"/>
				</xsl:if>
			</xsl:if>
		</xsl:if>
		<!-- The following allows inactive FedoraObjects to be deleted from the index. -->
		<xsl:if test="foxml:digitalObject/foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state' and @VALUE='Inactive']">
			<xsl:if test="not(foxml:digitalObject/foxml:datastream[@ID='METHODMAP'] or foxml:digitalObject/foxml:datastream[@ID='DS-COMPOSITE-MODEL'])">
				<xsl:if test="starts-with($PID,'')">
					<xsl:apply-templates mode="inactiveFedoraObject"/>
				</xsl:if>
			</xsl:if>
		</xsl:if>
	</xsl:template>

	<xsl:template match="/foxml:digitalObject" mode="activeFedoraObject">
		<add> 
		<doc> 
			<field name="PID">
				<xsl:value-of select="$PID"/>
			</field>
			<field name="REPOSITORYNAME">
				<xsl:value-of select="$REPOSITORYNAME"/>
			</field>
			<field name="REPOSBASEURL">
				<xsl:value-of select="substring($FEDORASOAP, 1, string-length($FEDORASOAP)-9)"/>
			</field>
			<xsl:for-each select="foxml:objectProperties/foxml:property">
				<field>
					<xsl:attribute name="name"> 
						<xsl:value-of select="concat('fgs.', substring-after(@NAME,'#'))"/>
					</xsl:attribute>
					<xsl:value-of select="@VALUE"/>
				</field>
			</xsl:for-each>
		
			<xsl:for-each select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/oai_dc:dc/*">
				<field>
					<xsl:attribute name="name">
						<xsl:value-of select="concat('dc.', substring-after(name(),':'))"/>
						<xsl:text></xsl:text>
					</xsl:attribute>
					<xsl:value-of select="text()"/>
				</field>
			</xsl:for-each>

<!--
			<xsl:for-each select="$PARENT_MODS//mods:title">
			  <field>
			    <xsl:attribute name="name">
                              <xsl:value-of select="concat('PARENT_', local-name())"/>
			    </xsl:attribute>
			    <xsl:value-of select="normalize-space(text())"/>
			  </field>
			</xsl:for-each>   
-->
			<!-- a datastream is fetched, if its mimetype 
			     can be handled, the text becomes the value of the field.
			     This is the version using PDFBox,
			     below is the new version using Apache Tika. -->
			<!-- 
			<xsl:for-each select="foxml:datastream[@CONTROL_GROUP='M' or @CONTROL_GROUP='E' or @CONTROL_GROUP='R']">
				<field>
					<xsl:attribute name="name">
						<xsl:value-of select="concat('ds.', @ID)"/>
					</xsl:attribute>
					<xsl:value-of select="exts:getDatastreamText($PID, $REPOSITORYNAME, @ID, $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
				</field>
			</xsl:for-each>
			 -->

			<!-- Text and metadata extraction using Apache Tika. 
				Parameters for getDatastreamFromTika, getDatastreamTextFromTika, and getDatastreamMetadataFromTika:
				- indexFieldTagName		: either "IndexField" (with the Lucene plugin) or "field" (with the Solr plugin)
				- textIndexField		: fieldSpec for the text index field, null or empty if not to be generated								 (not used with getDatastreamMetadataFromTika)
				- indexfieldnamePrefix	: optional or empty, prefixed to the metadata indexfield names											 (not used with getDatastreamTextFromTika)
				- selectedFields		: comma-separated list of metadata fieldSpecs, if empty then all fields are included with default params (not used with getDatastreamTextFromTika)
				- fieldSpec				: metadataFieldName ['=' indexFieldName] ['/' [index] ['/' [store] ['/' [termVector] ['/' [boost]]]]]
						metadataFieldName must be exactly as extracted by Tika from the document. 

										  look for "METADATA name=" under "fullDsId=" in the log, when "getFromTika" was called during updateIndex
						indexFieldName is used as the generated index field name,
										  if not given, GSearch uses metadataFieldName after replacement of the characters ' ', ':', '/', '=', '(', ')' with '_'
						the following parameters are used with Lucene (with Solr these values are specified in schema.xml)
						index			: ['TOKENIZED'|'UN_TOKENIZED']	# first alternative is default
						store			: ['YES'|'NO']					# first alternative is default
						termVector		: ['YES'|'NO']					# first alternative is default
						boost			: <decimal number>				# '1.0' is default
			-->
<!--
			<xsl:for-each select="foxml:datastream[@ID='MODS']">
			  <field>
				<xsl:value-of disable-output-escaping="yes" select="exts:getDatastreamFromTika($PID, $REPOSITORYNAME, @ID, 'field', concat('mods.', @ID), concat('mod_', @ID, '.'), '', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
</field>
			</xsl:for-each>
-->

<!-- Tika can grab the other datastreams for indexing I may need to do this for the xcaml stuff -->
<!--
			<xsl:variable name="PARENT_MODS" select="islandora-exts:getXMLDatastreamASNodeList($PID, $REPOSITORYNAME, 'MODS', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
-->
<!-- IMAGE DATA
			<xsl:for-each select="foxml:datastream[@CONTROL_GROUP='M' or @CONTROL_GROUP='E' or @CONTROL_GROUP='R']">
				<xsl:value-of disable-output-escaping="yes" select="exts:getDatastreamFromTika($PID, $REPOSITORYNAME, @ID, 'field', concat('ds.', @ID), concat('dsmd_', @ID, '.'), '', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
			</xsl:for-each>
	-->		

			<!-- 
			creating an index field with all text from the foxml record and its datastreams
			-->
<!-- ALL TEXT
 			<field name="foxml.all.text">
				<xsl:for-each select="//text()">
					<xsl:value-of select="."/>
					<xsl:text>&#160;</xsl:text>
				</xsl:for-each>
				<xsl:for-each select="//foxml:datastream[@CONTROL_GROUP='M' or @CONTROL_GROUP='E' or @CONTROL_GROUP='R']">
					<xsl:value-of select="exts:getDatastreamText($PID, $REPOSITORYNAME, @ID, $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
					<xsl:text>&#160;</xsl:text>
				</xsl:for-each>
			</field>

			<field name="mods.all">
			<xsl:value-of select="islandora-exts:getDatastreamTextRaw($PID, $REPOSITORYNAME, 'MODS', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
			</field>
-->			
			   <xsl:variable name="PARENT_MODS" as="element()" select="islandora-exts:getXMLDatastreamASNodeList($PID, $REPOSITORYNAME, 'MODS', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
			   <!-- define the mods prefixes --> 
			       <xsl:variable name="prefix">mods_</xsl:variable>
			       <xsl:variable name="suffix">_ms</xsl:variable>
			   <!--The following is for testing 
			       <field name="dump">
				 <xsl:copy-of select="$PARENT_MODS"/>
			       </field>
-->
			   <!-- This is where i get the mods.  it would be better in another template but i dont have time to sort it out. -->

			   <xsl:for-each select="$PARENT_MODS//title">
			     <field>
			       <xsl:attribute name="name">
				 <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
			       </xsl:attribute>
			       <xsl:if test="../nonSort">
				 <xsl:value-of select="../nonSort/text()"/>
				 <xsl:text> </xsl:text>
			       </xsl:if>
			       <xsl:value-of select="text()"/>
			     </field>	
			     <field>
			       <xsl:attribute name="name">
				 <xsl:value-of select="concat($prefix, local-name(), '_mlt')"/>
			       </xsl:attribute>
			       <xsl:if test="../nonSort">
				 <xsl:value-of select="../nonSort/text()"/>
				 <xsl:text> </xsl:text>
			       </xsl:if>
			       <xsl:value-of select="text()"/>
			     </field>
			     </xsl:for-each>

			   <xsl:for-each select="$PARENT_MODS//note">
			     <field>
			       <xsl:attribute name="name">
				 <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
			       </xsl:attribute>
			       <xsl:value-of select="text()"/>
			     </field>
			     <field>
			       <xsl:attribute name="name">
				 <xsl:value-of select="concat($prefix, local-name(), '_mlt')"/>
			       </xsl:attribute>
			       <xsl:value-of select="text()"/>
			     </field>
			   </xsl:for-each>


			   <!-- Sub-title -->
			   <xsl:for-each select="$PARENT_MODS//subTitle">
			     <field>
			       <xsl:attribute name="name">
				 <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
			       </xsl:attribute>
			       <xsl:value-of select="text()"/>
			     </field>
			     <field>
			       <xsl:attribute name="name">
				 <xsl:value-of select="concat($prefix, local-name(), '_mlt')"/>
			       </xsl:attribute>
			       <xsl:value-of select="text()"/>
			     </field>
			   </xsl:for-each>

			   <!-- Abstract -->
			   <xsl:for-each select="$PARENT_MODS//abstract[normalize-space(text())]">
			     <field>
			       <xsl:attribute name="name">
				 <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
			       </xsl:attribute>
			       <xsl:value-of select="text()"/>
			     </field>
			   </xsl:for-each>
			   
			   <!-- Genre (a.k.a. specific doctype) -->
			   <xsl:for-each select="$PARENT_MODS//genre[normalize-space(text())]">
			     <xsl:variable name="authority">
			       <xsl:choose>
				 <xsl:when test="@authority">
				   <xsl:value-of select="concat('_', @authority)"/>
				 </xsl:when>
				 <xsl:otherwise>
				   <xsl:text>_local_authority</xsl:text>
				 </xsl:otherwise>
			       </xsl:choose>
			     </xsl:variable>
			     <field>
			       <xsl:attribute name="name">
				 <xsl:value-of select="concat($prefix, local-name(), $authority, $suffix)"/>
			       </xsl:attribute>
			       <xsl:value-of select="text()"/>
			     </field>
			   </xsl:for-each>
			   
			   <!-- Resource Type (a.k.a. broad doctype)-->
			   <xsl:for-each select="$PARENT_MODS//typeOfResource[normalize-space(text())]">
			     <field>
			       <xsl:attribute name="name">
				 <xsl:value-of select="concat($prefix, 'resource_type', $suffix)"/>
			       </xsl:attribute>
			       <xsl:value-of select="text()"/>
			     </field>
			   </xsl:for-each>
			   

    <xsl:for-each select="$PARENT_MODS//identifier[@type][normalize-space(text())]">
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, local-name(), '_', translate(@type, ' ', '_'), $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="text()"/>
    </field>
    </xsl:for-each>

    <!-- Names and Roles
    @TODO: examine if formating the names is necessary?-->
    <xsl:for-each select="$PARENT_MODS//name[namePart and role]">
      <xsl:variable name="role" select="$PARENT_MODS//role/roleTerm/text()"/>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'name_', $role, $suffix)"/>
        </xsl:attribute>
        <!-- <xsl:for-each select="../../mods:namePart[@type='given']">-->
        <xsl:for-each select="namePart[@type='given']">
          <xsl:value-of select="text()"/>
          <xsl:if test="string-length(text())=1">
            <xsl:text>.</xsl:text>
          </xsl:if>
          <xsl:text> </xsl:text>
        </xsl:for-each>
        <xsl:for-each select="namePart[not(@type='given')]">
          <xsl:value-of select="text()"/>
          <xsl:if test="position()!=last()">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </field>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'reversed_name_', $role, $suffix)"/>
        </xsl:attribute>
        <xsl:for-each select="namePart[not(@type='given')]">
          <xsl:value-of select="text()"/>
        </xsl:for-each>
        <xsl:for-each select="namePart[@type='given']">
          <xsl:if test="position()=1">
            <xsl:text>, </xsl:text>
          </xsl:if>
          <xsl:value-of select="text()"/>
          <xsl:if test="string-length(text())=1">
            <xsl:text>.</xsl:text>
          </xsl:if>
          <xsl:if test="position()!=last()">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </field>
    </xsl:for-each>

    <!-- Notes with no type -->
    <xsl:for-each select="$PARENT_MODS//note[not(@type)][normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Notes -->
    <xsl:for-each select="$PARENT_MODS//note[@type][normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_', translate(@type, ' ', '_'), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Subjects / Keywords -->
    <xsl:for-each select="$PARENT_MODS//subject[not(@displayLabel)][normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Immediate children of Subjects / Keywords -->
    <xsl:for-each select="$PARENT_MODS//subject[not(@displayLabel)]/*[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'subject_', local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Subjects / Keywords with displaylabel -->
    <xsl:for-each select="$PARENT_MODS//subject[@displayLabel][normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_', translate(@displayLabel, ' ', '_'), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Immediate children of Subjects / Keywords with displaylabel -->
    <xsl:for-each select="$PARENT_MODS//subject[@displayLabel]/*[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'subject_', local-name(), '_', translate(../@displayLabel, ' ', '_'), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Coordinates (lat,long) -->
    <xsl:for-each select="$PARENT_MODS//subject/mods:cartographics/mods:coordinates[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_p')"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Coordinates (lat,long) -->
    <xsl:for-each select="$PARENT_MODS//subject/topic[../cartographics/text()][normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'cartographic_topic', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Country -->
    <xsl:for-each select="$PARENT_MODS//country[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <xsl:for-each select="$PARENT_MODS//province[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <xsl:for-each select="$PARENT_MODS//county[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <xsl:for-each select="$PARENT_MODS//region[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <xsl:for-each select="$PARENT_MODS//city[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <xsl:for-each select="$PARENT_MODS//citySection[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <xsl:for-each select="$PARENT_MODS//cartographics/coordinates[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>



    <!-- Host Name (i.e. journal/newspaper name) -->
    <xsl:for-each select="$PARENT_MODS//relatedItem[@type='host']/titleInfo/title[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'host_title', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Series Name (this means, e.g. a lecture series and is rarely used) -->
    <xsl:for-each select="$PARENT_MODS//relatedItem[@type='series']/titleInfo/title[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'series_title', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Volume (e.g. journal vol) -->
    <xsl:for-each select="$PARENT_MODS//part/detail[@type='volume']/*[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'volume', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Issue (e.g. journal vol) -->
    <xsl:for-each select="$PARENT_MODS//part/detail[@type='issue']/*[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'issue', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Subject Names -->
    <xsl:for-each select="$PARENT_MODS//subject/name/namePart/*[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'subject', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Physical Description -->
    <xsl:for-each select="$PARENT_MODS//physicalDescription[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Physical Description (note) -->
    <xsl:for-each select="$PARENT_MODS//physicalDescription/note[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'physical_description_', local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Physical Description (form) -->
    <xsl:for-each select="$PARENT_MODS//physicalDescription/form[@type][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'physical_description_', local-name(), '_', @type, $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Location -->
    <xsl:for-each select="$PARENT_MODS//location[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Location (physical) -->
    <xsl:for-each select="$PARENT_MODS//location/physicalLocation[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Location (url) -->
    <xsl:for-each select="$PARENT_MODS//location/url[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'location_', local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>


    <!-- Publisher's Name -->
    <xsl:for-each select="$PARENT_MODS//originInfo/publisher[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Edition (Book) -->
    <xsl:for-each select="$PARENT_MODS//originInfo/edition[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Date Issued (i.e. Journal Pub Date) -->
    <xsl:for-each select="$PARENT_MODS//originInfo/dateIssued[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
      <xsl:if test="position() = 1"><!-- use the first for a sortable field -->
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, local-name(), '_s')"/>
          </xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:if>
    </xsl:for-each>

    <!-- Date Captured -->
    <xsl:for-each select="$PARENT_MODS//originInfo/dateCaptured[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
      <xsl:if test="position() = 1"><!-- use the first for a sortable field -->
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, local-name(), '_s')"/>
          </xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:if>
    </xsl:for-each>

    <!-- Date Captured -->
    <xsl:for-each select="$PARENT_MODS//originInfo/dateCreated[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
      <xsl:if test="position() = 1"><!-- use the first for a sortable field -->
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, local-name(), '_s')"/>
          </xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:if>
    </xsl:for-each>

    <!-- Copyright Date (is an okay substitute for Issued Date in many circumstances) -->
    <xsl:for-each select="$PARENT_MODS//originInfo/copyrightDate[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Issuance (i.e. ongoing, monograph, etc. ) -->
    <xsl:for-each select="$PARENT_MODS//originInfo/issuance[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Languague Term -->
    <xsl:for-each select="$PARENT_MODS//language/languageTerm[@authority='iso639-2b' and type='code'][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Access Condition -->
    <xsl:for-each select="$PARENT_MODS//accessCondition[normalize-space(text())]">
      <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>



			   
			   <!-- this was for testing -->
<!--
			   <xsl:for-each select="$PARENT_MODS//title">
			    <field>
			      <xsl:attribute name="mods.name">
				<xsl:value-of select="concat('PARENT_', local-name())"/>				
			      </xsl:attribute>
			      <xsl:value-of select="text()"/>
			    </field>
			    </xsl:for-each>		
-->	
			    <!--  <xsl:value-of select="normalize-space(text())"/> -->

			
		</doc>
		</add>
	</xsl:template>

	<xsl:template match="/foxml:digitalObject" mode="inactiveFedoraObject">
		<delete> 
			<id><xsl:value-of select="$PID"/></id>
		</delete>
	</xsl:template>
	
</xsl:stylesheet>	
