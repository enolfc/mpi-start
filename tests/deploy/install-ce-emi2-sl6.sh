#!/bin/sh
# installation script for WN on sl5 + emi2 

################
# INSTALLATION #
################

echo "*"
echo "* Installation "
echo "*"

echo "** EMI-CREAM + Torque"
# Install needed tools for CE
yum --nogpg -q -y install emi-cream-ce emi-torque-server emi-torque-utils
if [ $? -ne 0 ] ; then
    echo "******************************************************"
    echo "ERROR installing cream!"
    echo "******************************************************"
    exit 1
fi

## install emi-mpi
echo "** EMI-MPI"
yum --nogpg -y install emi-mpi
if [ $? -ne 0 ] ; then
    echo "******************************************************"
    echo "ERROR installing emi-mpi!"
    echo "******************************************************"
    exit 1
fi

echo "******************************************************"
echo " INSTALLATION SUCCEDED!"
echo "******************************************************"
exit 0