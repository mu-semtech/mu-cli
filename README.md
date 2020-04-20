# mu-cli

Linux CLI support for setting up and starting mu projects and services.


## Getting started

First we install mu-cli, then we use it to create a new migration.  As a last step we create a script in our repository.

### Installation

#### Bash shell
Add `mu` to your path and source completions.

    git clone https://github.com/mu-semtech/mu-cli.git
    cd mu-cli
    echo "PATH=\"`pwd`/:\$PATH\"" >> ~/.bashrc
    echo "source `pwd`/completions" >> ~/.bashrc
    source ~/.bashrc

You now have the `mu` command on your system.

#### ZSH shell
Add `mu` to your path and source completions.

    git clone https://github.com/mu-semtech/mu-cli.git
    cd mu-cli
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

### Reading a configuration parameter in a script

When writing a script you may want to read information from the user.  When using bash, you can use the `read` command as such:

    read -p "Please enter your name: " NAME
    echo "Your name is $NAME but I could have used it for something better than printing a command"

Be sure to set the `interactive` option on your command to `true`.


## Reasoning



## Plugin API





## Usage

Write mu and use tab completions.  When generating code, make sure to supply the name of the project at the end.
