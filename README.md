# mu-cli

Linux CLI support for setting up and starting mu projects and services.

## Getting started

_Getting started with mu-cli_

First we install mu-cli, then we use it to create a new migration.  As a last step we create a script in our repository.

### Installation

#### Bash users

Add `mu` to your path and source completions.

    git clone https://github.com/mu-semtech/mu-cli.git
    cd mu-cli
    echo "PATH=\"`pwd`/:\$PATH\"" >> ~/.bashrc
    echo "source `pwd`/completions" >> ~/.bashrc
    source ~/.bashrc

You now have the `mu` command on your system.

#### ZSH users

Add `mu` to your path and source completions.

    git clone https://github.com/mu-semtech/mu-cli.git
    cd mu-cli
    echo "autoload -U +X bashcompinit && bashcompinit" >> ~/.zshrc
    echo "PATH=\"`pwd`/:\$PATH\"" >> ~/.zshrc
    echo "source `pwd`/completions" >> ~/.zshrc
    source ~/.zshrc

You now have the `mu` command on your system.

### Creating a project

The mu command can help you create a new project.  Move into a folder of your liking and create a new project with a given name, running:

    cd ~/code/mu/
    mu project new getting-started

The available commands depend on your project.  In a new mu-project, the migrations service will offer you a command.  Let's create a new mu-project so we have a solid starting point.

Visiting the project, we can see the standard services in the `mu-project`.

    cd getting-started
    cat docker-compose.yml

### Installing services

Common services can be installed through the cli.  You can request the current versions of these services from the cli.  Let's install the latest migrations service:

    mu project add service migrations

You are greeted with a copy-paste section to add this service to your project.  Copy-paste this snippet into the services section of your docker-compose.yml and ensure the indentation is correct.

Future versions of `mu` will insert this snippet for you.

### Running scripts for an existing service

Let's first see which commands the migrations service offers.  The description of the commands you can run come from within the containers of your project.  The containers don't need to be running, as long as they're created the command will find its way.

We can list the commands to execute with the -h option.

    docker-compose up -d

    mu script migrations -h

You are listed with the scripts your newly installed migrations service supports.  Note that the scripts may differ between versions.  We will run the new command and supply it with the name for our migration:

    mu script migrations new hello-world

And there you have it, a new migration file is born.  No need to search for the right variable name.

### Writing your own script

Scripts should be added to the services they belong to.  In many cases the scripts will be reusable by others using the same service.  In order to write your own script, you have to create a command which lists the options for your script.

We will go about this in three steps.  First we mount the scripts locally.  Then we create the structure to list our script.  Lastly, we implement our script and execute it.

#### A local development setup

You can develop scripts to add to your project, and you can develop them live by mounting the right folders.  Let's create a script to add to the dispatcher.  Assuming we can live without the current scripts of the dispatcher, we can override the current script by mounting a scripts folder.  Add the following mount-point to the dispatcher:

    volumes:
      - ./scripts/dispatcher/:/scripts/

Make sure you `up` your stack again so the scripts are picked up when running the `mu` command:

    docker-compose up -d

#### Adding the metadata for our command

The `mu` command currently requires some housekeeping so we know how to run your command.  More sensible defaults to come in the near future.

Move the following script into the `./scripts/dispatcher/config.json` folder:

    {
      "version": "0.1",
      "scripts": [
        {
          "documentation": {
            "command": "catch-all-redirect",
            "description": "Introduces a catch-all redirect route",
            "arguments": []
          },
          "environment": {
            "image": "ubuntu",
            "interactive": false,
            "script": "catch-all/run.sh"
          },
          "mounts": {
            "app": "/data/app/"
          }
        }
      ]
    }

Important things mentioned here are the mount point for `"app"`, this will mount our mu-project in the `"/data/app/"` folder so we can manipulate the files of our project.  Also note that we indicate the script to run and the image in which to run it, you can use any image and have any set of preinstalled content in there.  The documentation section is used when running `mu project script dispatcher -h`.

#### Implementing the script

As specified in our metadata, our script will be stored in `./scripts/dispatcher/catch-all/run.sh`.  Let's write and run!

Our script will replace the line `    send_resp( conn, 404, "Route not found.  See config/dispatcher.ex" )` with a new line like `Proxy.forward conn, path, "https://semantic.works/"`.  Not the best approach, but it will suffice:

    #!/bin/bash
    sed -i -e 's/send_resp( conn, 404, "Route not found.  See config\/dispatcher.ex" )/Proxy.forward conn, path, "https:\/\/semantic.works\/"/' /data/app/config/dispatcher/dispatcher.ex

