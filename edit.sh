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
for pair in $(ls $watchesdir); do
	args+=($pair "")
done
s=$(whiptail --title "Select currency pair" --menu "Currency pair:" 20 60 10 "${args[@]}" 3>&1 1>&2 2>&3)
if [ -z $s ]; then
	exit 0
fi
if [[ $s == "NEW" ]]; then
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
s=$(whiptail --title "Select watch to change" --menu "Select watch to change" 20 60 10 "${args[@]}" 3>&1 1>&2 2>&3)
if [ -z $s ]; then
        continue
fi
if [[ $s == "NEW" ]]; then
        s=$(whiptail --title "Enter new watch" --inputbox "Enter new watch trigger, example 'gt6350' or 'lt7980'" 8 60 3>&1 1>&2 2>&3)
        s=$(echo $s | tr '[:upper:]' '[:lower:]')
        if [ -e $watchesdir/$currencypair/$s ]; then
                whiptail --msgbox "Watch already exist" 8 60 3>&1 1>&2 2>&3
                continue
        fi
	wn=$s
        r=$(whiptail --title "New rule" --inputbox "Enter watch rule, example '+100' or '-75'" 8 60 3>&1 1>&2 2>&3)
	echo "$r" > $watchesdir/$currencypair/$s
        whiptail --msgbox "Watch created: '$s' with rule '$r'" 8 60 3>&1 1>&2 2>&3
fi
wn=$s
rule=$(cat $watchesdir/$currencypair/$wn)

txt="Enter the rule for this watch."
txt=$txt" It can be left empty for a simple watch."
txt=$txt" Enter DELETE in capital letters to delete this watch"
s=$(whiptail --title "Edit watch" --inputbox "$txt" 9 60 "$rule" 3>&1 1>&2 2>&3)
if [ -z $s ]; then
        continue
fi
if [[ $s == "DELETE" ]]; then
	rm $watchesdir/$currencypair/$wn
	continue;
fi
echo "$s" > $watchesdir/$currencypair/$wn

done
