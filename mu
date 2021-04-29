#!/bin/bash
MU_CLI_VERSION="1.0.2"

####
## Sending command info
####
STATUS_MESSAGE=""

function status_echo() {
    echo -n "$STATUS_MESSAGE";
}

function status_step() {
    STATUS_MESSAGE="$STATUS_MESSAGE.";
    echo -n ".";
}

####
## Implementation
####

function print_text_block() {
    for var in "$@"
    do
        echo "$var"
    done
}

function ensure_mu_cli_docker() {
    container_hash=`docker ps -f "name=mucli" -q`

    if [[ -z $container_hash ]] ;
    then
        docker run --volume /tmp:/tmp -i --name mucli --rm --entrypoint "tail" -d semtech/mu-cli:$MU_CLI_VERSION -f /dev/null
        if [[ "$?" -ne "0" ]]
        then
            echo "I could not start the mu-cli container.  Aborting operation." >> /dev/stderr
            exit 1
        fi
        container_hash=`docker ps -f "name=mucli" -q`
        while [[ -z $container_hash ]]
        do
            sleep 1;
            echo "."
        done
    fi
}

function print_commands_documentation() {
    service=$1
    command=$2
    jq_documentation_get_command_local="jq -c '( .scripts[] | select(.documentation.command == \\\"$command\\\") )'"
    command_documentation=`sh -c "$interactive_cli bash -c \"$local_cat_command | $jq_documentation_get_command_local\""`
    command_description=`echo "$command_documentation" | $interactive_cli $jq_documentation_get_description`
    command_description_indented=`echo "$command_description" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\n      /g'`

    command_arguments=`echo "$command_documentation" | $interactive_cli $jq_documentation_get_arguments`
    print_text_block "  $command:" \
                     "    description: $command_description_indented"
    echo -n "    command: mu script $service $command"
    for command_argument in $command_arguments
    do
        echo -n " [$command_argument]"
    done
}

function print_source_docker_files() {
    echo `ls docker-compose*.yml | tac | awk '{ print "-f " $1 }' | tr '\n' ' '`
}

function print_service_documentation() {
    service=$1
    available_container_id=`docker-compose $(print_source_docker_files) ps -q $service`
    mkdir -p /tmp/mu/cache/$available_container_id
    docker cp $available_container_id:/app/scripts /tmp/mu/cache/$available_container_id 2> /dev/null
    local_cat_command="cat /tmp/mu/cache/$available_container_id/scripts/config.json"
    if test -f "/tmp/mu/cache/$available_container_id/scripts/config.json"; then
        supported_commands=`sh -c "$interactive_cli bash -c \"$local_cat_command | $jq_documentation_filter_commands\""`
        for supported_command in $supported_commands
        do
            print_commands_documentation $service $supported_command
            print_text_block "" ""
        done
        echo ""
    else
        print_text_block "  no scripts found" \
                         ""
    fi
}

function print_service_scripts_documentation() {
    # This is used for listing the scripts a service knows about
    config_file_location=$1
    local_cat_command="cat $config_file_location"
    if [[ -f "$config_file_location" ]]
    then
        supported_commands=`sh -c "$interactive_cli bash -c \"$local_cat_command | $jq_documentation_filter_commands\""`
        if [[ -n "$supported_commands" ]]
        then
            print_text_block "" \
                             "Discovered scripts are:" \
                             ""
           for supported_command in $supported_commands
           do
               print_commands_documentation "[service]" $supported_command
               print_text_block "" ""
           done
           echo ""
        else
            print_text_block "" \
                             "There are no scripts available" \
                             ""
        fi
    else
        print_text_block "There are no scripts available" \
                         "";
    fi
}

