#!/bin/sh
# Usage: ./knn.sh [K]
#
# K defaults to 1 if not given.

k_value="${1:-1}"

k() {
    echo "$k_value"
}

knn() {
    java -jar Mars4_5.jar knn.s
}

skip_mars_copyright() {
    tail -n +3
}

k | knn | skip_mars_copyright
