#!/bin/bash
###########################################
# Monitors a currency pair on kraken
#   and send sms if currency value cross one of the watch.
# Takes values to watch from files in "watches" folder
#   example: touch watches/BTCEUR/lt5500
#     will watch if value fall below 5500 and then delete the watch
#   example: touch watches/BTCEUR/gt5500
#     will watch if value go above 5500 and then delete the watch
#   example: echo "+100" > watches/BTCEUR/gt5500
#     will watch if value go above 5500 and then set a watch to gt5600
#     same logic applie to "-150", etc...
#
# ${smsfrom} should be updated for your country
#
# require utils:
#   - jq
#   - bc
#   - curl
#   - xxd
#   - openssl
#   - base64
###########################################

#adapt to match country phone numbers
smsfrom="33612345678"

debug=0
currencypair=""
phone=""
delay=60
plivo_account=""
plivo_secret=""
watchesdir="watches"
mode="currencypair"
key=""
secret=""

while getopts "c:dhw:m:s:k:p:a:i:" optname
  do
    case "$optname" in
      "p")
	phone=$OPTARG
	;;
      "m")
        mode=$OPTARG
	;;
      "c")
        currencypair=$OPTARG
        watchesdir="${watchesdir}/${currencypair}"
        ;;
      "d")
        debug=1
        ;;
      "w")
        delay=$OPTARG
        ;;
      "s")
	secret=$(cat $OPTARG)
	;;
      "k")
	key=$(cat $OPTARG)
	;;
      "a")
	plivo_account=$(cat $OPTARG)
	;;
      "i")
	plivo_secret=$(cat $OPTARG)
	;;
      "h")
        help
        exit
        ;;
      *)
      # Should not occur
        echo "Unknown error while processing options"
        ;;
    esac
  done

function help {
        echo "kraken.sh [-m mode] [-c BTCEUR] [-w delay] [-d]"
        echo "          [-k file] [-s file]"
        echo "          [-a file] [-i file]"
        echo ""
        echo "Watches taken from folder './watches_[currencypair]'"
        echo ""
        echo "  -m      execution mode, default: currencypair"
        echo "          modes are: currencypair, closedorders"
        echo "  -c      currency pair, example: BTCEUR"
        echo "  -w      wait delay in seconds, default 60sec"
        echo "  -d      debug mode"
        echo "          delay changed to 10sec"
        echo "          do not send SMS"
	echo ""
	echo "	-k	Kraken API key file"
	echo "	-s	Kraken API secret file"
	echo ""
        echo "  -p      phone number"
	echo "	-a	Plivo account ID file"
	echo "	-i	Plivo API secret file"
	echo ""
	echo "Examples:"
	echo "	kraken.sh -c BTCEUR -w 60"
	echo "	kraken.sh -m closedorders -w 300 -k key.txt -s secret.txt"
        exit 1
}

function sign {
	method=$1
	args=$2

	echo -n "/0/private/${method}" > /dev/shm/kraken.tmp
	echo -n "${nonce}nonce=${nonce}${args}" | openssl sha256 -binary >> /dev/shm/kraken.tmp
	sign=$(cat /dev/shm/kraken.tmp | openssl sha512 -binary  -mac HMAC -macopt  hexkey:$(echo -n $secret | base64 -d | xxd -p -c 512) | base64 -w 0)
	echo $sign
}
function timestamp {
	echo $(date +"%s")
}
function nonce {
	echo $(timestamp)
}
function private {
	method=$1
	args=$2

	nonce=$(nonce)
	sign=$(sign "ClosedOrders" "&$args")

	echo -n "nonce=${nonce}" > /dev/shm/data.post
	if [[ ! -z $args ]]; then
		echo -n "&${args}" >> /dev/shm/data.post
	fi
	orders=$(curl -s -v -X POST \
		-H "Accept: application/json" \
		-H "API-Key: $key" \
		-H "API-Sign: $sign" \
		-d @/dev/shm/data.post \
		https://api.kraken.com/0/private/$method
		)
	echo $orders
}

if [[ $debug == 1 ]]; then
        delay=10
fi

