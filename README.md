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

FROM  python:3.6.0-alpine 
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
 После регистрации и создания группы и пректа на Gitlab, создадим **runner**:
 ```
 gitlab-runner register -n \
  --url http://35.187.110.133/ \
  --registration-token  \
  --executor docker \
  --description "my-runner" \
  --docker-image "docker:latest" \
  --docker-privileged \
  --tag-list docker
  ```
  f) Настроим секретные переменные в Gitlab-CI:
  В настройках CI/CD в Secret variables введем переменные:
  * переменная **TLSCACERT** значение файла **ca.pem** созданным на **docker-host2**
  * переменная **TLSCERT** значение файла **cert.pem**;
  * переменная **TLSKEY** значение файла **key.pem**.
  * переменная **CI_REGISTRY_USER** login на Docker Hub
  * переменная **CI_REGISTRY_PASSWORD** пароль от Docker Hub
  ![gitlab1](https://github.com/rastamalik/project/blob/master/terraform/4.png?raw=true "Optional Title")
  
  g) Запушем наш репозиторий на **GitLab** и создадим файл сборки **.gitlab-ci.yml**:
  ```
  .gitlab-ci.yml

image: docker:stable
stages:
 - test
 - stage
 - build
 - deploy
 - stop

  

services:
- docker:dind

before_script:

 - apk add --no-cache py-pip
 - pip install docker-compose

#Стадия тестирования

unittests_ui:
  stage: test
  script:
    
    - cd search_engine_ui/tests
    - pip install -q -r requirements-test.txt
    - coverage run -m unittest discover -s /
    - coverage report ui.py
  tags:
    - docker
unittests_crawler:
  stage: test
  script:
    
    - cd search_engine_crawler/tests
    - pip install -q -r requirements-test.txt
    - coverage run -m unittest discover -s /
    - coverage report crawler.py
  tags:
    - docker 
#В стадию stage поднимаем сервисы мониторинга и логирования

docker-logging:
  stage: stage
  variables:
    DOCKER_HOST: tcp://35.205.243.235:2376
    DOCKER_TLS_VERIFY: 1
    DOCKER_CERT_PATH: "/certs"
  script:
    - mkdir -p $DOCKER_CERT_PATH
    - echo "$TLSCACERT" > $DOCKER_CERT_PATH/ca.pem
    - echo "$TLSCERT" > $DOCKER_CERT_PATH/cert.pem
    - echo "$TLSKEY" > $DOCKER_CERT_PATH/key.pem
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" $CI_REGISTRY
    - docker-compose -f docker-compose-logging.yml up -d
    - rm -rf $DOCKER_CERT_PATH
  environment:
    name: kibana
    url: http://35.205.243.235:5601
  only:
    - master
  tags:
    - docker            

# Стадия build, собираем наши образы и пушим их на Docker Hub     

docker-build:
  stage: build
  script: 
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" $CI_REGISTRY
    - cd search_engine_ui
    - docker build -t rastamalik/crawler_ui .
    - docker push rastamalik/crawler_ui
    - cd ../search_engine_crawler
    
    - docker build -t rastamalik/crawler_api .
    - docker push rastamalik/crawler_api
    - cd ..
    - cd monitoring/prometheus
    - docker build -t rastamalik/prometheus .
    - docker push rastamalik/prometheus
    - cd ../../
    - cd monitoring/alertmanager
    - docker build -t rastamalik/alertmanager .
    - docker push rastamalik/alertmanager

# Стадия deploy, поднимаем все сервисы через docker-compose 
 
docker-deploy:
  stage: deploy
  variables:
    DOCKER_HOST: tcp://35.205.243.235:2376
    DOCKER_TLS_VERIFY: 1
    DOCKER_CERT_PATH: "/certs"
  script:
    - mkdir -p $DOCKER_CERT_PATH
    - echo "$TLSCACERT" > $DOCKER_CERT_PATH/ca.pem
    - echo "$TLSCERT" > $DOCKER_CERT_PATH/cert.pem
    - echo "$TLSKEY" > $DOCKER_CERT_PATH/key.pem
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" $CI_REGISTRY
    - docker-compose up -d
    - docker-compose stop crawler
    - docker-compose start crawler
   
    - rm -rf $DOCKER_CERT_PATH
  environment:
    name: master
    url: http://35.205.243.235:8000
  only:
    - master
  tags:
    - docker
# Поднимаем мониторинг и логирование

docker-monitoring:
  stage: stage
  variables:
    DOCKER_HOST: tcp://35.205.243.235:2376
    DOCKER_TLS_VERIFY: 1
    DOCKER_CERT_PATH: "/certs"
  script:
    - mkdir -p $DOCKER_CERT_PATH
    - echo "$TLSCACERT" > $DOCKER_CERT_PATH/ca.pem
    - echo "$TLSCERT" > $DOCKER_CERT_PATH/cert.pem
    - echo "$TLSKEY" > $DOCKER_CERT_PATH/key.pem
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" $CI_REGISTRY
    - docker-compose -f docker-compose-monitoring.yml up -d
    - rm -rf $DOCKER_CERT_PATH
    
  environment:
    name: prometheus
    url: http://35.205.243.235:9090
  only:
    - master
  tags:
    - docker
docker-grafana:
 stage: stage
 script:
    - echo "Grafana"
 environment:
    name: Grafana
    url: http://35.205.243.235:3000
 only:
    - master
 tags:
    - docker
    

docker-stop-crawler:
  stage: stop
  when: manual
  variables:
    DOCKER_HOST: tcp://35.205.243.235:2376
    DOCKER_TLS_VERIFY: 1
    DOCKER_CERT_PATH: "/certs"
  script:
    - mkdir -p $DOCKER_CERT_PATH
    - echo "$TLSCACERT" > $DOCKER_CERT_PATH/ca.pem
    - echo "$TLSCERT" > $DOCKER_CERT_PATH/cert.pem
    - echo "$TLSKEY" > $DOCKER_CERT_PATH/key.pem
    - docker-compose down
  
    - rm -rf $DOCKER_CERT_PATH
    
  
  tags:
    - docker 
docker-stop-monitoring:
  stage: stop
  when: manual
  variables:
    DOCKER_HOST: tcp://35.205.243.235:2376
    DOCKER_TLS_VERIFY: 1
    DOCKER_CERT_PATH: "/certs"
  script:
    - mkdir -p $DOCKER_CERT_PATH
    - echo "$TLSCACERT" > $DOCKER_CERT_PATH/ca.pem
    - echo "$TLSCERT" > $DOCKER_CERT_PATH/cert.pem
    - echo "$TLSKEY" > $DOCKER_CERT_PATH/key.pem
   
    - docker-compose -f docker-compose-monitoring.yml down
    - rm -rf $DOCKER_CERT_PATH
    
  
  tags:
    - docker        
  
```
 ![gitlab2](https://github.com/rastamalik/project/blob/master/terraform/7.png?raw=true "Optional Title")
 ![gitlab3](https://github.com/rastamalik/project/blob/master/terraform/5.png?raw=true "Optional Title") 
 ![gitlab4](https://github.com/rastamalik/project/blob/master/terraform/6.png?raw=true "Optional Title")
  
  # *  скрины работющих сервисов:
 ![gitlab5](https://github.com/rastamalik/project/blob/master/terraform/8.png?raw=true "Optional Title")
 ![gitlab6](https://github.com/rastamalik/project/blob/master/terraform/9.png?raw=true "Optional Title") 
 ![gitlab7](https://github.com/rastamalik/project/blob/master/terraform/10.png?raw=true "Optional Title")
 ![gitlab8](https://github.com/rastamalik/project/blob/master/terraform/11.png?raw=true "Optional Title")
 


3. Мониторинг и логирование
a) Для мониторинга используем **Prometheus**, а для визуализации **Grafana**, в каталоге **monitoring** создадим каталог **prometheus** c docker файлом и файлом конфигруации:
```
Dockerfile
FROM  prom/prometheus:v2.1.0
ADD  prometheus.yml /etc/prometheus/
ADD  alerts.yml   /etc/prometheus/
```
```
prometheus.yml

---
global:
  scrape_interval: '5s'
rule_files:
  - "alerts.yml"

alerting:
  alertmanagers:
  - scheme: http
    static_configs:
    - targets:
      - "alertmanager:9093"
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets:
        - 'localhost:9090'

  - job_name: 'crawler_ui'
    static_configs:
      - targets:
        - 'crawler_ui:8000'

  - job_name: 'crawler'
    static_configs:
      - targets:
        - 'crawler:8000'
```
b) Для запуска **Prometheus** и **Grafana** создадим отдельный **docker-compose-monitoring.yml**:
```
version: '3.3'
services:
  prometheus:
    image: rastamalik/prometheus
    ports:
      - '9090:9090'
    volumes:
      - prometheus_data:/prometheus
    networks:
      - reddit
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention=1d'

  alertmanager: 
     image: rastamalik/alertmanager 
     command: 
      - '--config.file=/etc/alertmanager/config.yml' 
     ports: 
      - 9093:9093 
     networks:
      - reddit
  grafana:
    image: grafana/grafana:5.0.0
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=secret
    depends_on:
      - prometheus
    networks:
      - reddit  
    ports:
      - 3000:3000


 


volumes:
  prometheus_data:
  grafana_data:
networks:
   reddit:
```
d) Посмотрим поднятые таргеты и снимем метрики для приложения и отправим в **Grafana**:



