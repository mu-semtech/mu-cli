#!/bin/bash

function ensure_fresh_semtech_images() {
    if test -f "/tmp/mu-semte.ch.images"; then
        # check if the images cache is less than 20 hrs old
        if test `find "/tmp/mu-semte.ch.images" -mmin +1200`
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
    tags=`curl -s https://info.mu.semte.ch$revision_link | jq '.data[].attributes.version'`
    for tag in $(echo "$tags" | jq '.'); do
        stripped_tag="${tag:1:-1}"
        tag_list="$tag_list $stripped_tag"
    done

    echo "$tag_list" > /tmp/mu-semte.ch.$service.tags
}

function get_mu_info_images() {
    images_array=`curl -s https://info.mu.semte.ch/microservices | jq '.data[]'`

    ac_image_list=""
    # all i want is 2 properties out of the object that gets parsed by jq
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

    echo "$ac_image_list" > /tmp/mu-semte.ch.images
}

function ensure_fresh_image_tags() {
    IMAGE=$1
    # check that the file exists
    if test -f "/tmp/mu-semte.ch.$IMAGE.tags"; then
        # check if the tags cache for the passed image cache is less than 20 hrs old
        if test `find "/tmp/mu-semte.ch.$IMAGE.tags" -mmin +1200`
        then
            get_mu_info_images
        fi
    else
        get_mu_info_images
    fi
}

ensure_fresh_semtech_images
