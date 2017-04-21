#!/usr/bin/env bash
# This script restore saved configuration to Gitlab.

source data/creds.env
source mk-helpers/env.vars
eval $(docker-machine env $machine)


BACKUP=1488485820_2017_03_02
BACKUP_FILE="$BACKUP"_gitlab_backup.tar

printf "Подготовка проектов\n"
docker-compose exec gitlab wget https://s3.eu-central-1.amazonaws.com/docker-mk-mar-2017/module5/$BACKUP_FILE -P /var/opt/gitlab/backups/

printf "Импортируем проекты\nОтвечаем 'yes' на вопросы из терминала\n"
docker-compose exec gitlab /opt/gitlab/bin/gitlab-rake gitlab:backup:restore BACKUP=$BACKUP
#
#
# printf "\nАктуализируем конфигурацию CI"
# for i in `seq 1 6`;
# do
   docker-compose exec -T gitlab gitlab-rails runner "\
    # Ci::Variable.create :key => \"DEV_HOST\", :value => \"$module5_host\", :gl_project_id => $i; "
    # printf "."
# done
#
