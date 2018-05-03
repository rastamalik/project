FROM ubuntu:12.04


ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get install -y python python-pip python-virtualenv gunicorn

# Setup flask application
WORKDIR /app
ADD . /app
RUN pip install -r requirements-test.txt  

RUN coverage run -m unittest discover -s /

RUN coverage report crawler.py
# Start gunicorn
#CMD ["gunicorn", "--config", "/deploy/gunicorn_config.py", "ui:app"]
#CMD ["coverage", "run" ,"-m unittest discover", "-s tests/"]
#CMD ["flask", "run", "--host=0.0.0.0"]

