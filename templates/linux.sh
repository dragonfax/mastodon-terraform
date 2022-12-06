#! /bin/bash

DATA_DIR=/opt/data
DATA_DEVICE=/dev/sdf

# install dependencies
sudo yum update -y
sudo yum install -y docker postgresql vim

# elasic search requires this.
sysctl -w vm.max_map_count=262144

## persistent data volume

# wait for the volume to be available
i=0
while ! [ -e $DATA_DEVICE ]
do
  i=$((i+1))
  if [ i -gt 60 ]
  then
    echo "persistence device never became available"
    exit 1
  fi

  sleep 1
done

# create the filesystem
if ! ( file -s `readlink -f $DATA_DEVICE` | grep 'SGI XFS filesystem' )
then
  echo "formating new ebs volume"
  mkfs -t xfs $DATA_DEVICE
fi

# create the target mount point
if ! [ -e $DATA_DIR ]
then
  mkdir $DATA_DIR
fi

# mount the file system
if ! grep $DATA_DEVICE /etc/fstab
then
  echo "$DATA_DEVICE /opt/data xfs defaults,nofail 0 2" >> /etc/fstab
fi
mount -a

# create the database directories
if ! [ -e $DATA_DIR/redis ]
then
  mkdir $DATA_DIR/redis
fi

if ! [ -e $DATA_DIR/postgres ]
then
  mkdir $DATA_DIR/postgres
fi

if ! [ -e $DATA_DIR/elasticsearch ]
then
  mkdir $DATA_DIR/elasticsearch
  # user id 1000, same as elasticsearch user in the es docker container.
  chown ec2-user:ec2-user $DATA_DIR/elasticsearch
fi


# docker compose
if ! [ -e /usr/local/bin/docker-compose ]
then
  sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi
export PATH="$PATH:/usr/local/bin"

sudo service docker start
sudo usermod -a -G docker ec2-user

# wait for docker service to be ready
i=0
while ! docker ps
do

  # wait for up to a minute
  i=$((i+1))
  if [ $i -gt 60 ]
  then
    echo "docker never came up"
    exit 1
  fi

  sleep 1
done

# generate ssl certs
SSL_CERT_FILE=$DATA_DIR/letsencrypt/live/${domain}/fullchain.pem
if ! [ -e $SSL_CERT_FILE ]
then
  docker run -p 80:80 -p 443:443 \
    -v "$DATA_DIR/letsencrypt:/etc/letsencrypt" \
    -v "/var/lib/letsencrypt:/var/lib/letsencrypt" \
    certbot/certbot:arm64v8-latest certonly --standalone -n \
      -d ${domain} \
      -m ${owner_email} \
      --agree-tos
fi

echo "starting mastodon service"

cd /opt
docker-compose up -d db
docker-compose up -d es

# wait for posgres
i=0
while ! PGPASSWORD=mastodon psql -h 127.0.0.1 mastodon_prod mastodon --command='select 1;'
do
  i=$((i+1))
  if [ $i -gt 60 ]
  then
    echo "postgres never came up"
    exit 1
  fi

  sleep 1
done

docker-compose run web bundle exec rake db:migrate


# create the elasticsearch indexes (its like db:migrate for ES)
# this reloads the whole ES db, so we try to skip it we can.
ES_CREATED_FILE=$DATA_DIR/elasticsearch/.indexes_created
if ! [ -e $ES_CREATED_FILE ]
then

  # wait for elastic search
  i=0
  while ! docker-compose ps es | grep healthy
  do
    i=$((i+1))
    if [ $i -gt 60 ]
    then
      echo "elasticsearch never came up"
      exit 1
    fi
    sleep 1
  done

  echo "rebuilding the ES indexes"
  docker-compose run web tootctl search deploy

  touch $ES_CREATED_FILE

fi

docker-compose run web bundle exec rake assets:precompile

docker-compose up -d nginx
