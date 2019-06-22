# Image Object Recognition Demo

## Overview
[Luminoth](https://luminoth.ai) is an open source computer vision
toolkit.  As installed with this demo, Luminoth will recognize
objects in a submitted image file, draw bounding boxes around the
objects, and attempt to identify the object within a given threshold
probability.  These instructions show how to run Luminoth in a
container on [OpenShift Container Platform](https://openshift.com).

## Download your pull secret
With OpenShift 3.11, you need to supply a pull secret for Dockerfile
binary builds to get images from the secure Red Hat image registry.

Browse to the [Red Hat trusted registry](https://registry.redhat.io).
Log in using your Red Hat customer portal credentials if prompted
and then click on the `Service Accounts` link in the middle of the
page to the right.

Select an existing service account or create a new one by pressing
the `New Service Account` button.  Select the `OpenShift Secret`
tab and then download your secret.

Move the downloaded file to the current directory and then determine
the name of your secret using the commands:

    mv /path/to/*secret.yaml .
    SECRET_NAME=$(grep name: *secret.yaml | awk '{print $2}')

## Installation
This application leverages a python 3.6 base layer, so there's no
need to install and configure operating system runtimes or language
runtimes in order to install and run Luminoth.

Download the Dockerfile in this project and then login to your
OpenShift environment:

    oc login -u <your username> <your OpenShift master hostname>

Create a new project.  The name `demo` is used below but feel free
to choose somthing else.  Just make sure you consistently use the
same project name in the following commands.

    oc new-project demo

Instantiate your secret and link it to the service accounts for
your project.

    oc create -f *secret.yaml -n demo
    oc secrets link default $SECRET_NAME --for=pull
    oc secrets link builder $SECRET_NAME

Import the image metadata for the python-36 builder image.

    oc import-image registry.redhat.io/ubi7/python-36 --confirm

Create and expose the Luminoth application.

    oc new-app . --name=luminoth --strategy=docker
    oc start-build luminoth --from-file=Dockerfile

    oc expose svc/luminoth

## Demo scenario
Use the command, 

    oc get routes

to get the URL for the application.  Browse to the URL to access
the web interface for Luminoth.  You can set a probability threshold
for object identification and `Browse` to a image file on your
laptop.  Press the `Submit` button, and the Luminoth app will use
trained models to identify objects within the image and draw bounding
boxes around them.
