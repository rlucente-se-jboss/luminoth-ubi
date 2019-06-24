# Image Object Recognition Demo
[Luminoth](https://luminoth.ai) is an open source computer vision
toolkit.  As installed with this demo, Luminoth will recognize
objects in a submitted image file, draw bounding boxes around the
objects, and attempt to identify the object within a given threshold
probability.  These instructions show how to run Luminoth in a
container on [OpenShift Container Platform](https://openshift.com).

This application leverages a python 3.6 base layer, so there's no
need to install and configure operating system runtimes or language
runtimes in order to install and run Luminoth.

These instructions are divided into two parts:
* installing directly within OpenShift
* building and pushing an image to a public registry using the RHEL 8 container tools

# Installing directly within OpenShift
Instructions are provided on how to use both the unauthenticated
and authenticated registries.  Both options are described below.

## Create an OpenShift project
Login to the OpenShift environment:

    oc login -u your-ocp-username ocp-master-hostname

where `your-ocp-username` and `ocp-master-hostname` refer to the
unprivileged username on OpenShift and the URL for the OpenShift
master host, respectively.

Create a new project.  The name `demo` is used below but feel free
to choose somthing else.  Just make sure you consistently use the
same project name in the following commands.

    oc new-project demo

Clone this github project to your workstation using:

    git clone https://github.com/rlucente-se-jboss/luminoth-ubi.git

## Install via registry.access.redhat.com (Option 1)
This is the simplest method as `registry.access.redhat.com` does
not require authentication.

Import the image metadata for the python-36 builder image.

    oc import-image registry.access.redhat.com/ubi7/python-36 --confirm

Create and expose the Luminoth application.

    oc new-app . --name=luminoth --strategy=docker
    oc expose svc/luminoth

## Install via registry.redhat.io (Option 2)
Pulling from this registry requires that you authenticate to it.
With OpenShift 3.11, you need to supply a pull secret for Dockerfile
binary builds to get images from the authenticated Red Hat image
registry.

Browse to the [Red Hat registry](https://registry.redhat.io).
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

Instantiate your secret and link it to the service accounts for
your project.

    oc create -f *secret.yaml -n demo
    oc secrets link default $SECRET_NAME --for=pull
    oc secrets link builder $SECRET_NAME

Import the image metadata for the python-36 builder image.  Doing
this will override the `FROM` line in the Dockerfile when creating
the application using the docker strategy below.

    oc import-image registry.redhat.io/ubi7/python-36 --confirm

Create and expose the Luminoth application.

    oc new-app . --name=luminoth --strategy=docker
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

## Clean up
To delete this project, use the commands:

    oc delete all --all -n demo
    oc delete project demo

Make sure to use whatever your project name was if you didn't use
`demo`.

# RHEL 8 with container tools
RHEL 8 includes Open Container Initiative (OCI) compliant tools to
enable building containers on a RHEL 8 server.  These containers
can be run directly using the `podman` tools or imported into a
registry and run on OCP.  This set of commands will show how to
build the container on RHEL 8, push to a public container registry,
and then instantiate within OpenShift.

## Install container tools on RHEL 8
Use `subscription-manager` to register for updates and attach the
desired pools to the system.  Alternatively, you can configure Red
Hat satellite to provide updates.  How to do that is beyond the
scope of these instructions.  Please see the official documentation
for both [Red Hat Enterprise Linux 8](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/)
and [Red Hat Satellite](https://access.redhat.com/documentation/en-us/red_hat_satellite/6.5/).

As root, run the following commands once you're registered and you
have access to the repositories listed below.

    subscription-manager repos \
        --enable=rhel-8-for-x86_64-baseos-rpms \
        --enable=rhel-8-for-x86_64-appstream-rpms
    yum -y update

Next, install the container tools.  As root,

    yum module install -y container-tools
    yum -y clean all

Now that the container tools are installed, you can logoff as root
and login as an unprivileged user.

## Use container tools to create the container image
The container tools include buildah, podman, skopeo, and runc.
We'll use buildah to create the image by leveraging the Universal
Base Image for RHEL 7 with the pre-installed python tooling.  Luminoth
will install with one command.  The other commands below configure
the container by setting ports, entrypoints, etc.

As an unprivileged user, run the following commands:

    container=$(buildah from registry.access.redhat.com/ubi7/python-36)
    buildah run $container pip install luminoth[tf]
    buildah run $container /opt/app-root/bin/lumi checkpoint refresh
    buildah run $container /opt/app-root/bin/lumi checkpoint download fast
    buildah config --entrypoint \
        "/opt/app-root/bin/lumi server web --host 0.0.0.0 --port 5000 --debug --checkpoint fast" \
        --port 5000 --user 1000 \
        $container
    buildah commit $container luminoth
    buildah unmount $container
    buildah rm $container

## Push the container to a public registry
For this step, we will login to the public [Quay](https://quay.io/)
image registry and push our newly created image there.  Create a
Quay account if you don't already have one.

As the same unprivileged user, login to Quay via the `podman` command
and push the new image.

    podman login -u your-quay-username quay.io
    podman push luminoth quay.io/your-quay-username/luminoth

Make sure to replace `your-quay-username` with your actual Quay
username.  You can make the `luminoth` image publicly available via
the [Quay](https://quay.io) web interface.

## Run the quay.io hosted container on OCP
Running the container on OpenShift is very straightforward.  Simply
do the following after logging in to OpenShift as a normal user,

    oc new-project demo
    oc import-image quay.io/your-quay-username/luminoth --confirm
    oc new-app luminoth
    oc expose svc/luminoth

Of course, replace `your-quay-username` with your actual user name.

## Troubleshooting builds on RHEL 8
If you get an error similar to ...
`'overlay' is not supported over xfs at "~/.local/share/containers/storage/overlay"`
with the `podman push` command then do the following.

As root:

    yum -y reinstall containers-common

For each unprivileged user on the system:

    rm -f ~/.config/containers/storage.conf

And then, for each unprivileged user, make sure the file
`~/.config/containers/storage.conf` has the contents:

    [storage]
       driver = "overlay"
       runroot = "/run/user/1000"
       graphroot = "/home/your-user-name/.local/share/containers/storage"
       [storage.options]
         mount_program = "/usr/bin/fuse-overlayfs"

Of course, replace `your-user-name` in the above with your actual username.
