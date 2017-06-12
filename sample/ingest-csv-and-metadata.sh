#!/bin/bash
# e.g. upload($contentType, $fileName, $relativeURI)
function upload() {
	curl -i -X PUT -H "Content-Type: $1" -H "Content-Disposition: attachment" --data-binary @$2 http://fedora-dev.prov.vic.gov.au:8080/rest/sources/$3 
}

# upload the CSV resource
upload "text/csv; charset=utf-8" 12800-sample.csv trains/12800-sample.csv
# upload the CSVM resource
upload "application/csvm+json" trains-schema.jsonld trains/trains-schema.jsonld


