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
![crawler1](https://github.com/rastamalik/project/blob/master/terraform/1.png?raw=true "Optional Title")
  
![crawler2](https://github.com/rastamalik/project/blob/master/terraform/2.png?raw=true "Optional Title")

 ![crawler3](https://github.com/rastamalik/project/blob/master/terraform/3.png?raw=true "Optional Title")
 
 
2. Для развертывания приложения для прогона в GitLab CI нам понадобяться два сервера, один для для запуска **gitlab-runner** второй для сервиса **Docker**.
a) Создадим VM для **gitlab-runner** с помощью **terraform**:
```
provider "google" {
  version = "1.4.0"
  project = "${var.project}"
  region  = "${var.region}"

}


resource "google_compute_instance" "app" {
   name         = "gitlab-ci"
  machine_type = "n1-standard-1"
  zone         = "${var.zone}"
  boot_disk {
    initialize_params {
      image = "${var.disk_image}"
    }
  }

  metadata {
    sshKeys = "appuser:${file(var.public_key_path)} "
        
 }
  
  network_interface {
    network       = "default"
    access_config = {}
  }
  connection {
    type        = "ssh"
    user        = "appuser"
    agent       = false
    private_key = "${file(var.private_key)}"
  }
  
  provisioner "remote-exec" {
    script = "files/docker.sh"
  }
}
```

b) Создадим VM для **Docker-сервиса** с помощью **docker-machine**:
```
docker-machine create --driver google \
   --google-project  docker-193613   \
   --google-zone europe-west1-b \
   --google-machine-type n1-standard-1 \
   --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
   docker-host2
```
e) Необходимо развернуть защищенное соединение между **gitlab-runner** и сервисом **Docker** на сервере **docker-host2**.
* заходим по ssh на docker-host2
* и проделываем следующии операции:
```
$ mkdir certificates
$ cd certificates
$ openssl genrsa -aes256 -out ca-key.pem 4096
$ openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem
$ openssl genrsa -out server-key.pem 4096
$ openssl req -subj "/CN=docker-host2" -sha256 -new -key server-key.pem -out server.csr
$ echo subjectAltName = DNS:manager,IP:<IP сервера где запущен gitlab-runner> >> extfile.cnf
$ openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem \
  -CAcreateserial -out server-cert.pem -extfile extfile.cnf
$ openssl genrsa -out key.pem 4096
$ openssl req -subj '/CN=client' -new -key key.pem -out client.csr
$ echo extendedKeyUsage = clientAuth >> extfile.cnf
$ openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem \
  -CAcreateserial -out cert.pem -extfile extfile.cnf
$ rm -v client.csr server.csr
В итоге мы получим следующие файлы:
$ ls
ca-key.pem  ca.srl    extfile.cnf  server-cert.pem
ca.pem      cert.pem  key.pem      server-key.pem
```
d) Настроим сервер с **Gitlab-runner**:
* зайдем по ssh на серверб,создадим каталоги ```mkdir -p /srv/gitlab/config /srv/gitlab/data /srv/gitlab/logs```, и создадим **docker-compose.yml** в каталоге **/srv/gitlab/** с содержимым:
```
web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'gitlab.example.com'
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url 'http://<YOUR-VM-IP>'
  ports:
    - '80:80'
    - '443:443'
    - '2222:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'
  ```
  
