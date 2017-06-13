#!/bin/sh

JAVA_OPT=-mx512m

lib="$(dirname "${0}")/../lib"
java $JAVA_OPT -cp "$lib/$(ls "$lib"|xargs |sed "s; ;:$lib/;g")" nz.co.rivuli.rio.convert.RDFConvert $*