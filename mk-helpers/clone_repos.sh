#!/usr/bin/env bash
# This script clone blog repos to parent_dir/module5_app

source data/creds.env
source mk-helpers/env.vars
eval $(docker-machine env $machine)

DIR="module5_app_test"
mkdir $DIR
cd $DIR

for i in ubuntu ruby mongodb blog_ui blog_backend blog; do
  printf "Trying to clone $i repo\n"
  cd ~/Work_Projects/express42/docker/module5_app_test/$i
  rm -rf .git
  git init
  git remote add upstream http://root:dockermk@10.211.55.60/module5/$i.git
  git fetch upstream
  git add . && gc -m "init commit [skip ci]"
  git push --set-upstream upstream master
done
#  git clone http://$GITLAB_USER:$GITLAB_PASSWORD@$module5_host/module5/$i.git;

# echo "Change dir to $DIR for working with Gitlab repo"
#
# for i in ubuntu ruby mongodb blog_ui blog_backend blog; do
#   printf "Push updated changes"
#   cd $i; git commit -am "Up"; \
#   git push origin master; \
#   cd ../
# done
