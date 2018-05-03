# project
1. Проект **CRAWLER** разбит на три части:
* Это описание работы приложения на **docker-host**
* Выкатывание приложения на **Gitlab-CI**
* Мониторинг и логирование.


1. Описание репозитория и запуск приложения на **docker-host** в GCP.
а) Репозиторий имеет такую структуру:
* в корне ренпозитория лежат файлы:
```
 docker-compose.yml - docker файл для запуска приложения на docker-машине,
 docker-compose-monitoring.yml - docker файл для запуска Prometheus, Alertmanager, Grafana,
 docker-compose-logging.yml - docker файл для запуска fluentd, elasticsearch, kibana
 .gitlab-ci.yml - файл для сборки и прогона приложения на GitLab -CI
 
 ```
 * папка **searh_engune_crawler** содержит поисковый бот **crawler.py** и **Dockerfile** для запуска контейнера **crawler**
 * папка **searh_engune_ui** содержит веб-интерфейс для поиска фраз на приндексированных ботом сайтах **ui.py** и **Dockerfile**     для запуска контейнера **crawler_ui**
 * папка **terraform** файлы инфраструктуры для создания VM  в GCP для разворачивания на ней GitLab CI
 * папка **monitoring** содержит docker файлы и файлы настроек **Prometheus** и **Alertmanager**
 * папка **logging** содержит docker файл ифайл настроек для **fluentd**.
 
 b) Создание VM **docker-host** в GCP с помощью **docker-machine**:
 ```
 docker-machine create --driver google \
   --google-project  docker-193613   \
   --google-zone europe-west1-b \
   --google-machine-type n1-standard-1 \
   --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
   docker-host
  ```
  d) Создание docker образов **crawler** бота и **crawler_ui** веб интерфейса:
  ```
  Dockerfile crawler
  
FROM  python:3.6.0-alpine 
RUN mkdir -p /deploy/app
COPY app /deploy/app
RUN pip install -r /deploy/app/requirements.txt
WORKDIR /deploy/app
ENV CRAWLER_APP=crawler.py
ENV MONGO mongo
ENV MONGO_PORT 27017
ENV RMQ_HOST rabbit
 
CMD ["python", "-u", "crawler.py","https://vitkhab.github.io/search_engine_test_site/"]
```
```
Dockerfile crawler_ui

FROM ubuntu:12.04
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -y python python-pip python-virtualenv gunicorn
RUN mkdir -p /deploy/app
COPY gunicorn_config.py /deploy/gunicorn_config.py
COPY app /deploy/app
RUN pip install -r /deploy/app/requirements.txt  
WORKDIR /deploy/app
ENV FLASK_APP=ui.py
ENV MONGO mongo
ENV MONGO_PORT 27017
EXPOSE 8000
CMD ["gunicorn", "--config", "/deploy/gunicorn_config.py", "ui:app"]
```
e) Соберем docker-compose файл для запуска микросервисов, кроме **crawler** и **crawler_ui**, Нам нужны сервисы **mongodb** и **rabbitmq**:
```
version: '3.3'
services:
  mongo:
    image: mongo:latest
    networks:
      - reddit
  crawler_ui:
    image: rastamalik/crawler_ui:latest
    ports:
      - 8000:8000/tcp
      
    networks:
      - reddit
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.crawler_ui
  crawler:
     image: rastamalik/crawler:latest
     networks:
       - reddit
     logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.crawler

  rabbit:
   image: rabbitmq:3-management 
   ports:
      - "15672:15672"
      - "5672:5672"
      - "5671:5671"
   environment: 
      RABBITMQ_DEFAULT_PASS: rabbitmq
      RABBITMQ_DEFAULT_USER: rabbitmq
      RABBITMQ_DEFAULT_VHOST: /

networks:
  reddit:
driver: bridge
```
При первом запуске **crawler** не сразу находит сервис **rabbitmq**, поэтому его еще раз перезапускаем после команды:
```
docker-compose up -d
docker-compose start crawler
```
Работующее приложение выглядит так:
