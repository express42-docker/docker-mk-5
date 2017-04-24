#!/usr/bin/env bash
# This script clone blog repos to parent_dir/module5_app

source mk-helpers/env.vars
#
DIR=module5_app
mkdir $DIR
cd $DIR

printf "clone repo"
for i in docker ubuntu ruby mongodb blog_ui blog_backend blog; do
  git clone http://$GITLAB_USER:$GITLAB_PASSWORD@$module5_host/module5/$i.git;
done
