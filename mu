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
elif [[ $1 == "migration" ]]
then
    if [[ $2 == "new" ]]
    then
        MIGRATION_NAME=$3
        MIGRATION_TIMESTAMP=`date +%Y%0m%0d%0H%0M%0S`
        FILENAME="$MIGRATION_TIMESTAMP-$MIGRATION_NAME.sparql"
        echo "Creating migration with name $FILENAME"
        mkdir -p config/migrations/
        cd config/migrations/
        touch $FILENAME
        echo "config/migrations/$FILENAME"
    else
        echo "Don't know migration command $2"
        echo "Known commands: [ new ]"
    fi
else
    echo "Don't know command $1"
    echo "Known commands [ project, service, migration ]"
fi
