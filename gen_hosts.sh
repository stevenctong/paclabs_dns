#!/bin/bash
# This takes the DNS entries from host_list.csv file and appends into the appropriate zone file
# host_list.csv can define just an A record (hostname+IP address+forward zone)
# Or host_list.csv can define an A plus PTR record (hostname+IP address+foward zone+reverse zone)
# Will check that the zone file already exists before appending

echo "Make sure all your hostnames are RFC compliant"

INPUT=host_list.csv    # host_list.csv is the records we want to put into the zone files
ZONE_FILE_LOC=files/bind/    # relative directory of zone files

# Checks that host_list.csv exists, and if not, exists
if [ -f $INPUT ] ; then
  echo "Host lists file: host_list.csv EXISTS, creating DNS entries from this file"
else
  echo "Host lists file: host_list.csv DOES NOT EXIST, no DNS entries will be created"
  exit 99
fi

# Sets $datetime to current date and hour to use as the SERIAL value in zone files
datetime="$(date '+%Y%m%d%H')"

IFS=,
cur_fwd_zone=0
cur_rev_zone=0

# This loops through $INPUT file line by line
{
  read line  # exclude the header line
  # Captures each comma separated value as a var
  # Gets last record by making sure it loops as long as there is a value to enter
  while read -r hostname ip_addr fwd_zone rev_zone comments || [ -n "$hostname" ] ;
  do

  # Checks if forward zone file for this record is present
  if [ -f "$ZONE_FILE_LOC$fwd_zone.zone" ] ; then
    # If first time updating this zone file, updates the SERIAL value
    if [ $cur_fwd_zone != $fwd_zone ] ; then
      echo "Zone file exists: $ZONE_FILE_LOC$fwd_zone.zone"

      sed -i 's/.*serial.*/                    '$datetime'  ; serial (year)(m)(d)(h)(m)(s)/' $ZONE_FILE_LOC$fwd_zone.zone
    fi

    # Checks that $hostname exists and that it is not already in the zone file
    if !(grep -qw ^$hostname $ZONE_FILE_LOC$fwd_zone.zone) ; then
      len=$((19-${#hostname}))  # 20 = total hostname whitespace
      spaces=$(printf '%*s' "$len" | tr ' ' "#")  # gets proper amount of whitespace as char #

      echo "$hostname$spaces IN     A     $ip_addr" | tr '#' " " >> $ZONE_FILE_LOC$fwd_zone.zone
      echo "Added host($hostname) IP ($ip_addr) FWD Zone ($fwd_zone) $comments"
    fi
  else
    if [ $cur_fwd_zone != $fwd_zone ] ; then
      echo "Zone file does NOT exist (no records added): $ZONE_FILE_LOC$fwd_zone.zone"
    fi
  fi

    cur_fwd_zone=$fwd_zone

    if [ -n "$rev_zone" ] ; then
      if [ -f "$ZONE_FILE_LOC$rev_zone.zone" ] ; then
        if [ $cur_rev_zone != $rev_zone ] ; then
          echo "Zone file exists: $ZONE_FILE_LOC$rev_zone.zone"

          sed -i 's/.*serial.*/                    '$datetime'  ; serial (year)(m)(d)(h)(m)(s)/' $ZONE_FILE_LOC$rev_zone.zone
        fi

        last_octet=$(echo $ip_addr | cut -d'.' -f4)

        if !(grep -qw ^$last_octet $ZONE_FILE_LOC$rev_zone.zone) ; then
          len=$((19-${#last_octet}))  # 20 = total hostname whitespace
          spaces=$(printf '%*s' "$len" | tr ' ' "#")  # gets proper amount of whitespace as char #

          echo "$last_octet$spaces IN     PTR     $hostname.$fwd_zone." | tr '#' " " >> $ZONE_FILE_LOC$rev_zone.zone
          echo "Added host($hostname) IP ($ip_addr) Last Octet ($last_octet) REV Zone ($rev_zone) $comments"
        fi

      else
        if [ $cur_rev_zone != $rev_zone ] ; then
          echo "Zone file does NOT exist (no records added): $ZONE_FILE_LOC$rev_zone.zone"
        fi
      fi

      cur_rev_zone=$rev_zone

    else
       echo "Skipping $hostname PTR record - No reverse zone in $INPUT"
    fi

  done
} < $INPUT  # input file for loop
