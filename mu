#!/bin/bash
MU_CLI_VERSION="latest"

function print_text_block() {
    for var in "$@"
    do
        echo "$var"
    done
}

function ensure_mu_cli_docker() {
    if [[ -z $container_hash ]] ;
    then
        docker run --volume /tmp:/tmp -i --name mucli --rm --entrypoint "tail" -d semtech/mu-cli:$MU_CLI_VERSION -f /dev/null
    fi
}

function print_commands_documentation() {
    command=$1
    jq_documentation_get_command_local="jq -c '( .scripts[] | select(.documentation.command == \\\"$command\\\") )'"
    command_documentation=`sh -c "$interactive_cli bash -c \"$local_cat_command | $jq_documentation_get_command_local\""`
    command_description=`echo "$command_documentation" | $interactive_cli $jq_documentation_get_description`
    command_arguments=`echo "$command_documentation" | $interactive_cli $jq_documentation_get_arguments`
    print_text_block "  $command:" \
                     "    description: $command_description"
    echo -n "    command: mu script $available_service $command"
    for command_argument in $command_arguments
    do
        echo -n " [$command_argument]"
    done
}

function print_service_documentation() {
    service=$1
    available_container_id=`docker-compose ps -q $service`
    mkdir -p /tmp/mu/cache/$available_container_id
    docker cp $available_container_id:/app/scripts /tmp/mu/cache/$available_container_id 2> /dev/null
    local_cat_command="cat /tmp/mu/cache/$available_container_id/scripts/config.json"
    if test -f "/tmp/mu/cache/$available_container_id/scripts/config.json"; then
        supported_commands=`sh -c "$interactive_cli bash -c \"$local_cat_command | $jq_documentation_filter_commands\""`
        for supported_command in $supported_commands
        do
            print_commands_documentation $supported_command
            print_text_block "" ""
        done
        echo ""
    else
        print_text_block "  no scripts found" \
                         ""
    fi
}

function print_available_services_information() {
    ensure_mu_cli_docker
    interactive_cli="docker exec -i mucli"
    jq_documentation_filter_commands="jq -r '( .scripts[].documentation.command )'"
    jq_documentation_get_description="jq -r .documentation.description"
    jq_documentation_get_arguments="jq -r .documentation.arguments[]"
    echo "...looking for containers..."
    available_services=`docker-compose ps --services`
    echo ""
    echo "found services:"
    for available_service in $available_services
    do
        print_text_block "$available_service:"
        print_service_documentation $available_service
    done
}

if [[ "start" == $1 ]]
then
    echo "Launching mu.semte.ch project ..."
    if [[ "dev" == $2 ]]
    then
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
    else
        docker-compose -f docker-compose.yml up -d
    fi
elif [[ "logs" == $1 ]]
then
    arguments="${@:2}"
    docker-compose logs -f $arguments
elif [[ "project" == $1 ]]
then
    echo "Mu project commands"
    if [[ "new" == $2 ]]
    then
        PROJECT_NAME=$3
        if [[ -z "$PROJECT_NAME" ]]
        then
            print_text_block "Please specify a project name." \
                             "" \
                             "The expected usage for this command is:" \
                             "  mu project new [project name]"
            exit 1
        fi

        echo "Creating new mu project for $PROJECT_NAME"
        git clone https://github.com/mu-semtech/mu-project.git $PROJECT_NAME
        cd $PROJECT_NAME
        rm -Rf ./.git
        git init .
        git add .
        git commit -m "Creating new mu project"
        echo "Your mu project hack gear is ready to be hacked... hack on"
    elif [[ "doc" == $2 ]]
    then
        echo "Generating documentation for project in `pwd`"
        docker run --rm -v `pwd`/config/resources:/config -v `pwd`/tmp:/config/output/ madnificent/cl-resources-plantuml-generator
        echo "Generated JSONAPI svg"
        docker run --rm -v `pwd`/config/resources:/config -v `pwd`/tmp:/config/output/ madnificent/cl-resources-ttl-generator
        echo "Generated ttl file for http://visualdataweb.de/webvowl/"
    elif [[ "add" == $2 ]]
    then
        if [[ "service" == $3 ]]; then
            service_image=$4
            service_tag=$5
            service_name=`echo $service_image | sed -e s/-//g`
            if [ -z "$service_tag" ]
            then
                service_tag="latest"
            fi
            echo "You can add the following snippet in your pipeline"
            echo "to hack this service live."
            echo ""
            echo "  $service_name:"
            echo "    image: semtech/$service_image:$service_tag"
            echo "    links:"
            echo "      - db:database"
            echo ""
            echo "All set to to hack!"
            for filename in $(find /tmp/musemtech/ -name "*.$service_image.installation_script"); do
                installation_script_location=$(<$filename)
                if [[ "null" == $installation_script_location ]]; then
                    exit 0
                else
                    echo "Executing installation script."
                    curl $installation_script_location > /tmp/install_service.sh
                    bash /tmp/install_service.sh
                fi
            done
        else
            echo "To add a service use:"
            echo "mu project add service [service name] [(optional) service tag]"
        fi
    else
        echo "Don't know command $2"
        echo "Known project commands: [ new, doc, add ]"
    fi
