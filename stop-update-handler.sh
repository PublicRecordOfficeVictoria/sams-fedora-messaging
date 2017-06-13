#!/bin/bash
# Stops the update handler and unsubscribes from the "Fedora" topic
java -jar fedora-update-handler/fedora-update-handler.jar stop fedora-update-handler-config.xml
