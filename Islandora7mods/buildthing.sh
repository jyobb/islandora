#!/bin/sh

echo good;

CL=dk.defxws.fedoragsearch.server.GenericOperationsImpl:dk.defxws.fedoragsearch.server.TransformerToText:dk.defxws.fedoragsearch.server.errors.GenericSearchException

LIB=/usr/fedora/tomcat/webapps/fedoragsearch/WEB-INF/lib


JARS=$LIB/xml-apis-1.3.04.jar:$LIB/axis-1.4.jar:$LIB/fcrepo-client-admin-3.5-fedora.jar:$LIB/fcrepo-common-3.5.jar:$LIB/fcrepo-server-3.5.jar:$LIB/log4j-1.2.15.jar:$LIB/jaxrpc-api-1.1.jar

javac -Xlint -cp .:$JARS:$CL ca/upei/roblib/DataStreamForXSLT.java 