elif [[ "script" == $1 ]]
then
    service=$2
    command=$3
    container_hash=`docker ps -f "name=mucli" -q`
    interactive_cli="docker exec -i mucli"
    ensure_mu_cli_docker

    # jq commands
    jq_documentation_filter_commands="jq -r '( .scripts[].documentation.command )'"
    jq_documentation_get_command="jq -c '( .scripts[] | select(.documentation.command == \\\"$command\\\") )'"
    jq_documentation_get_description="jq -r .documentation.description"
    jq_documentation_get_arguments="jq -r .documentation.arguments[]"
    jq_command_get_mount_point="jq -r .mounts.app"
    jq_command_get_script="jq -r .environment.script"
    jq_command_get_image="jq -r .environment.image"

    ensure_mu_cli_docker

    container_id=`docker-compose ps -q $service`
    if [[ -z $container_id ]] ;
    then
        echo ""
        print_available_services_information
        exit 1
    fi
    mkdir -p /tmp/mu/cache/$container_id
    docker cp $container_id:/app/scripts /tmp/mu/cache/$container_id
    cat_command="cat /tmp/mu/cache/$container_id/scripts/config.json"

    if [[ "-h" == $command ]] || [[ -z $command ]] ;
    then
        print_text_block "The commands supported by $service are listed below." \
                         "you can invoke them by typing 'mu script $service [COMMAND] [ARGUMENTS]'." \
                         ""
        print_service_documentation $service
        exit 0
    fi
    echo -n "Executing "
    command_spec=`sh -c "$interactive_cli bash -c \"$cat_command | $jq_documentation_get_command\""`
    if [[ -z $command_spec ]] ;
    then
        print_text_block "" \
                         "Error could not find command: $command for service: $service." \
                         "Supported commands are:"
        print_service_documentation $service
        exit 1
    fi
    echo -n "."
    app_mount_point=`echo "$command_spec" | $interactive_cli $jq_command_get_mount_point`
    app_folder="$PWD"
    echo -n "."
    script_path=`echo "$command_spec" | $interactive_cli $jq_command_get_script`
    echo -n "."
    script_folder_name=`dirname $script_path`
    script_file_name=`basename $script_path`
    folder_name="$script_folder_name"
    entry_point="$script_file_name"
    working_directory="/script"
    arguments="${@:4}"
    echo -n "."
    image_name=`echo "$command_spec" | $interactive_cli $jq_command_get_image`
    echo ""
    interactive_mode=`echo "$command_spec" | $interactive_cli jq -r '.environment.interactive // false'`
    it=""
    if [[ true = "$interactive_mode" ]];
    then
        it=" -it "
    fi

    docker run --volume $PWD:$app_mount_point --volume /tmp/mu/cache/$container_id/scripts/$folder_name:/script $it -w $working_directory --rm --entrypoint ./$entry_point $image_name $arguments
