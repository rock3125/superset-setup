# superset-setup
Helper for setting up superset on a Ubuntu server 22.04

## run
sign-in as `simsage` user, and run 
```
# run <full-domain-name> <db-password>
sudo ./initial-server-setup.sh superset.simsage.ai fiefai7TaiTeeng6Ohx5

# restart the server, it'll need to update a few things

# populate your two cert files in /opt/cert/
sudo nano /opt/cert/cert-chain.txt
sudo nano /opt/cert/key.txt
sudo systemctl restart nginx

# then create your initial admin user, make sure to sign-out to
# get the docker group associated properly with the simsage user
docker exec -it superset superset fab create-admin
```