With that file in place, we can ensure the execution bit is set on the file and run it through mu-cli!

    chmod u+x ./scripts/dispatcher/catch-all/run.sh
    mu script migration catch-all

And behold the glory of our new dispatcher:

    git diff

Awesome!

## How-to guides

_Specific guides how to apply this container_

### Reading a configuration parameter in a script

Reading parameters from a script may occur from many languages.  This example reads from the commandline using a bash script.

In order to read contents from a user, your command needs to be ran in interactive mode.


When writing a script you may want to read information from the user.  When using bash, you can use the `read` command as such:

    read -p "Please enter your name: " NAME
    echo "Your name is $NAME but I could have used it for something better than printing a command"

Be sure to set the `interactive` option on your command to `true`.


## Reasoning

_Background information about the approach we took_

### High-level architectural overview

mu-cli is a scirpt which supplies a bunch of functions.  It bases itself on a somewhat limited shell script and executes commands you may not have installed through Docker.

We find two series of scripts:

  - Creating new services and projects
  - Manipulating existing projects through scripts

#### Creating new services and projects

We assume you have Git installed.  In order to create a new service or project, we either clone a template repository, or we create the minimal contents needed through a simple script.

Although the current approach works this way, the long-term flexibility may be more in line with either cloning template repositories or in line with running scripts.

#### Running scripts

Scripts are currently attached to a microservice defined in a project.  We assume the scripts are defined in `/app/scripts` in the final output of the container.

When you choose to run a script, we parse the json file which describes the command.  This describes how the script should be ran (in which image and which executable).  The json file has some options to specify the environment which the script needs to run correctly.

### Executing and finding scripts in a project

Finding the scripts in a project requires some wizardry.  We find containers that are running for your project and inspect those to find the available scripts.

We want to be compatible with the options supplied in the docker-compose.yml file and select the "right" docker-compose files to find the services in.  In case of conflict we want to stay as close as possible to your configuration.  That includes things like mounted volumes for finding the scripts.

docker-compose offers a script which lists all containers active for the current project, regardless of the docker-compose file through which they were launched.  Although this requires the stack to have been started before you can execute such scripts, it helps us make sure the environment for the container is what the user expects it to be.  We copy the scripts folder from the existing container and start reasoning on its contents.

Once the script has been found, we execute it in the requested environment.  The container in which the script runs can be set dynamically.

### Base technologies

mu-cli is a command-line extension of mu.semte.ch.  Searching for a limited set of dependencies, the result is a shell script which heavily relies on Docker for its base functionality.

Depending on a shell seems to be well-suited for terminal support.  These scripts can be written in multiple languages.  Tools are dependent on the language chosen.  It is highly uncertain which scripts a person will have installed.  We can request the user to install all necessary dependencies, but that would not be the nicest experience.  Furthermore, depending on installed commands may also make us depend on specific versions.

Because the stack already requires Docker and docker-copmose, we try to keep the shell dependencies low, and use a long-running docker-container for other functionality.

As such, the base dependency is a shell (we assume something Bash-compatible at this time) and Docker.

### Installing a service

Installing a service is a different beast alltogether.  We can't inspect the service's image or the environment like we do when running scripts.

We maintain an index of images compatible with mu.semte.ch.  This list is queried for the name you're looknig for.  If we find the service, we check the necessary image.  We create a new container for that image and ensure it exists immediately.  Once the container is created, we copy the scripts container from that image.  Next we remove the container again.

The `config.json` describes what we need to when we want to install the image.  Each of those commands in order.

### Embedding scripts in the container

You may wonder why we share the scripts through the container itself rather than using some other system.

There are a few advantages to this approach:

  - We expect the majority of the scripts to be tied to a microservice.  It makes sense to maintain the scripts which match a specific version of the microservice, so it makes sense for the scripts to be maintained with the sourcecode.
  - If you are using mu.semte.ch, you must have found ways to share Docker containers.  You already have a sturdy way of sharing scripts.
  - By storing the scripts in a container and supporting mounted volumes, it's easy to develop scripts by mounting them in a container.
  - Although we can easily share scripts with a microservice, you may add a container which exits early (like semtech/mu-scripts) to embed project-specific scripts in the same manner.

A possible downside of our approach is that the image may get polluted with large scripts.  We doubt this will be an issue in practice as you can run the scripts in a container with a different image.  As such, you can embed extra dependencies in such an image.  If the custom script itself becomes large, you can create a custom docker build for storing the information about that script.

Taking these factors into account, it makes sense to keep use this mechanism for sharing scripts.

## API

_Provided application interface_

### Shell API

This is a listing of all commands in the shell.

- 
