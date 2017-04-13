#!/usr/bin/env bash
# This script create docker-machine with Gitlab.
# Without parameters start Docker host in Amazon. With v - in Virtualbox, p - in Parallels.

source mk-helpers/env.vars
source data/creds.env
SRC_CERTS=~/.docker/machine/machines/$machine/*.pem
DST_CERTS=images/docker-git-compose/certs

printf "\nСоздаем сервер с Gitlab CI\n"
case $1 in
  'p' ) docker-machine create -d parallels --parallels-cpu-count 4 --parallels-disk-size "8440" --parallels-memory "4048" $machine;;
  'v' ) docker-machine create -d virtualbox --virtualbox-cpu-count 2 --virtualbox-disk-size "8440" --virtualbox-memory "4048" $machine;;
  * ) docker-machine create -d amazonec2 --amazonec2-root-size "60" --amazonec2-instance-type "t2.large" --amazonec2-region "eu-central-1" --amazonec2-subnet-id "subnet-ccbf57a5" $machine;;
esac

source mk-helpers/env.vars

# Set machine vars
eval $(docker-machine env $machine)

# Create gitlab CI image
cp -r $SRC_CERTS $DST_CERTS
printf "\n\n\nСоздаем образ для CI агента\n"
docker build -t $DOCKERHUB_USER/docker:git-compose images/docker-git-compose
docker login -u $DOCKERHUB_USER -p $DOCKERHUB_PASSWORD
docker push $DOCKERHUB_USER/docker:git-compose

# Setup infrastructure
printf "\n\n\nСоздаем пользователя и обновляем регистрацию\n"
docker-compose up -d

while [ $(curl --write-out %{http_code} --silent --output /dev/null http://$module5_host/users/sign_in) -ne 200 ]; do
  # Убираем возможность регистрации на время мастер-класса
  docker-compose exec -T gitlab gitlab-rails runner "ApplicationSetting.last.update_attributes(signup_enabled: false)" > /dev/null

  # Создаем пользователя
  docker-compose exec -T gitlab gitlab-rails runner "user = User.find_by(email: 'admin@example.com'); user.password = \"$GITLAB_PASSWORD\"; user.password_confirmation = \"$GITLAB_PASSWORD\"; user.password_automatically_set = false; user.save" > /dev/null
done

printf "\n\nАдрес вашего сервера: $module5_host\n"
printf "Gitlab login: $GITLAB_USER\n"
printf "Gitlab password: $GITLAB_PASSWORD\n"
