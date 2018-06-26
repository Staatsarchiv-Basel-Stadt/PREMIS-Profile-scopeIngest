<?xml version="1.0" encoding="UTF-8"?>
<!-- ***************************
	 eCH-0160-SIP-to-PREMIS.xslt
	 ***************************
     XSLT template to create PREMIS-metadata in a scopeIngest process with eCH-0160 SIP metadata and file preservation information from DROID. This
     transformation is conceptually part of step 3 "AIP und DI erstellen" in the ingest module of scopeArchiv. It is based on the original template
     "BENTO-xISADg_premis_GEVER.xslt" from scope.

     Notes
     =====
     * all references to the creation of xISADg-files have been removed
     * input paths have been adapted
     * naming convention of files have not been changed
     * output directory has been changed, metadata files are stored in directory '../data-out', followed by the same pattern
       (aip-xxxxxxxx-xxx/metadaten/*.*)
     * in 'metadata.xml' and 'IngestProcessData.xml', the path to the xsd schema file has to be adapted to a relative one, i.e. './xsd/*.xsd'
     * Schema validation has to be set to "lax" in Saxon EE configuration

      Changes
      =======

      17.05.2018 : oliver.schihin@bs.ch : change value of "objectIdentifierType" to 'xmlID'
                   oliver.schihin@bs.ch : Add second fixity block to transport MD5-hash from DROID
      04.06.2018 : oliver.schihin@bs.ch : Change content location value
                   oliver.schihin@bs.ch : Begin work on implementing controlled vocabularies (from LC)
		  26.06.2018 : oliver.schihin@bs.ch : Preparing publication as reference implementation
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	            xmlns:xs="http://www.w3.org/2001/XMLSchema"
	            xmlns:fn="http://www.w3.org/2005/xpath-functions"
	            xmlns:isadg="ISADG"
	            xmlns:arelda="http://bar.admin.ch/arelda/v4"
	            xmlns:premis="info:lc/xmlns/premis-v2"
	            xmlns:scope="http://www.scope.ch"
	            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	            exclude-result-prefixes="scope fn arelda premis isadg xs xsi">
	<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

    <!-- =================
    	 OUTPUT PATH PARTS
    	 =================
    -->
	<!-- output folder containg the metadata -->
	<xsl:param name="output-file-relative-path" select="xs:string('metadaten')"
	/>
	<!-- name of PREMIS file-->
	<xsl:param name="premis-file-name" select="xs:string('premis.xml')"/>

	<!-- ===================
	     ADDITIONAL XML DATA
	     ===================
	     * load additional XML trees for further processing
         * paths have to be adapted to local system
	-->
	<!-- primary data identification information (DROID) -->
	<xsl:param name="identify-file-path"
               select="xs:string('file:///home/ssvasco/Dokumente/Code_and_Scripts/scopeIngest/premis-mapping/data-in/Droid6_IdentifyReport.xml')"
	/>
	<!-- file containing the ingest process information -->
	<xsl:param name="ingest-process-data-path"
		       select="xs:string('file:///home/ssvasco/Dokumente/Code_and_Scripts/scopeIngest/premis-mapping/data-in/IngestProcessData.xml')"
	/>
	<!-- load external file trees to variables for later use -->
	<xsl:variable name="files-formats-recognition" select="doc($identify-file-path)"
	/>
	<xsl:variable name="ingest-process-data" select="doc($ingest-process-data-path)"
	/>
	<!-- ==============
		 START TEMPLATE
	     ==============
	-->
	<xsl:template match="/">
		<!-- output some information about the XSL engine -->
		<xsl:comment>
			<xsl:text>product: </xsl:text>
			<xsl:value-of select="system-property('xsl:product-name')"/>
			<xsl:text> </xsl:text>
			<xsl:value-of select="system-property('xsl:product-version')"/>
			<xsl:text> </xsl:text>
			<xsl:text>schema-aware?: </xsl:text>
			<xsl:value-of select="system-property('xsl:is-schema-aware')"/>
		</xsl:comment>
		<!-- root of the information result XML -->
		<AIPGenerationResultFiles>
			<xsl:apply-templates/>
		</AIPGenerationResultFiles>
	</xsl:template>
	<!-- template to match all topmost dossiers or, said differently, all dossiers that do not have a dossier as a parent and at least contain one document
		 containing at least a dateiRef element (ablieferungGeverSIP) or contain a dossier containing at least a dateiRef element (ablieferungFilesSIP)
	-->
	<xsl:template match="arelda:dossier[not(ancestor::arelda:dossier)][arelda:dokument/arelda:dateiRef] |
		                 arelda:dossier[not(ancestor::arelda:dossier)][arelda:dateiRef]">
		<!-- generate an XML fragment and store it in a variable with all files references under the current dossier at all levels for later use -->
		<xsl:variable name="file-references">
			<xsl:apply-templates select="arelda:dateiRef | descendant::arelda:dossier/arelda:dateiRef  | descendant::arelda:dokument/arelda:dateiRef"
				                 mode="fileRef"
			/>
		</xsl:variable>
		<!-- get AIP PID without the ISIL Code from IngestProcessData.xml associated with the dossier ID -->
		<xsl:variable name="aip-pid">
			<xsl:value-of select="fn:id(@id,$ingest-process-data)/scope:PID"/>
		</xsl:variable>
		<!-- if the AIP PID is not defined, do not continue -->
		<xsl:if test="$aip-pid[normalize-space()]">
			<!-- compute the relative paths to the metadata files and schemas to be used later in the AIP generation -->
			<xsl:variable name="premis-metadata-file-path" select="scope:get-filename($aip-pid,$premis-file-name)"/>
			<xsl:variable name="premis-schema-file-relative-path" select="xs:string('xsd/premis/premis-v2-1.xsd')"/>
			<!-- load list with all files (datei) from "inhaltsverzeichnis" part of the metadata.xml referenced under this sub-branch -->
			<xsl:variable name="referenced-files" select="//arelda:datei[@id=$file-references/file/@BentoID]"/>
			<outputdir id="{fn:id(@id,$ingest-process-data)/@UoDid}" aipdir="{$aip-pid}" source-id="{@id}">
				<!-- info about the PREMIS metadata file generated -->
				<primarydatametadafilepath type="metadata"
					filename="{$premis-file-name}"
					schemafilerelativepath="{$premis-schema-file-relative-path}">
					<xsl:value-of select="$premis-metadata-file-path"/>
				</primarydatametadafilepath>
				<!-- list of referenced files -->
				<xsl:apply-templates select="$referenced-files" mode="result"/>
			</outputdir>

			<!-- ========================
				 PREMIS METADATA ELEMENTS
				 ========================
			-->
			<xsl:result-document href="../data-out/{$premis-metadata-file-path}" exclude-result-prefixes="isadg">
				<premis:premis xsi:schemaLocation="info:lc/xmlns/premis-v2 {$premis-schema-file-relative-path}"
					           version="2.1"
					           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
					           xmlns:premis="info:lc/xmlns/premis-v2">
					<!-- object list with AIP-PID -->
					<xsl:apply-templates select="$referenced-files" mode="premis">
						<xsl:with-param name="file-references" select="$file-references"/>
						<xsl:with-param name="aip-pid" select="$aip-pid" tunnel="yes"/>
					</xsl:apply-templates>
					<!-- default event -->
					<xsl:call-template name="premis-event">
						<xsl:with-param name="file-references" select="$file-references"/>
					</xsl:call-template>
					<!-- default agent -->
					<xsl:call-template name="premis-agent"/>
				</premis:premis>
			</xsl:result-document>
		</xsl:if>
	</xsl:template>

	<!-- =================
		 RESULT  TEMPLATES
		 =================
	-->
	<!-- template to generate the list of objects in the result xml -->
	<xsl:template match="arelda:datei" mode="result">
		<file id="{@id}" type="primarydata">
			<xsl:apply-templates select="arelda:name" mode="premis"/>
		</file>
	</xsl:template>
	<!-- ================
		 PREMIS TEMPLATES
		 ================
	-->
	<!-- template to generate a PREMIS object element based on an eCH-0160 datei element -->
	<xsl:template match="arelda:datei" mode="premis">
		<xsl:param name="file-references" />
		<xsl:param name="aip-pid" tunnel="yes" />
		<!-- relative path of file: call a template on the file name to generate the relative path based on the position inside the inhaltsverzeichnis in
			 eCH-0160
		-->
		<xsl:variable name="file-relative-path">
			<xsl:apply-templates select="arelda:name" mode="premis"/>
		</xsl:variable>
		<!-- get the identification information from "IdentifyReport.xml" based on the relative path of the file -->
		<xsl:variable name="identification-info"
			          select="$files-formats-recognition//IdentificationFile[file_path[ends-with(.,translate($file-relative-path,'/','\'))]]"
		/>
		<!-- comment to test ID generation -->
		<xsl:comment>
			<xsl:value-of select="concat('object-id_',position())"/>
		</xsl:comment>
		<!-- PREMIS:object -->
		<!-- in the files references XML fragment find the one that matches the current datei ID and get the PREMIS ID of it and use it for the xmlID -->
		<premis:object xsi:type="premis:file" xmlID="{$file-references/file[@BentoID=current()/@id]/@premisID}">
			<premis:objectIdentifier>
				<!-- new value definition: 'xmlID' -->
				<premis:objectIdentifierType>xmlID</premis:objectIdentifierType>
				<premis:objectIdentifierValue>
					<xsl:value-of select="@id"/>
				</premis:objectIdentifierValue>
			</premis:objectIdentifier>
			<premis:objectCharacteristics>
				<premis:compositionLevel>0</premis:compositionLevel>
				<!-- two fixity blocks: first from SIP (metadata.xml), second from file identification -->
				<premis:fixity>
					<premis:messageDigestAlgorithm>
						<xsl:value-of select="arelda:pruefalgorithmus"/>
					</premis:messageDigestAlgorithm>
					<premis:messageDigest>
						<xsl:value-of select="arelda:pruefsumme"/>
					</premis:messageDigest>
					<premis:messageDigestOriginator>
						<xsl:text>SIP</xsl:text>
					</premis:messageDigestOriginator>
				</premis:fixity>
				<premis:fixity>
					<premis:messageDigestAlgorithm>
						<xsl:text>MD5</xsl:text>
					</premis:messageDigestAlgorithm>
					<premis:messageDigest>
						<xsl:value-of select="$identification-info/md5_hash"/>
					</premis:messageDigest>
					<premis:messageDigestOriginator>
						<xsl:text>ingest</xsl:text>
					</premis:messageDigestOriginator>
				</premis:fixity>
				<premis:size>
					<xsl:value-of select="$identification-info/size"/>
				</premis:size>
				<premis:format>
					<premis:formatDesignation>
						<premis:formatName>
							<xsl:value-of select="$identification-info/format_name"/>
						</premis:formatName>
						<premis:formatVersion>
							<xsl:value-of select="$identification-info/format_version"/>
						</premis:formatVersion>
					</premis:formatDesignation>
					<premis:formatRegistry>
						<premis:formatRegistryName>PRONOM</premis:formatRegistryName>
						<premis:formatRegistryKey>
							<xsl:value-of select="$identification-info/puid"/>
						</premis:formatRegistryKey>
					</premis:formatRegistry>
				</premis:format>
			</premis:objectCharacteristics>
			<premis:storage>
				<premis:contentLocation>
					<premis:contentLocationType>URI</premis:contentLocationType>
					<!-- output full URN to the file -->
					<premis:contentLocationValue>
						<xsl:variable name="ISIL">
							<xsl:value-of select="$ingest-process-data/scope:IngestProcessData/scope:IngestSettings/scope:Archive_ISIL_Code/@value"/>
						</xsl:variable>
						<xsl:variable name="DOC">
							<xsl:value-of select="fn:id(@id,$ingest-process-data)/scope:RelativeUri/text()" />
						</xsl:variable>
						<xsl:value-of select="concat('urn:',$ISIL,':',$aip-pid,'/primaerdaten/',$DOC)"/>
					</premis:contentLocationValue>
				</premis:contentLocation>
			</premis:storage>
			<!-- use a default event identifier (event-id_1) as this XSLT transformation is always used for an initial ingest -->
			<premis:linkingEventIdentifier>
				<premis:linkingEventIdentifierType>xmlID</premis:linkingEventIdentifierType>
				<premis:linkingEventIdentifierValue>event-id_1</premis:linkingEventIdentifierValue>
			</premis:linkingEventIdentifier>
		</premis:object>
	</xsl:template>
	<!-- template to generate the file relative path by traversing upwards the elements (ordner) containig the file name and concatenating the values -->
	<xsl:template match="arelda:name" mode="premis">
		<xsl:if test="not(parent::*/parent::arelda:ordner/parent::arelda:inhaltsverzeichnis)">
			<xsl:apply-templates select="parent::*/parent::*/arelda:name" mode="premis"/>
			<xsl:text>/</xsl:text>
		</xsl:if>
		<xsl:value-of select="."/>
	</xsl:template>
	<!-- PREMIS: event -->
	<!-- template to generate the default event for the this initial ingest -->
	<xsl:template name="premis-event">
		<xsl:param name="file-references"/>
		<premis:event xmlID="event-id_1">
			<premis:eventIdentifier>
				<premis:eventIdentifierType>xmlID</premis:eventIdentifierType>
				<premis:eventIdentifierValue>event-id_1</premis:eventIdentifierValue>
			</premis:eventIdentifier>
			<premis:eventType>ingest</premis:eventType>
			<!--2013-05-29T15:23:24 format-dateTime(current-time(), '[Y0001]-[M01]-[D01]')-->
			<premis:eventDateTime>
				<xsl:value-of select="current-dateTime()"/>
			</premis:eventDateTime>
			<!--premis:eventDetail-->
			<!-- scope ingest process ID is used as event detail -->
			<premis:eventDetail>
				<xsl:value-of select="concat('Prozess-ID scopeIngest: ', $ingest-process-data/scope:IngestProcessData/scope:IngestSettings/@id)"/>
			</premis:eventDetail>
			<premis:eventOutcomeInformation>
				<premis:eventOutcomeDetail>
					<!--premis:eventOutcomeDetailNote-->
					<!-- full PID with ISIL code for the outcome detail note -->
					<premis:eventOutcomeDetailNote>
						<xsl:value-of select="concat($ingest-process-data/scope:IngestProcessData/scope:IngestSettings/scope:Archive_ISIL_Code/@value,':',id(@id,$ingest-process-data)/scope:PID)"/>
					</premis:eventOutcomeDetailNote>
				</premis:eventOutcomeDetail>
			</premis:eventOutcomeInformation>
			<premis:linkingAgentIdentifier>
				<premis:linkingAgentIdentifierType>xmlID</premis:linkingAgentIdentifierType>
				<!--premis:linkingAgentIdentifierValue-->
				<!-- default agent -->
				<premis:linkingAgentIdentifierValue>agent-id_1</premis:linkingAgentIdentifierValue>
				<!-- value from LOC controlled vocabulary -->
				<premis:linkingAgentRole>implementer</premis:linkingAgentRole>
			</premis:linkingAgentIdentifier>
			<!-- link all premis objects to this event -->
			<xsl:for-each select="$file-references/file">
				<premis:linkingObjectIdentifier>
					<premis:linkingObjectIdentifierType>xmlID</premis:linkingObjectIdentifierType>
					<premis:linkingObjectIdentifierValue>
						<xsl:value-of select="@premisID"/>
					</premis:linkingObjectIdentifierValue>
				</premis:linkingObjectIdentifier>
			</xsl:for-each>
		</premis:event>
	</xsl:template>
	<!-- PREMIS: event -->
	<!-- template to output the default agent -->
	<xsl:template name="premis-agent">
		<xsl:param name="external-data"/>
		<premis:agent>
			<premis:agentIdentifier>
				<premis:agentIdentifierType>xmlID</premis:agentIdentifierType>
				<premis:agentIdentifierValue>agent-id_1</premis:agentIdentifierValue>
			</premis:agentIdentifier>
			<!--premis:agentName-->
			<!-- scope user name is used -->
			<premis:agentName>
				<xsl:value-of select="$ingest-process-data/scope:IngestProcessData/scope:IngestSettings/scope:User/scope:UserName"/>
			</premis:agentName>
			<!--premis:agentType -->
			<!-- scope user type is used -->
			<premis:agentType>
				<xsl:value-of select="$ingest-process-data/scope:IngestProcessData/scope:IngestSettings/scope:User/scope:UserType"/>
			</premis:agentType>
			<premis:linkingEventIdentifier>
				<premis:linkingEventIdentifierType>xmlID</premis:linkingEventIdentifierType>
				<premis:linkingEventIdentifierValue>event-id_1</premis:linkingEventIdentifierValue>
			</premis:linkingEventIdentifier>
		</premis:agent>
	</xsl:template>

	<!-- =============================
		 GENERAL TEMPLATES / FUNCTIONS
	     =============================
	-->
	<!-- template to generate the XML fragment with the list of all files references belonging to the descendants of a given ordunungsystemposition -->
	<xsl:template match="arelda:dateiRef" mode="fileRef">
		<file premisID="{concat('object-id_',position())}" BentoID="{.}"/>
	</xsl:template>
	<!-- template to overrride default template, catch all text and supress output -->
	<xsl:template match="text()"/>
	<!-- function to generate the AIP relative path(s) for the file(s) that will be generated as a result of running this transformation sheet -->
	<xsl:function name="scope:get-filename">
		<xsl:param name="aip-pid"/>
		<xsl:param name="file-name"/>
		<xsl:value-of select="concat($aip-pid,'/',$output-file-relative-path,'/',$file-name)"/>
	</xsl:function>
</xsl:stylesheet>
