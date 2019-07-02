# mu-cli
Linux CLI support for setting up and starting mu projects and services.

## Assumptions
mu currently assumes your mu projects to be stored in `~/code/mu/` and your services to be stored in `~/code/<language>/`.  The frontend projects are expected to live in `~/code/ember/`.

The tasks-at-hand mu project would thus be stored in `~/code/mu/tasks-at-hand/`.  The migrations-service would be stored in `~/code/ruby/migrations-service/`.

Helpers are available to start and stop a mu project.


## Installation
Add `mu` to your path and source completions.

    git clone https://github.com/mu-semtech/mu-cli.git
    cd mu-cli
    echo "PATH=\"`pwd`/:\$PATH\"" >> ~/.bashrc
    echo "source `pwd`/completions" >> ~/.bashrc
    source ~/.bashrc

This will ensure both are available and loaded.


## Usage
Write mu and use tab completions.  When generating code, make sure to supply the name of the project at the end.
