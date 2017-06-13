# sams-fedora-messaging
Data pipelines driven by Fedora's asynchronous messages

## installation

The messaging pipeline assumes that Fedora and Fuseki are both installed, that Fedora's Java Messaging Service is enabled, and that Fuseki is configured to have a SPARQL 1.1 Graph Store Protocol endpoint available at `http://localhost:8080/fuseki/prov/data` and a SPARQL Query Protocol endpoint at `http://localhost:8080/fuseki/prov/query`  

Check out the repository
```
$ git clone https://github.com/PublicRecordOfficeVictoria/sams-fedora-messaging.git
```

Install the `csv2rdf` Ruby gem, and verify it's installed
```bash
$ gem install specific_install
$ sudo gem specific_install -l https://github.com/theodi/csv2rdf
$ csv2rdf help
Usage:
  csv2rdf myfile.csv OR csv2json http://example.com/myfile.csv

Options:
  d, [--dump-errors], [--no-dump-errors]  # Pretty print error and warning objects.
  s, [--schema=FILENAME OR URL]           # Schema file
  v, [--validate], [--no-validate]        # Validate as well as transform
  f, [--full], [--no-full]                # Get full output rather than minimal output

Supports converting CSV files to JSON

```

Configure the system to run the script `sams-fedora-messaging/start-update-handler.sh` at boot time.

## Testing

Edit the files `sample/create-container.sh` and `sample/ingest-csv-and-metadata.sh` to set the correct domain name for the server.
Run the first script to create the "sources/trains" folder, and the second script to upload the sample CSV file and its associated CSV Metadata file.
Each time the second script is run, the CSV file should be reconverted to RDF and stored in the SPARQL Graph Store.

