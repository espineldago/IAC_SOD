#!/bin/bash
sudo apt update
sudo apt install -y git
sudo git clone https://github.com/espineldago/TF_SOD.git
cd TF_SOD
sudo apt install -y docker.io
sudo docker build -t sod .
sudo docker run -d -p 80:80 sod