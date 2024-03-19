#!/bin/bash -e
#
# Usage: ./update.sh [release_tag]
#
# Updates to given Boost version and/or regenerates all setup files.
#

TAG="$1"

HEADERS=""

join_by() {
	local IFS="$1"
	shift
	echo "$*"
}

list_libraries() {
    find . -mindepth 1 -maxdepth 1 -type d | cut -d/ -f2 | sort
}

xcode_header_search_paths() {
    list_libraries | while read lib ; do
        echo "\$(BOOST)/$lib/include"
    done
}

msvc_additional_includes() {
    list_libraries | while read lib ; do
        echo "\$(BOOST)\\\\$lib\\\\include"
    done
}


LIBS=$(list_libraries)


if [ -n "$TAG" ] ; then
    echo "Checking out tag $TAG..."
    for lib in $LIBS ; do
        git -C $lib checkout $TAG
    done
fi


echo "Updating Xcode config file..."
XCODE_PATHS=$(join_by " " $(xcode_header_search_paths))
sed -e "s@^\(HEADER_SEARCH_PATHS =\) .*@\1 ${XCODE_PATHS} \$(inherited)@g" boost.xcconfig >boost.xcconfig.new
mv -f boost.xcconfig.new boost.xcconfig


echo "Updating Visual Studio property sheet..."
MSVC_PATHS=$(join_by ";" $(msvc_additional_includes))
sed -e "s@\(<BoostIncludes>\).*<@\1${MSVC_PATHS}<@g" boost.props >boost.props.new
mv -f boost.props.new boost.props


echo "Sorting git submodules..."
awk 'BEGIN { I=0 ; J=0 ; K="" } ; /^\[submodule/{ N+=1 ; J=1 ; K=$2 ; gsub(/("vendor\/|["\]])/, "", K) } ; { print K, N, J, $0 } ; { J+=1 }' .gitmodules \
    | sort \
    | awk '{ $1="" ; $2="" ; $3="" ; print }' \
    | sed 's/^ *//g' \
    | awk '/^\[/{ print ; next } { print "\t", $0 }' \
    > .gitmodules.new
mv -f .gitmodules.new .gitmodules
