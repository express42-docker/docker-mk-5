

# Docker-mk-5

Инсрукция по использованию скрипта развертывания
```
$ mk-helpers/preseed.sh
Usage:
--provision        -        provision VM and deploy gitlab on it
--seed             -        seed projects from backup
--create_images    -        create base docker images for ci builds and push them to registry
--runner           -        reconfigure gitlab ci runner
--full             -        fulfill all presented actions
-p                 -        along with --provision used to up parallels env
-v                 -        along with --provision used to up virtualbox env
```

## Quick start

Скачать сам репозиторий
```
$ git clone https://github.com:chromko/docker-mk-5-new.git
$ cd docker-mk-5-new
```

```
В файле data/creds.env выставить значения переменных
```
NAME=your_name
```

Запустить процесс развертывания в AWS и ждать завершения
```
mk-helpers/preseed.sh --full
...
Адрес вашего сервера: <Адрес вашей docker machine>
Gitlab login: root
Gitlab password: dockermk

```
Для развертывания в parallels или virtualbox указать флаг '-p' или '-v' соответственно
```
mk-helpers/preseed.sh --full -p
```

Для подключения к docker-engine на созданной ВМ запустить:
```
source mk-helpers/env.vars
docker ps
....

Клонировать репозитории для мк (будут содержаться в папке module5_app):
```
sh mk-helpers/clone-repos.sh
```

## Gitlab Workflow

1. Автоматическое развертывание стенда mk-helpers/preseed.sh:
  - --provision
    - Поднятие виртуальной машины (aws,parallels,virtualbox)
    - Подготовка dockerd и /etc/hosts для использования insecure local registry
  - --seed
    - Восстановление базы проектов из бекапа
    - Внесение secure variables в каждый проект (DEV\_HOST и BUILD\_TOKEN)
  - --create\_images
    - Клонирование репозиториев для базовых образов docker (dind, git-compose)
    - Сборка образов и push в local registry
  - --runner
    - (пере)создание toml файла для gitla-ci-runner и перезапуск контейнера
  - --full
    - все вместе
2. Запуск gitlab-ci pipeline
  - Подготовка
    - В gitlab-ci-runner через volume пробрасывается sock
    - Для ускорения и упрощения коммуникации каждый сборочный контейнер присоединяется к сети dockermk5\_default (в ней нахоядтся сам runner и gitlab с его  gitlab-registry.local)
    - Gitlab-ci-runner запускает контейнер из образа docker:dind
    - Gitlab-ci-runner запускает runner контейнер
    - В переменной окружения DOCKER\_HOST (.gitlab-ci.yml файл) ссылаемся на docker-engine внутри контенера с docker:dind
    - Используется переменная DOCKER\_DRIVER со значением используемого storage driver для сборки образов (vfs по-умолчанию медленный)
  - Ход работы
    - Внутри runner контенера происходит процесс одного job&#39;а
    - Job&#39; ы в одинаковом stage проекта выполняются параллельно (и в разных проектах, если позволяет  concurrent значение runner&#39;а)
    - После окончания job&#39;ы контейнер выключается, а вся информация по сборке пропадает (кроме /cached и /artifacts (если есть).
  - Во время сборок проектов используется несколько директив docker
    - --cache-from  - позволяет использовать скаченный(pull) образ и как источник сборочного кэша
    - --pull  - заставляет docker постоянно проверять актуальную версию базового образа (FROM image:tag )
  - В случае необходимости сохранить собранный артифакт в виде docker образа – происходит push в local registry
  - Chaining
    - После release стадии запускается стадия notify, которая , используя BUILD\_TOKEN (постоянный, выданный пользователю root) и id проекта, создает новый pipeline этого проекта
3. Deploy
  - На стадии deploy запускается docker-compose, который разворачивает на DEV\_HOST машине контейнеры с проектом блога.
  - Во вкладке pipelines-&gt;environments проекта(blog\_ui) появляется запись о созданном окружении(dev) и ссылка на сайт проекта. У остальных(blog\_backend, mongodb) deployment проектов ссылки  нет (окружение есть).

## Gitlab Ci Monitoring

1. Gitlab имеет встроенный Prometheus, а также ряд экспортеров:
  - Node exporter
  - Gitalb-monitor(Database, Sidekiq, Process); В версии 1.3 экспортера завезли статистику билдов (пока не в релизе гитлаба)
  - Redis
  - Postgres
  - Prometheus
  - Kubernetes
  - Gitlab-ci-runner exporter (запускается с помощью директивы monitor\_server в toml)
  - Gilab pages
2. Gitlab EE имеет deploy-board
3. Gitlab может выводить dashboards для мониторинга kubernetes приложений
