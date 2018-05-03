FROM ubuntu:12.04


ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get install -y python python-pip python-virtualenv gunicorn

# Setup flask application
RUN mkdir -p /deploy/app
COPY gunicorn_config.py /deploy/gunicorn_config.py
COPY app /deploy/app
RUN pip install -r /deploy/app/requirements.txt  

WORKDIR /deploy/app
ENV FLASK_APP=ui.py
ENV MONGO mongo
ENV MONGO_PORT 27017
EXPOSE 8000
# Start gunicorn
CMD ["gunicorn", "--config", "/deploy/gunicorn_config.py", "ui:app"]
#CMD ["coverage", "run" ,"-m unittest discover", "-s tests/"]
#CMD ["flask", "run", "--host=0.0.0.0"]

