#!/bin/bash

# migrate articles and stories from drupal 6 to nikola
# Copyright 2014 Johan Vervloet
# You can use and distribute this script under the terms of the
# GNU General Public License version 3 or later.

# Notes:
#  * my drupal site has no multiple revisions of posts.
#  * I had one vocabulary that I used for tagging posts.
#  * you need to have pandoc installed for this script to work.


# please change the two variables below
# according to your needs

# mysql command to connect to your drupal database
MYSQL_CMD="mysql -N -s -u root johanv6"
# directory to save the files
OUT_DIR="/tmp/out"

mkdir -p $OUT_DIR

nodes=$(echo "
      SELECT nid
      FROM node
      WHERE status > 0
      " | $MYSQL_CMD);

for nid in $nodes
do
      out_file=$OUT_DIR/$nid.rst

      details=$(echo "
              SELECT FROM_UNIXTIME(created),title
              FROM node
              WHERE nid=$nid
              " | $MYSQL_CMD | sed 's/\t/;/g');

      created=`echo $details | cut -f 1 -d\;`
      title=`echo $details | cut -f 2 -d\;`

      tags=$(echo "
              SELECT GROUP_CONCAT(td.name)
              FROM term_node tn JOIN term_data td ON tn.tid=td.tid
              WHERE tn.nid=$nid
              " | $MYSQL_CMD);

      cat > $out_file << EOF
.. title: $title
.. slug: node-$nid
.. date: $created
.. tags: $tags
.. link:
.. description:
.. type: text

EOF


      echo "SELECT body FROM node_revisions WHERE nid=$nid" | \
      $MYSQL_CMD | \
# convert node from html to rst
      pandoc --from=html --to=rst | \
# some trial and error for newlines
      sed 's/\\\\n/\n/g' | \
# convert references to other posts
      perl -p -000 -e 's;`((\s|[^<])*)</node/([0-9]*)>`__;:doc:`\1<node-\3>`;g' | \
# lots of trial and error to convert inline code
        perl -p -000 -e 's/``([^`]*\\n[^`]*)``/\n\n::\n\n\1\n\n/g' | \
      sed 's/\\n/\n  /g' | sed 's/\\t/\t/g' | sed 's/\\ / /g' | \
# convert video-links to youtube-links
# I did the conversion of \_ to _ manually
      sed 's/\[video:.*[/=]\([^/=]*\)\]/.. youtube:: \1/g' >> $out_file

# some output to show progress
      echo -n .

done

