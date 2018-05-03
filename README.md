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
 * папка **searh_engune_ui** содержит веб-интерфейс для поиска фраз на приндексированных ботом сайтах **ui.py** и **Dockerfile** для запуска контейнера **crawler_ui**
 
