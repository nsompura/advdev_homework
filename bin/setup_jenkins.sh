#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi 
oc set resources dc/jenkins --limits=memory=2Gi,cpu=2 --requests=memory=2Gi,cpu=2 -n ${GUID}-jenkins

# Create custom agent container image with skopeo
oc new-build  -D $'FROM docker.io/openshift/jenkins-slave-maven-centos7:v3.9\n
      USER root\nRUN yum -y install skopeo && yum clean all\n
      USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`

echo "apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "tasks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "${REPO}"
      contextDir: "openshift-tasks"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        env:
        - name: GUID
          value: ${GUID}
        - name: CLUSTER
          value: ${CLUSTER}
        - name: REPO
          value: ${REPO}
        jenkinsfilePath: Jenkinsfile
kind: List
metadata: []" | oc create -f - -n ${GUID}-jenkins
