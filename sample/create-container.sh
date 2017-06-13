#!/bin/bash
# creates "sources" and "sources/trains" containers in Fedora

#create "sources" folder in Fedora as sibling of "records"
curl -i -X PUT -H "Content-Type: text/turtle" http://fedora-dev.prov.vic.gov.au:8080/rest/sources

# create "trains" folder within "sources" folder
curl -i -X PUT -H "Content-Type: text/turtle" http://fedora-dev.prov.vic.gov.au:8080/rest/sources/trains

