#!/bin/bash
sudo modprobe loop
mkdir -p scratch

timestamp="Sat Jul 25 07:[45]"
usnj="/home/brett/Uni/Thesis/USN Journal/usnj.pl"

for image in *.img
do
        echo "# $image"
        date
        
        sudo mount -o loop,offset=105906176,ro,streams_interface=windows $image scratch/
        
        sleep 10
        for keyword in stub.jpg payload.exe monitor.exe killSuperfetch 01189998819991197253.log
        do
                echo "## $keyword"
                keywordUnicode="$(echo "$keyword"|sed "s/\(.\)/\1\\\\x00/g;s/\\\\x00$//")"

                # Registry
                echo "### Registry"
                grep -aPio "$keyword" scratch/Windows/System32/config/* | wc -l
                grep -aPio "$keywordUnicode" scratch/Windows/System32/config/* | wc -l
                echo "### User Registry"
                grep -aPio "$keyword" scratch/Users/*/NTUSER.DAT | wc -l
                grep -aPio "$keywordUnicode" scratch/Users/*/NTUSER.DAT | wc -l
        
                # Pagefile
                echo "### Pagefile"
                grep -aPio "$keyword" scratch/pagefile.sys | wc -l
                grep -aPio "$keywordUnicode" scratch/pagefile.sys | wc -l
                
                #RecentFileCache
                echo "### RecentFileCache"
                grep -aPio "$keywordUnicode" scratch/Windows/AppCompat/Programs/RecentFileCache.bcf | wc -l
                
                # Prefetch
                echo "### Prefetch"
                grep -aPio "$keyword" scratch/Windows/Prefetch/* | wc -l
                grep -aPio "$keywordUnicode" scratch/Windows/Prefetch/* | wc -l
                
                # Filenames
                echo "### Filenames"
                find scratch/ | grep -i "$keyword"
                
                # USN Journal
                echo "### USN Journal"
                perl "$usnj" -c -f "scratch/\$Extend/\$UsnJrnl:\$J"  | grep -i "$keyword"
        done
        
        sleep 10
        sudo umount scratch/
        sleep 10
done

