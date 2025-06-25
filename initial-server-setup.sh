#!/bin/bash

if [ $# -ne 2 ]; then
  printf "$0 takes two parameters: <domain-name> <db-password>"
  exit 1
fi

# set password below for DB access
domain_name="$1"
db_password="$2"

# check is root
if [ "$EUID" -ne 0 ]; then
  echo "run: sudo $0"
  exit 1
fi

# update server
apt update && apt upgrade -y

# secure the ssh part of the server
if [ ! -f ./secure-ssh.sh ]; then
  printf "secure-ssh.sh script missing\n"
  exit 1
fi
bash ./secure-ssh.sh
if [ $? -ne 0 ]; then
  printf "secure-ssh.sh failed\n"
  exit 1
fi

# clear up login
chmod a-x /etc/update-motd.d/*
chmod a+x /etc/update-motd.d/98*
chmod a+x /etc/update-motd.d/90*

# 
apt install nano docker.io postgresql postgresql-contrib build-essential git net-tools nginx python3-pip libpq-dev python3-dev libsystemd-dev -yyq

# log out and back in after this command!
usermod -aG docker simsage

pip3 install pandas psycopg2-binary psycopg2 pyarrow fastparquet --break-system-packages
if [ $? -ne 0 ]; then
  printf "pip3 install failed\n"
  exit 1
fi

#################################################################################################
# set up postgres using the postgres user

# check we have version 15 of postgres and can find the config files we need to change
if [ ! -f "/etc/postgresql/15/main/pg_hba.conf" ]; then
  printf "wrong postgres version, please adjust script first\n"
  exit 1
fi

# create a parquet DB for our parquet copy script
sudo -u postgres createdb parquet_store
if [ $? -ne 0 ]; then
  printf "cannot create DB parquet_store\n"
  exit 1
fi

# create the superset DB
sudo -u postgres createdb superset_metadata
if [ $? -ne 0 ]; then
  printf "cannot create DB superset_metadata\n"
  exit 1
fi

# create a simsage user in the db
sudo -u postgres createuser simsage
if [ $? -ne 0 ]; then
  printf "cannot create simsage user in DB\n"
  exit 1
fi

sudo -u postgres psql -c "alter user simsage with encrypted password '"$db_password"';"
sudo -u postgres psql -c "grant all privileges on database parquet_store to simsage;"
sudo -u postgres psql -c "grant all privileges on database superset_metadata to simsage;"

# set up postgres to enable comms with the local docker instance

# make sure the docker bridge is 172.17.0.0/16
if [ "$(docker network inspect bridge | grep "172.17.0.0/16" | tr -d ' ')" == "" ]; then
  printf "docker network incorrect for set up\n"
  exit 1
fi

# set localhost ipv4 and ipv6 to accept md5 password auth
# and add docker bridge to allowed network access using md5
sed -i 's|127.0.0.1.*scram-sha-256|127.0.0.1/32   md5\nhost  all  all  172.17.0.0/16  md5\n|g' /etc/postgresql/15/main/pg_hba.conf
sed -i 's|::1/128.*scram-sha-256|::1/128   md5|g' /etc/postgresql/15/main/pg_hba.conf

# set the listen address to allow anyone
sed -i "s/#listen_addresses.*/listen_addresses = '*'/g" /etc/postgresql/15/main/postgresql.conf

# restart the postgres server
systemctl restart postgresql
if [ $? -ne 0 ]; then
  printf "postgres server set up failed, restart failed after config changes\n"
  exit 1
fi

#################################################################################################
# set up valkey

if [ ! -f ./valkey/valkey-server ]; then
  printf "valkey/valkey-server missing\n"
  exit 1
fi

groupadd valkey
useradd -r -g valkey -s /bin/false valkey
mkdir /etc/valkey
mkdir /var/lib/valkey
mkdir /var/run/valkey

chown valkey:valkey /var/lib/valkey
chmod 750 /var/lib/valkey
chown valkey:valkey /var/run/valkey

cp ./valkey/valkey-server /usr/local/bin/
cp ./valkey/valkey-cli /usr/local/bin/
cp ./valkey/valkey.conf /etc/valkey/
cp ./valkey/valkey.service /etc/systemd/system/

# set local ip address for listening
sed -i "s/<localip>/$(hostname -i)/g" /etc/valkey/valkey.conf

systemctl daemon-reload
systemctl start valkey.service
if [ $? -ne 0 ]; then
  printf "valkey service failed to start\n"
  exit 1
fi

systemctl enable valkey.service

#################################################################################################
# superset in docker

docker run -d \
    --name superset \
    -p 8088:8088 \
    -e SUPERSET_SECRET_KEY="0EYM+/Q2Nx5ZgesJxBZpPW9BQAHgWKD25OJT4eLg2w8bhqowA6fdpyLp" \
    -e DB_CONNECTION_STRING="postgresql+psycopg2://simsage:$db_password@host.docker.internal:5432/superset_metadata" \
    -e SUPERSET_CACHE_REDIS_URL="redis://host.docker.internal:6379/0" \
    -e SUPERSET_RATELIMIT_STORAGE_REDIS_URL="redis://host.docker.internal:6379/1" \
    simsage/superset:5.0.0

# wait for superset to start properly
printf "\nwaiting 10 seconds for superset to start properly\n"
sleep 10

# set up the initial superset db
docker exec -it superset superset db upgrade
# initialize superset
docker exec -it superset superset init

#################################################################################################
# set up nginx

# copy new nginx config for local cert and restart nginx
cp ./nginx/default /etc/nginx/sites-available/default
sed -i "s#<domainname>#$domain_name#g" /etc/nginx/sites-available/default
printf "\n\nSUPERSET SERVER DOMAIN NAME: $domain_name\n\n"

mkdir /opt/cert/
if [ ! -f /opt/cert/cert-chain.txt ]; then
  touch /opt/cert/cert-chain.txt
  touch /opt/cert/key.txt
fi

systemctl restart nginx

#################################################################################################
# perform parquet copy for example

sed -i "s#<password>#$db_password#g" ./parquet/upload_parquet_to_postgres.py
cd ./parquet
python3 upload_parquet_to_postgres.py
cd ..

#################################################################################################
# remind the user to set up their admin user for accessing superset
printf "\nEnsure to put the cert-bundle and keys into the appropriate files in /opt/cert/\n"
printf "\nyou must run\n\ndocker exec -it superset superset fab create-admin\n\nto create your initial admin user"
