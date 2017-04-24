

# Docker-mk-5

Инсрукция по использованию скрипта развертывания
```
$ mk-helpers/preseed.sh
Usage:
--provision - provision VM and deploy gitlab on it
--seed - seed projects from backup
--create_images - create base docker images for ci builds and push them to registry
--runner - reconfigure gitlab ci runner
--full - fulfill all presented stages
```

## Getting started

Скачать репозиторий с необходимыми данными
```
$ wget https://s3.eu-central-1.amazonaws.com/docker-mk-mar-2017/module5/data.zip
$ unzip data.zip && rm -f data.zip
```
В файле data/creds.env выставить значения переменных
```
NAME = your_name
```
Скачать сам репозиторий
```
$ git clone https://github.com:chromko/docker-mk-5-new.git
$ cd docker-mk-5-new
```

Запустить процесс развертывания в AWS и ждать завершения
```
mk-helpers/preseed.sh --full
```
Для развертывания в parallels или virtualbox указать флаг 'p' или 'v' соответственно
```
mk-helpers/preseed.sh --full p
```

Для подключения к docker-engine на созданной ВМ запустить:
```
source mk-helpers/env.vars
docker ps
....
```
Клонировать репозитории для мк (будут содержаться в папке module5_app):
```
sh mk-helpers/clone-repos.sh
```
