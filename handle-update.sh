#!/bin/bash
# handle a Fedora update message

function handleRDFSource() {
		# download the graph and copy it to graph store
		# download the updated resource from Fedora
		echo Updated Fedora resource is an RDF resource and will be copied to the graph store
		echo Downloading RDF/XML from Fedora resource $updatedResourceURI ...
		curl -s -S --header "Accept: application/rdf+xml" -o temp/updated-resource.rdf $updatedResourceURI
		echo Storing resource graph in graph store as $updatedResourceURI
		# save the updated resource as a named graph in SPARQL store
		curl -H "Content-Type: application/rdf+xml" -X PUT --data-binary @temp/updated-resource.rdf http://localhost:8080/fuseki/prov/data?graph=$updatedResourceURI
}	

function handleFedoraMetadata() {
		metadataURI=$updatedResourceURI/fcr:metadata
		echo Downloading RDF/XML from the metadata resource $metadataURI
		curl -s -S --header "Accept: application/rdf+xml" -o temp/updated-resource.rdf $metadataURI
		echo Updating resource graph in graph store as $metadataURI
		# save the updated resource as a named graph in SPARQL store
		curl -H "Content-Type: application/rdf+xml" -X PUT --data-binary @temp/updated-resource.rdf http://localhost:8080/fuseki/prov/data?graph=$metadataURI
}	

function handleCSV() {
			# Regenerate RDF from CSV
			echo "Updated Fedora resource is CSV;  if a related CSVW metadata resource can be found, it will be used to extract RDF from this CSV"
			# Check the SPARQL store to find associated CSVW metadata resource
			# For now, assume only 1, though it might be worth allowing for multiple interpretations of a single CSV.
			curl -X POST -H "Content-Type: application/sparql-query" -H "Accept: text/csv" --upload-file "sparql/find-csvw-metadata.rq" http://localhost:8080/fuseki/prov/query | tail -n +2 > temp/csvw-metadata.csv
			csvwMetadata=`cat temp/csvw-metadata.csv | tr -d '[:space:]'`
			# execute CSV2RDF to generate RDF, deposit RDF in graph store
			# e.g.
			# csv2rdf --schema=http://fedora-dev.prov.vic.gov.au:8080/rest/sources/trains/trains-schema.jsonld > csv-rdf.ttl
			if [[ "$csvwMetadata" == "" ]]; then
				echo "Cannot find a metadata resource with which to extract RDF from resource $updateResourceURI"
			else
				echo "The CSV resource has a related CSVW metadata resource at $csvwMetadata"
				csv2rdf --schema=$csvwMetadata > temp/raw-csv-rdf.ttl

				#remove validation warnings from the turtle file output by csv2rdf
				sed '0,/^@/ {/^[^@]/ d}' temp/raw-csv-rdf.ttl > temp/csv-rdf.ttl

				# save data extracted from the CSV as a named graph in SPARQL store, named by the URI of the metadata resource which was used to extract it
				echo "Storing CSV-derived RDF in graph store as $csvwMetadata"
				curl -H "Content-Type: text/turtle" -X PUT --data-binary @temp/csv-rdf.ttl http://localhost:8080/fuseki/prov/data?graph=$csvwMetadata
				#TODO append Provenance metadata describing the csv2rdf conversion  
			fi
}	

function handleCSVM() {
			echo Updated Fedora resource is a CSV-on-the-Web metadata resource. It will be stored and also used to generate an RDF representation of a related CSV file.
			# Download CSVW metadata and copy to graph store
			echo Retrieving CSVM resource from $updatedResourceURI
			curl -s -S -o temp/updated-resource.jsonld $updatedResourceURI
			# Fuseki won't accept JSON-LD, so convert it to RDF/XML
			rdfconvert-0.4/bin/rdfconvert.sh -i JSON-LD -o RDF/XML temp/updated-resource.jsonld temp/updated-resource.rdf
			# Store the CSVM in the SPARQL store
			echo "Storing CSVM resource in graph store"
			curl -H "Content-Type: application/rdf+xml" -X PUT --data-binary @temp/updated-resource.rdf http://localhost:8080/fuseki/prov/data?graph=$updatedResourceURI

			# execute CSV2RDF to generate RDF, deposit RDF in graph store
			# e.g.
			# csv2rdf --schema=http://fedora-dev.prov.vic.gov.au:8080/rest/sources/trains/trains-schema.jsonld > csv-rdf.ttl
			# The metadata file must refer to a locally-patched CSVW context because the standard context contains a bug:  https://github.com/w3c/csvw/issues/849
			csv2rdf --schema=$updatedResourceURI > temp/raw-csv-rdf.ttl
			#TODO error handling: what if the linked CSV is not found, or an error occurs in generation?

			#remove validation comments from the turtle file output by csv2rdf
			sed '0,/^@/ {/^[^@]/ d}' temp/raw-csv-rdf.ttl > temp/csv-rdf.ttl

			# save data extracted from the CSV as a named graph in SPARQL store
			# FIXME use the URI of the CSV as the name of the graph, or better yet, a URI that combines both the CSV and CSVM URIs.
			# Note: 
			echo Storing CSV-derived RDF in graph store as $updatedResourceURI
			curl -H "Content-Type: text/turtle" -X PUT --data-binary @temp/csv-rdf.ttl http://localhost:8080/fuseki/prov/data?graph=$updatedResourceURI
			#TODO append Provenance metadata describing the csv2rdf conversion  
}	


