#!/bin/bash
# Starts the update handler, if necessary, establishing a persistent subscription to the "Fedora" topic
# NB stopping this script will not terminate the subscription. Notification messages will accumulate and be delivered when the handler script is restarted.
# To terminate the subscription, run stop-update-handler.sh
java -jar fedora-update-handler/fedora-update-handler.jar start fedora-update-handler-config.xml
