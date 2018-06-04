#!/bin/bash
echo -e "\e[1;46m This is a short script to prep your system for the main one \e[0m";
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
cp ~/IOSXR-Telemetry-Collection-Stack/Pipeline/id_rsa ~/.ssh/id_rsa
