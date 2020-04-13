#!/bin/bash

# comment out the info mu semtech repo when testing locally
#repository="https://info.mu.semte.ch"
#repository="http://localhost"
repository=$1


# stripping out : and / from the repository name
repository_name="${repository//https:\/\/}"
repository_name="${repository_name//http:\/\/}"

# we will ensure the default musemtech directory is there
mkdir -p /tmp/musemtech

# comment out the following line when testing locally
# repository_name="info.mu.semte.ch"

function ensure_fresh_semtech_images() {
    if test -f "/tmp/musemtech/$repository_name.images"; then
        # check if the images cache is less than 20 hrs old
        if test `find "/tmp/musemtech/$repository_name.images" -mmin +1200`
        then
            get_mu_info_images
        fi
    else
        get_mu_info_images
    fi
}

function get_revisions_for_service() {
    service=$1
    revision_link=$2

    tag_list=""
    tags=`curl -s $repository$revision_link | jq '.data[].attributes.version'`
    for tag in $(echo "$tags" | jq '.'); do
        stripped_tag="${tag:1:-1}"
        tag_list="$tag_list $stripped_tag"
    done

    echo "$tag_list" > /tmp/musemtech/$repository_name.$service.tags
}

function get_mu_info_images() {
    images_array=`curl -s $repository/microservices | jq '.data[]'`

    ac_image_list=""
    # TODO to this less ugly
    for image in $(echo "$images_array" | jq '. | "\(.attributes.title)!\(.relationships.revisions.links.related)"'); do
        image_title_quoted=${image%!*}
        image_title="${image_title_quoted:1}"
        revision_link_quoted=${image#*!}
        revision_link="${revision_link_quoted::-1}"

        # add the image title to the list of images
        ac_image_list="$ac_image_list $image_title"
        # populate the revisions file
        get_revisions_for_service $image_title $revision_link
    done

    for image in $(echo "$images_array" | jq '. | "\(.attributes.title)!\(.attributes."installation-script")"'); do
        image_title_quoted=${image%!*}
        image_title="${image_title_quoted:1}"
        installation_script_quoted=${image#*!}
        installation_script="${installation_script_quoted::-1}"
        echo "$installation_script" > /tmp/musemtech/$repository_name.$image_title.installation_script
    done

    images_list=()
    images_list_var=$(echo "$images_array" | jq '. | "\(.attributes.title)"')
    for img in $images_list_var; do
        images_list+=($img)
    done

    compose_snippets=$(echo "$images_array" | jq '. | "\(.attributes."compose-snippet"|tostring)"')
    SAVEIFS=$IFS   # Save current IFS
    IFS=$'\n'      # Change IFS to new line
    compose_snippets=($compose_snippets) # split to array $names
    IFS=$SAVEIFS   # Restore IFS
    for ((i = 0; i < ${#compose_snippets[@]}; i++))
    do
        snippet="${compose_snippets[$i]}"
        image="${images_list[$i]}"
        image=${image%!*}
        image="${image:1}"
        image="${image::-1}"
        echo "$snippet" > /tmp/musemtech/$repository_name.$image.compose_snippet
    done

    development_snippets=$(echo "$images_array" | jq '. | "\(.attributes."development-snippet"|tostring)"')
    SAVEIFS=$IFS   # Save current IFS
    IFS=$'\n'      # Change IFS to new line
    development_snippets=($development_snippets) # split to array $names
    IFS=$SAVEIFS   # Restore IFS
    for ((i = 0; i < ${#development_snippets[@]}; i++))
    do
        snippet="${development_snippets[$i]}"
        image="${images_list[$i]}"
        image=${image%!*}
        image="${image:1}"
        image="${image::-1}"
        echo "$snippet" > /tmp/musemtech/$repository_name.$image.development_snippet
    done

    creation_snippets=$(echo "$images_array" | jq '. | "\(.attributes."creation-snippet"|tostring)"')
    SAVEIFS=$IFS   # Save current IFS
    IFS=$'\n'      # Change IFS to new line
    creation_snippets=($creation_snippets) # split to array $names
    IFS=$SAVEIFS   # Restore IFS
    for ((i = 0; i < ${#creation_snippets[@]}; i++))
    do
        snippet="${creation_snippets[$i]}"
        image="${images_list[$i]}"
        image=${image%!*}
        image="${image:1}"
        image="${image::-1}"
        echo "$snippet" > /tmp/musemtech/$repository_name.$image.creation_snippet
    done

    echo "$ac_image_list" > /tmp/musemtech/$repository_name.images
}

function ensure_fresh_image_tags() {
    IMAGE=$1
    # check that the file exists
    if test -f "/tmp/musemtech/$repository_name.$IMAGE.tags"; then
        # check if the tags cache for the passed image cache is less than 20 hrs old
        if test `find "/tmp/musemtech/$repository_name.$IMAGE.tags" -mmin +1200`
        then
            get_mu_info_images
        fi
    else
        get_mu_info_images
    fi
}

ensure_fresh_semtech_images
get_mu_info_images
