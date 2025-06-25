#!/bin/bash

# check is root
if [ "$EUID" -ne 0 ]; then
  echo "run: sudo $0"
  exit 1
fi

# check we are simsage - as the secure-ssh script will only allow simsage to sign-in to the server as a security measure
if [ "$(logname)" != "simsage" ]; then
  printf "not simsage user, only simsage user should use $0"
  exit 1
fi

# make ssh more secure by modifying sshd

sed -i '/^#PasswordAuthentication/d' /etc/ssh/sshd_config
sed -i '/^PasswordAuthentication/d' /etc/ssh/sshd_config
sed -i '/^#PermitEmptyPasswords/d' /etc/ssh/sshd_config
sed -i '/^PermitEmptyPasswords/d' /etc/ssh/sshd_config
sed -i '/^#PermitRootLogin/d' /etc/ssh/sshd_config
sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config
sed -i '/^X11Forwarding/d' /etc/ssh/sshd_config
sed -i '/^#X11Forwarding/d' /etc/ssh/sshd_config
sed -i '/^#Protocol/d' /etc/ssh/sshd_config
sed -i '/^Protocol/d' /etc/ssh/sshd_config
sed -i '/^#ClientAliveInterval/d' /etc/ssh/sshd_config
sed -i '/^ClientAliveInterval/d' /etc/ssh/sshd_config
sed -i '/^#AllowUsers/d' /etc/ssh/sshd_config
sed -i '/^AllowUsers/d' /etc/ssh/sshd_config
sed -i '/^#MaxAuthTries/d' /etc/ssh/sshd_config
sed -i '/^MaxAuthTries/d' /etc/ssh/sshd_config
sed -i '/^#PubkeyAuthentication/d' /etc/ssh/sshd_config
sed -i '/^PubkeyAuthentication/d' /etc/ssh/sshd_config

echo "X11Forwarding no" >> /etc/ssh/sshd_config
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "Protocol 2" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config

echo "AllowUsers simsage" >> /etc/ssh/sshd_config
echo "MaxAuthTries 3" >> /etc/ssh/sshd_config

systemctl reload sshd

# disarm strict host checking and unknown hosts messages
cat > /home/simsage/.ssh/config <<EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

EOF

exit 0
