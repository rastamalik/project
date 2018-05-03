FROM  python:3.6.0-alpine 

RUN mkdir -p /deploy/app
COPY app /deploy/app
RUN pip install -r /deploy/app/requirements.txt
WORKDIR /deploy/app
ENV CRAWLER_APP=crawler.py
ENV MONGO mongo
ENV MONGO_PORT 27017
ENV RMQ_HOST rabbit
 
CMD  ["python", "-u", "crawler.py","https://vitkhab.github.io/search_engine_test_site/"]
