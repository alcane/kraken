#!/bin/bash
###########################################
# Edit watches for kraken.sh
#
# require utils:
#   - whiptail
###########################################

watchesdir="watches"
debug=0

while true; do

args=("NEW" "Create a new pair")
args+=("DEL" "Delete a pair and watches")
pairs=()
for pair in $(ls $watchesdir); do
	pairs+=($pair "")
done
s=$(whiptail --title "Select currency pair" --menu "Select a currency pair" 20 60 10 "${args[@]}" "${pairs[@]}" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
	exit
fi
if [ -z "$s" ]; then
	exit 0
fi
if [[ $s == "DEL" ]]; then
	s=$(whiptail --title "Delete currency pair" --menu "Delete a currency pair" 20 60 10 "${pairs[@]}" 3>&1 1>&2 2>&3)
	rm -rf $watchesdir/$s
	continue;
elif [[ $s == "NEW" ]]; then
	s=$(whiptail --title "Enter currency pair" --inputbox "Pair:" 8 60 3>&1 1>&2 2>&3)
	s=$(echo $s | tr '[:lower:]' '[:upper:]')
	if [ -d $watchesdir/$s ]; then
		whiptail --msgbox "Pair already exist" 8 60 3>&1 1>&2 2>&3
		continue
	fi
	mkdir $watchesdir/$s
        whiptail --msgbox "Pair created: $s" 8 60 3>&1 1>&2 2>&3
fi
currencypair=$s

args=("NEW" "Create a new watch")
for watch in $(ls $watchesdir/$s); do
        args+=($watch "")
done
txt="Currency pair: $currencypair\n"
txt=$txt"Select watch to change"
s=$(whiptail --title "Select watch to change" --menu "$txt" 20 60 10 "${args[@]}" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
	exit
fi
if [ -z "$s" ]; then
        exit
fi
if [[ $s == "NEW" ]]; then
	txt="Currency pair: $currencypair\n"
	txt=$txt"Enter new watch trigger, example 'gt6350' or 'lt7980'"
        s=$(whiptail --title "Enter new watch" --inputbox "$txt" 8 60 3>&1 1>&2 2>&3)
        s=$(echo $s | tr '[:upper:]' '[:lower:]')
        if [ -e $watchesdir/$currencypair/$s ]; then
                whiptail --msgbox "Watch already exist" 8 60 3>&1 1>&2 2>&3
                continue
        fi
	touch $watchesdir/$currencypair/$s
        whiptail --msgbox "Watch created: '$s'" 8 60 3>&1 1>&2 2>&3
fi
wn=$s
rule=$(cat $watchesdir/$currencypair/$wn | sed 's/\s//g')

txt="Currency pair: $currencypair\nWatch: $wn\n"
txt=$txt"Enter the rule for this watch.\n"
txt=$txt"It can be left empty for a simple watch.\n"
txt=$txt"Enter DELETE in capital letters to delete this watch."
s=$(whiptail --title "Edit watch" --inputbox "$txt" 11 60 " $rule" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
	exit
fi
if [[ $s == "DELETE" ]]; then
	rm $watchesdir/$currencypair/$wn
	continue;
fi
echo "$s" | sed 's/\s//g' > $watchesdir/$currencypair/$wn

done