# convert it to RDF, store it in Fuseki, ask it which resource was updated, query updated resource, store it in Fuseki

# temporary storage
mkdir -p file temp

# the update message, in JSON-LD format, is passed by fedora-update-handler to this script via standard input, so save it to a file
cat > temp/update-message.jsonld

# Fuseki won't accept JSON-LD, so convert it to RDF/XML
rdfconvert-0.4/bin/rdfconvert.sh -i JSON-LD -o RDF/XML temp/update-message.jsonld temp/update-message.rdf

# Store the update in the SPARQL store
echo Storing update event in graph store
curl -H "Content-Type: application/rdf+xml" -X PUT --data-binary @temp/update-message.rdf http://localhost:8080/fuseki/prov/data?graph=data:,last-update-message

# Now examine the update and take the appropriate action

# The update can be of several types, which require different handling
# prefix event: <http://fedora.info/definitions/v4/event#>
# event:ResourceDeletion - DELETE corresponding graph from SPARQL store
# event:ResourceCreation and event:ResourceModification - obtain new resource graph and PUT into SPARQL store
# event:ResourceRelocation - combine DELETE and PUT new resource graph
curl -X POST -H "Content-Type: application/sparql-query" -H "Accept: text/csv" --upload-file "sparql/get-event-type.rq" http://localhost:8080/fuseki/prov/query | tail -n +2 > temp/event-type.csv
# strip white space from file, leaving just the URI
eventType=`cat temp/event-type.csv | tr -d '[:space:]'` 
echo Type of event is: $eventType

# find the URI of the resource which was updated; this is the resource which prov:wasGeneratedBy a prov:Activity
# issue the sparql query, retrieve CSV, and discard the header row
curl -X POST -H "Content-Type: application/sparql-query" -H "Accept: text/csv" --upload-file "sparql/get-updated-resource-uri.rq" http://localhost:8080/fuseki/prov/query | tail -n +2 > temp/updated-resource-uri.csv

# strip white space from file, leaving just the URI
updatedResourceURI=`cat temp/updated-resource-uri.csv | tr -d '[:space:]'` 

# If the event was a deletion, then delete the corresponding graph from the graph store
if [ "$eventType" = "http://fedora.info/definitions/v4/event#ResourceDeletion" ]; then
	echo Purging resource graph from graph store at $updatedResourceURI
	curl -X DELETE http://localhost:8080/fuseki/prov/data?graph=$updatedResourceURI
elif [[ "$eventType" = "http://fedora.info/definitions/v4/event#ResourceCreation" || "$eventType" = "http://fedora.info/definitions/v4/event#ResourceModification" ]]; then 
	# Fedora resource was created or updated; need to mirror the new content to the graph store
	# The updated resource may be a Linked Data Platform RDFSource (e.g. a Fedora container or item), 
	# or it may be a NonRDFSource; some kind of binary object
	curl -X POST -H "Content-Type: application/sparql-query" -H "Accept: text/csv" --upload-file "sparql/is-rdf-source.rq" https://localhost:8080/fuseki/prov/query | tail -n +2 > temp/updated-resource-is-rdf.csv
	isRDFSource=`cat temp/updated-resource-is-rdf.csv | tr -d '[:space:]'` 
	if [ "$isRDFSource" = "true" ]; then
		handleRDFSource
	else
		echo Updated Fedora resource is a non-RDF resource
		# The resource which was updated was not itself RDF, but there is an associated metadata RDF resource. 
		# This metadata resource needs to be copied to the graph store. 
		# The URI of the metadata resource = the URI of the resource, with "/fcr:metadata" appended. 
		# (The LDP-compliant way to find the metadata would be to make an HTTP HEAD request with the original resource URI and follow the "described-by" Link header,
		# but with Fedora the "/fcr:metadata" assumption is safe.)
		handleFedoraMetadata
		
		# The so-called "NonRDF Source" may still be a source of additional RDF:
		# • A CSV file contains information that can be represented in RDF.
		# • A CSV on the Web metadata file (application/csvm+json) is itself RDF
		# • A CSV on the Web metadata file (application/csvm+json) also contains instructions for extracting RDF from an associated CSV file
		curl -X POST -H "Content-Type: application/sparql-query" -H "Accept: text/csv" --upload-file "sparql/get-media-type.rq" http://localhost:8080/fuseki/prov/query | tail -n +2 > temp/media-type.csv
		mediaType=`cat temp/media-type.csv | tr -d '[:space:]'`
		#TODO "text/csv" mediaType will include a character encoding suffix - check regex works here
		if [[ "$mediaType" =~ "^text/csv(;.*)?" ]]; then
			handleCSV
		elif [[ "$mediaType" = "application/csvm+json" ]]; then
			handleCSVM
		else
			# some other non-RDF content type: ignore it; maybe later we could extract metadata from image files, and similar, at this point.
			echo Ignoring updated resource with content type $mediaType
		fi
	fi
else 
	# resourceRelocation events are not yet implemented, any other unknown event types also ignored here
	echo Ignoring unimplemented event type $eventType
fi


