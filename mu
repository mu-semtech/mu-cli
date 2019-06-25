#!/bin/bash

if [[ "ember" == $1 ]]
then
    echo "Ember project commands";
    if [[ "start" == $2 ]]
    then
        PROJECT_NAME=$3
        echo "Starting ember project named: $PROJECT_NAME"
        cd ~/code/ember/$PROJECT_NAME
        eds --proxy http://host/
    elif [[ "shell" == $2 ]]
    then
        PROJECT_NAME=$3
        echo "Entering project shell for $PROJECT_NAME"
        cd ~/code/ember/$PROJECT_NAME
        echo "This looks like the start of a great hack..."
    elif [[ "new" == $2 ]]
    then
        PROJECT_NAME=$3
        echo "Creating new ember project for $PROJECT_NAME"
        cd ~/code/ember/
        edi ember new $PROJECT_NAME
        cd $PROJECT_NAME
        edi ember install ember-cli-materialize
        rm app/styles/app.css
        git add app/styles/app.scss
        git commit -a -m "Installing ember-cli-materialize"
        edi ember install ember-router-scroll
        git commit -a -m "Installing ember-router-scroll"
        echo "Your ember project is ready for hacking..."
    else
        echo "Don't know command $2"
        echo "Known ember commands: [ start, shell, new ]"
    fi
elif [[ "project" == $1 ]]
then
    echo "Mu project commands"
    if [[ "start" == $2 ]]
    then
        PROJECT_NAME=$3
        echo "Starting docker-compose for $PROJECT_NAME"
        cd ~/code/mu/$PROJECT_NAME
        docker-compose up
    elif [[ "shell" == $2 ]]
    then
        PROJECT_NAME=$3
        echo "Starting shell for $PROJECT_NAME"
        cd ~/code/mu/$PROJECT_NAME
        echo "Go go, goooo muhmuh go...  go go... muhmuh be good"
    elif [[ "new" == $2 ]]
    then
        PROJECT_NAME=$3
        echo "Creating new mu project for $PROJECT_NAME"
        cd ~/code/mu
        git clone https://github.com/mu-semtech/mu-project.git $PROJECT_NAME
        cd ~/code/mu/$PROJECT_NAME/
        rm -Rf ./.git
        git init .
        git add .
        git commit -m "Creating new mu project"
        echo "Your mu project hack gear is ready to be hacked... hack on"
    elif [[ "doc" == $2 ]]
    then
        PROJECT_NAME=$3
        echo "Generating documentation for $PROJECT_NAME"
        cd ~/code/mu/$PROJECT_NAME/
        docker run --rm -v `pwd`/config/resources:/config -v `pwd`/tmp:/config/output/ madnificent/cl-resources-plantuml-generator
        echo "Generated JSONAPI svg"
        docker run --rm -v `pwd`/config/resources:/config -v `pwd`/tmp:/config/output/ madnificent/cl-resources-ttl-generator
        echo "Generated ttl file for http://visualdataweb.de/webvowl/"
    else
        echo "Don't know command $2"
        echo "Known project commands: [ start, shell, new, doc ]"
    fi
elif [[ "service" == $1 ]]
then
    echo "Mu service commands"
    if [[ "shell" == $2 ]]
    then
        echo "Opening service"
        LANGUAGE=$3
        SERVICE_NAME=$4
        echo "Opening service in language $LANGUAGE with name $SERVICE_NAME"
        cd ~/code/$LANGUAGE/$SERVICE_NAME
    elif [[ "new" == $2 ]]
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
            cd ~/code/ruby/
            mkdir $SERVICE_NAME
            cd $SERVICE_NAME
            echo "FROM semtech/mu-ruby-template:2.0.0-ruby2.3" >> Dockerfile
            echo "MAINTAINER $USER_NAME <$EMAIL>" >> Dockerfile
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
            echo "    image: semtech/mu-ruby-template:2.0.0-ruby2.3"
            echo "    links:"
            echo "      - db:database"
            echo "    ports:"
            echo '      - "8888:80"'
            echo "    environment:"
            echo '      RACK_ENV: "development"'
            echo "    volumes:"
            echo "      - \"/home/$USER/code/$LANGUAGE/$SERVICE_NAME/:/app\""
            echo ""
            echo "All set to to hack!"
        elif [[ "javascript" == $LANGUAGE ]]
        then
            USER_NAME=`git config user.name`
            EMAIL=`git config user.email`
            USER=`whoami`
            echo "Creating new javascript service for $SERVICE_NAME"
            cd ~/code/javascript/
            mkdir $SERVICE_NAME
            cd $SERVICE_NAME
            echo "FROM semtech/mu-javascript-template:1.3.5" >> Dockerfile
            echo "MAINTAINER $USER_NAME <$EMAIL>" >> Dockerfile
            echo "# see https://github.com/mu-semtech/mu-javascript-template for more info" >> Dockerfile
            echo "# see https://github.com/mu-semtech/mu-javascript-template for more info" >> app.js
            echo "" >> app.js
            echo "import { app, query, errorHandler } from 'mu';" >> app.js
            echo "" >> app.js
            echo "app.get('/', function( req, res ) {" >> app.js
            echo "  res.send('Hello mu-javascript-template');" >> app.js
            echo "} );" >> app.js
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
            echo "    environment:"
            echo '      NODE_ENV: "development"'
            echo "    volumes:"
            echo "      - \"/home/$USER/code/$LANGUAGE/$SERVICE_NAME/:/app\""
            echo ""
            echo "All set to to hack!"
        else
            echo "Don't know language $LANGUAGE"
            echo "Known languages: [ ruby, js ]"
        fi
    else
        echo "Don't know service command $2"
        echo "Known commands: [ shell, new ]"
    fi
elif [[ $1 == "migration" ]]
then
    if [[ $2 == "new" ]]
    then
        PROJECT=$3
        MIGRATION_NAME=$4
        MIGRATION_TIMESTAMP=`date +%Y%0m%0d%0H%0M%0S`
        FILENAME="$MIGRATION_TIMESTAMP-$MIGRATION_NAME.sparql"
        PROJECT_DIRECTORY=~/code/mu/$PROJECT
        echo "Creating migration for project $PROJECT with name $FILENAME"
        if [[ -d $PROJECT_DIRECTORY ]]
        then
            mkdir -p $PROJECT_DIRECTORY/config/migrations/
            cd $PROJECT_DIRECTORY/config/migrations/
            touch $FILENAME
            echo "$PROJECT_DIRECTORY/config/migrations/$FILENAME"
        else
            echo "Could not find mu project $PROJECT in $PROJECT_DIRECTORY"
        fi
    else
        echo "Don't know migration command $2"
        echo "Known commands: [ new ]"
    fi
else
    echo "Don't know command $1"
    echo "Known commands [ project, ember, service, migration ]"
fi
