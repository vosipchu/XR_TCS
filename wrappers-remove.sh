#!/bin/bash
#######################################################
######## This removes aliases from your server  #######
#######################################################
sed -i 2,192d ~/.bashrc;

echo -e "\e[1;45m All command wrappers from ~/.bashrc were removed! \e[0m";
