#!/bin/bash

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
    docker-compose logs -f $2 $3 $4 $5 $6 $7 $8
elif [[ "project" == $1 ]]
then
    echo "Mu project commands"
    if [[ "new" == $2 ]]
    then
        PROJECT_NAME=$3
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
    container_id=`docker-compose ps -q $service`
    if [[ -z $container_id ]] ;
    then
        echo "Error could not find service $service, please make sure that the service with name \"$service\" exists in your current mu project."
        exit 1
    fi
    mkdir -p /tmp/mu/cache/$container_id
    docker cp $container_id:/app/scripts /tmp/mu/cache/$container_id
    cat_command="cat /tmp/mu/cache/$container_id/scripts/config.json"
    if [[ "-h" == $command ]] ;
    then
        echo "The commands supported by $service are listed below."
        echo "you can invoke them by typing 'mu script $service [COMMAND]'."
        echo ""
        echo "Service $service supports the following commands:"
        jq_command="jq -r '( .scripts[].documentation.command )'"
        supported_commands=`sh -c "docker run --volume /tmp:/tmp --rm semtech/mu-cli:testversion bash -c \"$cat_command | $jq_command\""`
        echo $supported_commands
        exit 0
    fi
    echo -n "Executing "
    jq_command="jq -c '( .scripts[] | select(.documentation.command == \\\"$command\\\") )'"
    command_spec=`sh -c "docker run --volume /tmp:/tmp --rm semtech/mu-cli:testversion bash -c \"$cat_command | $jq_command\""`
    if [[ -z $command_spec ]] ;
    then
        echo ""
        echo "Error could not find command: $command for service: $service. Please refer to the documentation of the mu service to check the commands available or run 'mu script $service -h'"
        exit 1
    fi
    echo -n "."
    app_mount_point=`echo "$command_spec" | docker run --volume /tmp:/tmp --rm -i --entrypoint "/usr/bin/jq" semtech/mu-cli:testversion -r .mounts.app`
    app_folder="$PWD"
    echo -n "."
    script_path=`echo "$command_spec" | docker run --volume /tmp:/tmp --rm -i --entrypoint "/usr/bin/jq" semtech/mu-cli:testversion -r .environment.script`
    echo -n "."
    script_folder_name=`dirname $script_path`
    script_file_name=`basename $script_path`
    folder_name="$script_folder_name"
    entry_point="$script_file_name"
    working_directory="/script"
    arguments="${@:4}"
    echo -n "."
    image_name=`echo "$command_spec" | docker run --volume /tmp:/tmp --rm -i --entrypoint "/usr/bin/jq" semtech/mu-cli:testversion -r .environment.image`
    echo ""
    docker run --volume $PWD:$app_mount_point --volume /tmp/mu/cache/$container_id/scripts/$folder_name:/script -it -w $working_directory --rm --entrypoint ./$entry_point $image_name $arguments
    rm -rf /tmp/mu/cache/$container_id
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
