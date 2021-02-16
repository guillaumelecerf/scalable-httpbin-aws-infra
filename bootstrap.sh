#!/bin/bash
yum update -y
yum install -y gcc gcc-c++ python3 python3-devel git
# Run httpbin as the ec2-user for security
su ec2-user -c \
  'export PATH=${PATH}:/home/ec2-user/.local/bin
  cd /home/ec2-user
  git clone https://github.com/postmanlabs/httpbin.git
  cd httpbin
  sed "s%Response Service.%Response Service.<br/>Running on $(hostname -f)%" -i httpbin/core.py
  pip3 install --user --no-cache-dir pipenv
  pip3 install --user --no-cache-dir -r <(pipenv lock -r)
  pip3 install --user --no-cache-dir .
  gunicorn -b 0.0.0.0:8080 httpbin:app -k gevent'
