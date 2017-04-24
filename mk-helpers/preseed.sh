#!/usr/bin/env bash
# This script create docker-machine with Gitlab.
# Without parameters start Docker host in Amazon. With v - in Virtualbox, p - in Parallels.

# Creating machine with remote provider
source mk-helpers/env.vars
provision() {

  if [[ ! $(docker-machine status $machine) = "Running" ]]; then
    printf "\nСоздаем сервер с Gitlab CI\n"
    case $1 in
      'p' ) docker-machine create -d parallels --parallels-cpu-count 4 --parallels-disk-size "26000" --parallels-memory "4048" $machine;;
      'v' ) docker-machine create -d virtualbox --virtualbox-cpu-count 4 --virtualbox-disk-size "26000" --virtualbox-memory "4048" $machine;;
      * ) docker-machine create -d amazonec2 --amazonec2-root-size "12" --amazonec2-instance-type "t2.medium" --amazonec2-region "eu-central-1" --amazonec2-subnet-id "subnet-ccbf57a5" $machine;;
    esac
  fi
    # Set machine vars
      source mk-helpers/env.vars
    # Setup infrastructure
    docker-compose --project-name dockermk5 up -d

    printf "\n\n\nСоздаем пользователя и обновляем регистрацию\n"


    while [ $(curl --write-out %{http_code} --silent --output /dev/null http://$module5_host/users/sign_in) -ne 200 ]; do
      # Убираем возможность регистрации на время мастер-класса
      docker-compose exec -T gitlab gitlab-rails runner "ApplicationSetting.last.update_attributes(signup_enabled: false)" > /dev/null

      # Создаем пользователя
      docker-compose exec -T gitlab gitlab-rails runner "user = User.find_by(email: 'admin@example.com'); user.password = \"$GITLAB_PASSWORD\"; user.password_confirmation = \"$GITLAB_PASSWORD\"; user.password_automatically_set = false; user.save" > /dev/null
    done

    printf "\n\n\nГотовим окружение к использованию  локального docker registry\n"
    #####  Prepare environment for local registry
    if ! docker-machine ssh $machine "ping $DOCKER_REGISTRY -c 1 &>  /dev/null" ; then
      docker-machine ssh $machine "sudo /bin/sh -c 'echo ${module5_host} $DOCKER_REGISTRY >> /etc/hosts'"
    fi

    if ! docker-machine ssh $machine sudo test -e /etc/docker/daemon.json  ; then
      docker-machine ssh $machine "echo {\'insecure-registries\':[\'$DOCKER_REGISTRY\']} |  tr \"'\" '\"' | sudo  tee /etc/docker/daemon.json"
      docker-machine ssh $machine sudo /etc/init.d/docker restart
    fi
      file=/srv/docker/gitlab/config/gitlab.rb

      docker-machine ssh $machine "sudo sed -i 's/.*registry_external_url.*/registry_external_url \"http:\/\/$DOCKER_REGISTRY\"/' $file "
      docker-machine ssh $machine "sudo sed -i '/^#.*registry_enabled/s/^#//' $file"
      docker-machine ssh $machine "sudo sed -i '/^#.*registry\[.enable.\]/s/^#//' $file"
      docker-compose restart gitlab

    printf "\n\nАдрес вашего сервера: $module5_host\n"
    printf "Gitlab login: $GITLAB_USER\n"
    printf "Gitlab password: $GITLAB_PASSWORD\n"
}

seed() {

  BACKUP_FILE=${BACKUP}_gitlab_backup.tar

  printf "Подготовка проектов\n"
  docker-machine scp mk-helpers/$BACKUP_FILE $machine:~/ls
  docker-machine ssh $machine "sudo cp ~/$BACKUP_FILE /srv/docker/gitlab/data/backups/"

  # docker-compose exec gitlab wget https://s3.eu-central-1.amazonaws.com/docker-mk-mar-2017/module5/$BACKUP_FILE -P /var/opt/gitlab/backups/

  printf "Импортируем проекты\n"
  docker-compose exec gitlab sh -c "yes yes | /opt/gitlab/bin/gitlab-rake gitlab:backup:restore BACKUP=$BACKUP"

  ### Add variables
  printf "\nАктуализируем конфигурацию CI"
  for i in `seq 10 16`;
  do
      docker-compose exec -T gitlab gitlab-rails runner "\
      Ci::Variable.create :key => \"DEV_HOST\", :value => \"$module5_host\", :project_id => $i;
      Ci::Variable.create :key => \"BUILD_TOKEN\", :value => \"$BUILD_TOKEN\", :project_id => $i; "
      printf "."

  done

  docker-compose restart gitlab
}

# Create gitlab CI images

create_images() {

  SRC_CERTS=~/.docker/machine/machines/$machine/*.pem
  DST_CERTS=images/docker-git-compose/certs

  mkdir images

  printf "\n\n\nЖдём загрузки Gitlab\n"

  while [ $(curl --write-out %{http_code} --silent --output /dev/null http://$module5_host/users/sign_in) -ne 200 ]; do
    sleep 1
  done

  docker login -u $GITLAB_USER -p $GITLAB_PASSWORD $DOCKER_REGISTRY
  printf "\n\n\nСоздаем образ для CI агента\n"
  if ! docker pull $DOCKER_REGISTRY/module5/docker:git-compose &> /dev/null ; then
      git clone http://$GITLAB_USER:$GITLAB_PASSWORD@${module5_host}/module5/docker.git --branch git-compose images/docker-git-compose
      if [ ! -d $DST_CERTS ]; then
        printf "\n\n\nКопируем ключи для управления docker\n"
        mkdir -p  $DST_CERTS
        cp -r $SRC_CERTS $DST_CERTS
      fi
      docker build -t $DOCKER_REGISTRY/module5/docker:git-compose images/docker-git-compose
      docker push $DOCKER_REGISTRY/module5/docker:git-compose
  fi

  if ! docker pull $DOCKER_REGISTRY/module5/docker:dind &> /dev/null ; then
    git clone http://$GITLAB_USER:$GITLAB_PASSWORD@${module5_host}/module5/docker.git --branch dind images/docker-dind
    docker build -t $DOCKER_REGISTRY/module5/docker:dind images/docker-dind
    docker push $DOCKER_REGISTRY/module5/docker:dind
  fi
}

#### Register runner
runner() {
  printf "\nРегистрируем CI агент\n"
  docker-compose exec gitlab_runner sh -c '/bin/echo > /etc/gitlab-runner/config.toml'
  docker-compose exec gitlab_runner gitlab-runner register -n
  docker-compose exec gitlab_runner sed -i s/concurrent\ =\ 1/concurrent\ =\ 2/ /etc/gitlab-runner/config.toml
  docker-compose restart gitlab_runner
}

case $1 in
  '--provision' ) provision $2;;
  '--seed'      ) seed;;
  '--create_images') create_images;;
  '--runner' ) runner;;
  '--full'    )
    provision $2
    seed
    create_images
    runner
    ;;
  * ) printf  "\
        Usage:
      --provision - provision VM and deploy gitlab on it
      --seed - seed projects from backup
      --create_images - create base docker images for ci builds and push them to registry
      --runner - reconfigure gitlab ci runner
      --full - fulfill all presented stages
      \n"
esac
