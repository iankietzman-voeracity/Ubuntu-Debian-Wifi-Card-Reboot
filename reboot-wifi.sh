#!/bin/bash

# The following two variables may need to be updated according to your machine
# Run 'sudo lshw -C network' to find the appropriate values

# model
networkAdapter=$(lspci | grep "Wireless 7260")

# system interface
logicalName="wlp3s0"

# This only works for Wireless 7260, editing this to work with other PCI cards will likely require
# digging deeper here
# More info: # https://bugzilla.kernel.org/show_bug.cgi?id=191601
intelBuggery="0x50.B=0x40"

    
# Find which pci slot the controller is assigned to
pciSlot=$(echo ${networkAdapter} | awk '{ print $1 }')
devicePath="/sys/bus/pci/devices/0000:$pciSlot/remove"

while true; do

    # If card exists, remove it
    if [ -f $devicePath ]; then
        echo 'remove wireless PCI'
        echo 1 | sudo tee $devicePath > /dev/null
        sleep 1
    fi

    # Probe the drivers in case they were accidentally removed
    echo 'probe drivers'
    sudo modprobe iwlmvm
    sudo modprobe iwlwifi
    
    # Bring network PCI back online
    echo 'rescan PCI'
    echo 1 | sudo tee /sys/bus/pci/rescan > /dev/null
    sleep 1

    # Make sure network card is back online as PCI
    if [ -f $devicePath ]; then
        echo 'IT'\''S ALIVE! ALIIIIIIIIIIIIIIIVE!'
        
        sudo setpci -s $pciSlot $intelBuggery

        sleep 1
        wifiProcessId=$(rfkill list |grep Wireless |awk -F: '{ print $1 }')
        echo "unblock woken up PCI: $wifiProcessId"
        sudo rfkill unblock $wifiProcessId

        sleep 1
        sudo ifconfig $logicalName up

        # Testing if the PCI is back online, exitCode of 0 indicates success
        exitCode=$?
        echo "device is resurrected"
        if [ $exitCode -eq 0 ];then

            # Turn off power management, as that is known to contribute problems
            sudo iwconfig $logicalName power off
            break
        fi
    else
        # Failed state
        echo "Failed. Retrying"
        sudo modprobe -r iwlmvm
        sudo modprobe -r iwlwifi
    fi
done

echo "Success - Wifi should be back online"