if [[ $mode == "currencypair" ]]; then

	if [[ -z $currencypair ]]; then
        	help
	fi

	#ensure watches folder exists
	mkdir -p $watchesdir 2>/dev/null

	#init values with latest data
	while : ; do
       		values=$(curl -s "https://api.kraken.com/0/public/OHLC?pair=${currencypair}&interval=1")
	        [[ $? == 0 ]] && [[ ! -z $values ]] && break;
	        echo "Error, retry..."
        	sleep 5
	done
	pair=$(echo $values | jq '.result|keys|.[0]')
	previous=$(echo $values | jq ".result.$pair|.[-1]|.[4]" | tr -d '"' | tr '.' '.')

	#main loop
	while true; do

	        watches=$(ls $watchesdir | tr '\n' ' ')
	        echo "watches: $watches"

	        #get latest data from kraken
	        values=""
	        while : ; do
	                values=$(curl -s "https://api.kraken.com/0/public/OHLC?pair=${currencypair}&interval=1")
        	        [[ $? == 0 ]] && [[ ! -z $values ]] && break;
	                echo "Error, retry..."
        	        sleep 5
	        done
	        pair=$(echo $values | jq '.result|keys|.[0]')
       		last=$(echo $values | jq ".result.$pair|.[-1]|.[4]" | tr -d '"' | tr '.' '.')
	        if [[ -z $last ]]; then
        	        echo "Error, retry..."
	                continue;
	        fi

        	echo -e "${currencypair}:\tprev:${previous}\tlast:${last}"
	        txt=""

        	#loop over watches
	        for watch in $watches; do
	                crossed=0

        	        #parse watch file name
                	value=${watch:2}
	                comparison=${watch:0:2}

        	        #interpret the parsed values
                	plew=$(echo $previous'<='$value|bc -l)
	                lgtw=$(echo $last'>'$value|bc -l)
        	        pgew=$(echo $previous'>='$value|bc -l)
                	lltw=$(echo $last'<'$value|bc -l)
	                #echo "$plew $lgtw $pgew $lltw"

	                #determine if we cross something
        	        if [[ $comparison == "gt" ]] && [[ $plew == 1 ]] && [[ $lgtw == 1 ]]; then
                	        txt="Crossing > $value !"
                        	crossed=1
	                fi
	                if [[ $comparison == "lt" ]] && [[ $pgew == 1 ]] && [[ $lltw == 1 ]]; then
        	                txt="Crossing < $value !"
                	        crossed=1
	                fi

        	        #do we crossed a value ?
                	if [[ $crossed == 1 ]]; then
                        	txt="$txt\nRemove watch ${comparison}${value}"
	                        action=$(cat $watchesdir/$watch)
        	                rm $watchesdir/$watch

                	        #if we define and action like "+100"
                        	if [[ ! -z $action ]]; then
	                                #parse it
        	                        op=${action:0:1}
                	                diff=${action:1}
                        	        #compute new watch
                                	newvalue=$(echo "${value}${op}${diff}"|bc -l)
	                                #create watch file
        	                        txt="$txt\nSet new watch '${comparison}${newvalue}' with action '$action'"
                	                echo $action > $watchesdir/${comparison}${newvalue}
                        	fi
	                fi
	        done
        	previous=$last

	        #send sms if crossing a value
        	if [[ $txt != "" ]]; then
			txt="${currencypair}: ${txt}"
	                echo -e $txt
        	        if [[ $debug == 0 ]]; then
                	        curl -i --user $plivo_account:$plivo_secret \
                        	-H "Content-Type: application/json" \
	                        -d "{\"src\": \"${smsfrom}\",\"dst\": \"${phone}\", \"text\": \"${txt}\"}" \
        	                https://api.plivo.com/v1/Account/$plivo_account/Message/
                	fi
	        fi

	        echo "Wait $delay seconds..."
	        sleep $delay
	done;

elif [[ $mode == "closedorders" ]]; then

	echo "Checking closed orders"

	start=$(timestamp)
	start=$((start-(3600*24)))
	orders=$(private "ClosedOrders" "start=${start}")

#{
#  "XXXXX-XXXXXX-XXXXXXX": {
#    "refid": null,
#    "userref": 0,
#    "status": "closed",
#    "reason": null,
#    "opentm": 1518725446.8556,
#    "closetm": 1518735451.1516,
#    "starttm": 0,
#    "expiretm": 0,
#    "descr": {
#      "pair": "LTCXBT",
#      "type": "buy",
#      "ordertype": "limit",
#      "price": "0.020011",
#      "price2": "0",
#      "leverage": "none",
#      "order": "buy 2.00000000 LTCXBT @ limit 0.020011",
#      "close": ""
#    },
#    "vol": "2.00000000",
#    "vol_exec": "2.00000000",
#    "cost": "0.043022",
#    "fee": "0.000053",
#    "price": "0.020011",
#    "stopprice": "0.00000000",
#    "limitprice": "0.00000000",
#    "misc": "",
#    "oflags": "fciq"
#  }
#}
	echo $orders | jq '.result.closed as $v | .result.closed | reduce keys[] as $k (
                               {}; if $v[$k].status == "closed" then .[$k] = $v[$k] else . end
                            )'
else

	echo "Unknown mode"
	help

fi