function print_available_services_information() {
    ensure_mu_cli_docker
    interactive_cli="docker exec -i mucli"
    jq_documentation_filter_commands="jq -r '( .scripts[].documentation.command )'"
    jq_documentation_get_description="jq -r .documentation.description"
    jq_documentation_get_arguments="jq -r .documentation.arguments[]"
    echo "...looking for containers..."
    available_services=`docker-compose $(print_source_docker_files) ps --services`
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
    docker-compose `print_source_docker_files` logs -f $arguments
elif [[ "project" == $1 ]]
then
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
        docker run --rm -v `pwd`/config/resources:/config -v `pwd`/doc:/config/output/ madnificent/cl-resources-plantuml-generator
        echo "Generated JSONAPI svg"
        docker run --rm -v `pwd`/config/resources:/config -v `pwd`/doc:/config/output/ madnificent/cl-resources-ttl-generator
        echo "Generated ttl file for http://visualdataweb.de/webvowl/"
    elif [[ "add" == $2 ]]
    then
        if [[ "service" == $3 ]]; then
            service_image=$4
            service_tag=$5

            echo -n "Adding service "

            if [[ "$service_tag" == "" ]]
            then
                service_tag="latest"
            fi

            # 1. get the service image
            echo -n "."
            ensure_mu_cli_docker
            echo -n "."
            interactive_cli="docker exec -i mucli"
            echo -n "."

            service_image_description=`curl -s "https://info.mu.semte.ch/microservice-revisions?filter[microservice][:exact:title]=$service_image&filter[:exact:version]=$service_tag&page[size]=1"`

            if [[ "$?" -ne "0" ]]
            then
                echo " FAILED"
                echo ""
                echo "Could not fetch image description.  Are you online?"
                exit 1
            fi

            echo -n "."
            jq_infosemtech_image_name="jq -r .data[].attributes.image"
            image_name=`echo "$service_image_description" | $interactive_cli $jq_infosemtech_image_name`

            if [[ "$image_name" == "" ]]
            then
                echo " FAILED"
                echo ""
                echo "Could not find image in the repository."
                exit 1
            fi

            echo -n "."

            docker image inspect $image_name:$service_tag > /dev/null 2> /dev/null
            found_docker_image="$?"
            echo -n "."
            if [[ $found_docker_image -ne "0" ]]
            then
                echo ""
                echo "about to pull the image: $image_name:$service_tag"
            fi
            echo -n "."
            docker run --name mu_cli_tmp_copy --entrypoint "/bin/sh" "$image_name:$service_tag"
            echo -n "."
            if [[ $found_docker_image -ne "0" ]]
            then
                echo "Adding service ......"
            fi
            echo -n "."
            mkdir -p /tmp/mu/cache/mu_cli_tmp_copy/

            # 2. copy scripts contents from the image
            echo -n "."
            docker cp mu_cli_tmp_copy:/app/scripts/install /tmp/mu/cache/mu_cli_tmp_copy/ > /dev/null 2> /dev/null
            install_path_exists="$?"
            echo -n "."
            docker rm -f mu_cli_tmp_copy > /dev/null # remove the container before going further
            if [[ $install_path_exists -ne "0" ]]
            then
                echo " FAILED"
                echo ""
                echo "Could not find install script for $image_name:$service_tag"
                echo ""
                echo "For more info on how to add an install script to an image,"
                echo "see https://github.com/mu-semtech/mu-cli."
                echo "Perhaps the maintainers would fancy a PR :-)"
                exit 1
            fi
            docker cp docker-compose.yml mucli:/tmp/
            echo -n "."
            docker cp /tmp/mu/cache/mu_cli_tmp_copy/install/docker-compose-snippet.yml mucli:/tmp/
            echo -n "."

            # 3. extract script information
            services_line_number=`docker exec mucli grep -n -P "^services:" /tmp/docker-compose.yml | awk -F ":" '{ print $1 }' | tail -n 1`
            echo -n "."
            last_root_object_line_number=`docker exec mucli grep -n -P "^\\w" /tmp/docker-compose.yml | awk -F ":" '{ print $1 }' | tail -n 1`
            echo -n "."
            docker exec mucli sed -i -e "s/^/  /" /tmp/docker-compose-snippet.yml
            echo -n "."

            # 4. append lines with info
            if [ $services_line_number -ne $last_root_object_line_number ] ;
            then
                line_number_to_insert_at=$services_line_number
                r="r"
                docker exec mucli sed -i -e "$line_number_to_insert_at$r /tmp/docker-compose-snippet.yml" /tmp/docker-compose.yml
                echo -n "."
            else
                docker exec mucli /bin/bash -c "echo '' >> /tmp/docker-compose.yml"
                echo -n "."
                docker exec mucli /bin/bash -c "cat /tmp/docker-compose-snippet.yml >> /tmp/docker-compose.yml"
                echo -n "."
            fi
            docker cp mucli:/tmp/docker-compose.yml docker-compose.yml
            echo " DONE"
            exit 0
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
    # Check if we are in a project or in a service
    if [[ -f ./docker-compose.yml && -f Dockerfile ]]
    then
        echo "mu script is not supported in folders which have a Dockerfile and a docker-compose.yml"
        exit 1
    elif [[ -f ./docker-compose.yml ]]
    then
        service=$2
        command=$3
        interactive_cli="docker exec -i mucli"
        ensure_mu_cli_docker

        # jq commands
        jq_documentation_filter_commands="jq -r '( .scripts[].documentation.command )'"
        jq_documentation_get_command="jq -c '( .scripts[] | select(.documentation.command == \\\"$command\\\") )'"
        jq_documentation_get_description="jq -r .documentation.description"
        jq_documentation_get_arguments="jq -r .documentation.arguments[]"
        jq_command_get_mount_point="jq -r '.mounts.app // false'"
        jq_command_get_script="jq -r .environment.script"
        jq_command_get_image="jq -r .environment.image"

        ensure_mu_cli_docker

        if [[ "-h" == $service ]] || [[ -z $service ]] ;
        then
            echo ""
            print_available_services_information
            exit 0
        fi

        container_id=`docker-compose $(print_source_docker_files) ps -q $service`
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
                             "Error: could not find script: $command for service: $service." \
                             "Supported scripts are:"
            print_service_documentation $service
            exit 1
        fi
        echo -n "."
        app_mount_point=`echo "$command_spec" | $interactive_cli bash -c "$jq_command_get_mount_point"`
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
        echo -n "."
        # NOTE: this approach for discovering the project name will
        # not work when running installation scripts for a service
        docker_compose_project_name=`docker inspect --format '{{ index .Config.Labels "com.docker.compose.project"}}' $container_id`
        echo -n "."
        interactive_mode=`echo "$command_spec" | $interactive_cli jq -r '.environment.interactive // false'`
        echo -n "."
        it=""
        if [[ true == "$interactive_mode" ]];
        then
            it=" -it "
        fi
        echo -n "."

        network_options=$()
        join_networks=`echo "$command_spec" | $interactive_cli jq -r '.environment.join_networks // false'`
        echo -n "."
        if [[ true == "$join_networks" ]]
        then
            default_network_id=`docker network ls -f "label=com.docker.compose.project=$docker_compose_project_name" -f "label=com.docker.compose.network=default" -q`
            network_options=("--network" "$default_network_id")
        fi
        echo -n "."

        volume_mounts=(--volume /tmp/mu/cache/$container_id/scripts/$folder_name:/script)
        if [[ false != "$app_mount_point" ]]
        then
            volume_mounts+=(--volume $PWD:$app_mount_point)
        fi
        docker run ${network_options[@]} ${volume_mounts[@]} $it -w $working_directory --rm --entrypoint ./$entry_point $image_name $arguments
    elif [[ -f "Dockerfile" ]]
    then
        # A script for developing a microservice
        STATUS_MESSAGE="Discovering script "
        status_echo
        image_name=`cat Dockerfile | grep -oP "^FROM \\K.*"`
        status_step # 1
        command=$2
        interactive_cli="docker exec -i mucli"
        ensure_mu_cli_docker

        status_step # 2

        # jq commands
        jq_documentation_filter_commands="jq -r '( .scripts[].documentation.command )'"
        jq_documentation_get_command="jq -c '( .scripts[] | select(.documentation.command == \\\"$command\\\") )'"
        jq_documentation_get_description="jq -r .documentation.description"
        jq_documentation_get_arguments="jq -r .documentation.arguments[]"
        jq_command_get_mount_point="jq -r .mounts.service"
        jq_command_get_script="jq -r .environment.script"
        jq_command_get_image="jq -r .environment.image"

        status_step # 3

        image_id=`docker images -q $image_name`

        status_step # 4

        # make sure we have the image available
        if [[ -z image_id ]]
        then
            echo " need to fetch base image."

            echo -n "Fetching service base image ... "
            docker pull $image_name 2> /dev/null
            if [[ "$?" -ne "0" ]]
            then
                echo ""
                echo "Could not find the image."
                echo "Check if the FROM in your Dockerfile is correct."
                echo "If the image is not available publicly,"
                echo "make sure to build it locally"
                exit 1
            fi
            echo "DONE"

            status_echo
            image_id=`docker images -q $image_name`
        fi

        status_step # 5

        docker run --name mu_cli_tmp_copy --entrypoint /bin/sh $image_name

        status_step # 6

        mkdir -p /tmp/mu/cache/$image_id

        status_step # 7

        docker cp mu_cli_tmp_copy:/app/scripts /tmp/mu/cache/$image_id 2> /dev/null

        status_step # 8

        # cleaning up copy container
        docker rm -f mu_cli_tmp_copy 2> /dev/null > /dev/null

        status_step # 9

        config_location="/tmp/mu/cache/$image_id/scripts/config.json"
        cat_config_command="cat $config_location"

        if [[ "-h" == $command || "" == "$command" ]]
        then
            echo " DONE"
            echo ""
            print_service_scripts_documentation $config_location
            exit 0
        fi

        status_step # 10

        command_spec=`sh -c "$interactive_cli bash -c \"$cat_config_command | $jq_documentation_get_command\""`

        status_step # 11

        if [[ -z $command_spec ]] ;
        then
            echo " DONE"
            print_text_block "" \
                             "Error: Script not found" \
                             "  Could not find script $command in $image_name" \
                             "" \

            print_service_scripts_documentation $config_location
            exit 1
        fi

        status_step # 12

        service_mount_point=`echo "$command_spec" | $interactive_cli $jq_command_get_mount_point`
        status_step # 13

        service_folder="$PWD"
        status_step # 14
        script_path=`echo "$command_spec" | $interactive_cli $jq_command_get_script`
        status_step # 15
        script_folder_name=`dirname $script_path`
        script_file_name=`basename $script_path`
        folder_name="$script_folder_name"
        entry_point="$script_file_name"
        working_directory="/script"
        status_step # 16
        arguments="${@:3}"
        status_step # 17
        image_name=`echo "$command_spec" | $interactive_cli $jq_command_get_image`
        status_step # 18
        interactive_mode=`echo "$command_spec" | $interactive_cli jq -r '.environment.interactive // false'`
        status_step # 19
        it=""
        if [[ true = "$interactive_mode" ]];
        then
            it=" -it "
        fi

        status_step # 20

        # docker arguments

        docker_volumes=(
            --volume $PWD:$service_mount_point
            --volume /tmp/mu/cache/$image_id/scripts/$folder_name:/script)
        docker_environment_variables=(
            -e SERVICE_HOST_DIR="$PWD/")

        status_step # 21

        echo " DONE"

        echo "Executing script $command $arguments"

        docker run ${docker_volumes[@]} ${docker_environment_variables[@]} $it -w $working_directory --rm --entrypoint ./$entry_point $image_name $arguments
        exit 0
    else
        echo "Did not recognise location"
        echo ""
        echo "Please make sure you are in the top-level folder of either:"
        echo " - a project (containing a docker-compose.yml)"
        echo " - a service (containing a Dockerfile)"
        exit 1
    fi
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
            echo "FROM semtech/mu-javascript-template:1.5.0-beta.1" >> Dockerfile
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
            echo "    image: semtech/mu-javascript-template:1.5.0-beta.1"
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
    echo "Known commands [ project, logs, service, script, start ]"
fi