elif [[ "service" == $1 ]]
then
    echo "Mu service commands"
    if [[ "new" == $2 ]]
    then
        LANGUAGE=$3
        SERVICE_NAME=$4
        echo "Creating new service"
        if [[ "ruby" == $LANGUAGE ]]
        then
            USER_NAME=`git config user.name`
            EMAIL=`git config user.email`
            USER=`whoami`
            echo "Creating new ruby service for $SERVICE_NAME"
            mkdir $SERVICE_NAME
            cd $SERVICE_NAME
            echo "FROM semtech/mu-ruby-template:2.10.0" >> Dockerfile
            echo "LABEL maintainer=\"$USER_NAME <$EMAIL>\"" >> Dockerfile
            echo "# see https://github.com/mu-semtech/mu-ruby-template for more info" >> Dockerfile
            echo "# see https://github.com/mu-semtech/mu-ruby-template for more info" >> web.rb
            echo "get '/' do" >> web.rb
            echo "  content_type 'application/json'" >> web.rb
            echo "  { data: { attributes: { hello: 'world' } } }.to_json" >> web.rb
            echo "end" >> web.rb
            git init .
            git add .
            git commit -m "Initializing new mu ruby service"
            echo "You can add the following snippet in your pipeline"
            echo "to hack this service live."
            DOCKER_SERVICE_NAME=`echo $SERVICE_NAME | sed -e s/-//g`
            echo ""
            echo "  $DOCKER_SERVICE_NAME:"
            echo "    image: semtech/mu-ruby-template:2.10.0"
            echo "    links:"
            echo "      - db:database"
            echo "    ports:"
            echo '      - "8888:80"'
            echo "    environment:"
            echo '      RACK_ENV: "development"'
            echo "    volumes:"
            echo "      - \"`pwd`/:/app\""
            echo ""
            echo "All set to to hack!"
        elif [[ "javascript" == $LANGUAGE ]]
        then
            USER_NAME=`git config user.name`
            EMAIL=`git config user.email`
            USER=`whoami`
            echo "Creating new javascript service for $SERVICE_NAME"
            mkdir $SERVICE_NAME
            cd $SERVICE_NAME
            echo "FROM semtech/mu-javascript-template:1.3.5" >> Dockerfile
            echo "LABEL maintainer=\"$USER_NAME <$EMAIL>\"" >> Dockerfile
            echo "" >> Dockerfile
            echo "# see https://github.com/mu-semtech/mu-javascript-template for more info" >> Dockerfile
            echo "// see https://github.com/mu-semtech/mu-javascript-template for more info" >> app.js
            echo "" >> app.js
            echo "import { app, query, errorHandler } from 'mu';" >> app.js
            echo "" >> app.js
            echo "app.get('/', function( req, res ) {" >> app.js
            echo "  res.send('Hello mu-javascript-template');" >> app.js
            echo "} );" >> app.js
            echo "" >> app.js
            echo "app.use(errorHandler);" >> app.js
            git init .
            git add .
            git commit -m "Initializing new mu javascript service"
            echo "You can add the following snippet in your pipeline"
            echo "to hack this service live."
            DOCKER_SERVICE_NAME=`echo $SERVICE_NAME | sed -e s/-//g`
            echo ""
            echo "  $DOCKER_SERVICE_NAME:"
            echo "    image: semtech/mu-javascript-template:1.3.5"
            echo "    links:"
            echo "      - db:database"
            echo "    ports:"
            echo '      - "8888:80"'
            echo '      - "9229:9229"'
            echo "    environment:"
            echo '      NODE_ENV: "development"'
            echo "    volumes:"
            echo "      - \"`pwd`/:/app\""
            echo ""
            echo "All set to to hack!"
        else
            echo "Don't know language $LANGUAGE"
            echo "Known languages: [ ruby, javascript ]"
        fi
    else
        echo "Don't know service command $2"
        echo "Known commands: [ shell, new ]"
    fi
else
    echo "Don't know command $1"
    echo "Known commands [ project, service, script ]"
fi
