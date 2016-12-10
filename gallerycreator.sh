#!/bin/bash

INPUT_FORMAT=JPG
THUMBNAIL_DIR=thumbs
THUMBNAIL_FORMAT=png
THUMBNAIL_SIZE=150x115
GALLERY_TITLE="Gallery"
GALLERY_FILE="index.html"
SCRIPT_DIR=""
FONT_DIR="fonts"


function check_dependency {
    command -v "$1" >/dev/null 2>&1 || {
        echo >&2 "You need to install Image Magick! Try this on a Debian based system:";
        echo >&2 "sudo apt-get install imagemagick"
        exit 1;
    }
}

function check_dependencies {
    check_dependency "mogrify"
    check_dependency "convert"
}

function create_thumbnail_from_single_file {
    mogrify -format ${THUMBNAIL_FORMAT} -quality 50 -unsharp 0x.2 -path ${THUMBNAIL_DIR} -thumbnail ${THUMBNAIL_SIZE} $1
}

function create_border_on_single_file {
    infile="$1"
    outfile="$2"
    bc="#888888"

    # From http://www.imagemagick.org/Usage/thumbnails/#rounded_border

    convert "$infile" \
            -format 'roundrectangle 1,1 %[fx:w+4],%[fx:h+4] 15,15'\
            info: > tmp.mvg

    convert "$infile" -border 3 -alpha transparent \
            -background none -fill white -stroke none -strokewidth 0 \
            -draw "@tmp.mvg"    tmp_mask.png
    convert "$infile" -border 3 -alpha transparent \
            -background none -fill none -stroke "$bc" -strokewidth 1 \
            -draw "@tmp.mvg"    tmp_overlay.png


    convert "$infile" -alpha set -bordercolor none -border 3 \
            tmp_mask.png -compose DstIn -composite \
            tmp_overlay.png -compose Over -composite \
            "$outfile"

    # Cleanup of temporary files
    rm -f tmp.mvg tmp_mask.png tmp_overlay.png
}

function create_thumbnails_with_progress {
    files=( $(ls *.${INPUT_FORMAT}) )
    number_of_files=${#files[@]}
    i=1
    for f in ${files[@]}; do
        progress=$((i*100/number_of_files))
        echo -ne "Creating thumbnail of file ${i}/${number_of_files}  -  ${progress}%\r"
        i=$((i+1))
        create_thumbnail_from_single_file $f
    done
    echo ""
}

function create_borders_on_thumbnails {
    cd ${THUMBNAIL_DIR}
    files=( $(ls *.${THUMBNAIL_FORMAT}) )
    number_of_files=${#files[@]}
    i=1
    for f in ${files[@]}; do
        progress=$((i*100/number_of_files))
        echo -ne "Creating border on file ${i}/${number_of_files}  -  ${progress}%\r"
        i=$((i+1))
        create_border_on_single_file $f $f
    done
    echo ""
    cd ..
}

function create_html_links {
    files=( $(ls *.${INPUT_FORMAT}) )
    number_of_files=${#files[@]}
    i=1
    for f in ${files[@]}; do
        thumbnail=${f%.$INPUT_FORMAT}
        create_html_link $f ${thumbnail}.${THUMBNAIL_FORMAT}
    done
}

function create_html_header {
    printf "<!DOCTYPE html>\n<html>\n<head><title>${GALLERY_TITLE}</title>\n" >> ${GALLERY_FILE}

    files=( $(ls ${SCRIPT_DIR}/*.css 2>/dev/null | xargs -n 1 basename 2>/dev/null) )
    number_of_files=${#files[@]}
    i=1
    for f in ${files[@]}; do
        printf "<link rel='stylesheet' type='text/css' href='$f' />\n" >> ${GALLERY_FILE}
    done

    printf "</head>\n<body>\n\n<p class='pagetitle'>${GALLERY_TITLE}</p>\n"   >> ${GALLERY_FILE}
}

function create_html_link {
    printf "<a href='./${1}'><img src='./${THUMBNAIL_DIR}/${2}' /></a>\n" >> ${GALLERY_FILE}
}

function create_html_footer {
    printf "\n\n</body>\n</html>\n" >> ${GALLERY_FILE}
}

function copy_css {
    if [ $(ls ${SCRIPT_DIR}/*.css -1 2>/dev/null | wc -l) -ne 0 ]; then
        cp ${SCRIPT_DIR}/*.css .
    fi
}

function copy_fonts {
    if [ -d "${SCRIPT_DIR}/${FONT_DIR}" ]; then
        cp -r ${SCRIPT_DIR}/${FONT_DIR} ${FONT_DIR}
    fi
}

function create_thumbnails {
    mkdir -p ${THUMBNAIL_DIR}
    create_thumbnails_with_progress
    create_borders_on_thumbnails
}

function create_image_gallery {
    rm -f ${GALLERY_FILE}
    create_html_header
    create_html_links
    create_html_footer
    copy_css
    copy_fonts
}

function print_help {
    echo "Gallery Creator 1.0"
    echo "By Johan Sjöblom. Code is public domain"
    echo ""
    echo "Usage:"
    echo "$0 <PATH> <GALLERY_NAME>"
    echo "Example:"
    echo "$0 ~/images/italy \"Trip to Italy\""
    echo ""
    echo "Will create thumbnails in a subfolder to <PATH> called ${THUMBNAIL_DIR}."
    echo "A HTML gallery with the title <GALLERY_NAME> will be created."
}

function check_input_parameters {
    if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$#" -ne 2 ] ; then
        print_help
        exit 0
    fi
    cd $1
    GALLERY_TITLE="$2"
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
check_input_parameters "$@"
check_dependencies

create_thumbnails
create_image_gallery
