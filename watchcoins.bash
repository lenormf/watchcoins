#!/usr/bin/env bash

test $# -lt 1 && echo "usage: $0 <bitcoin address>" && exit 1

TMP_CMC=/tmp/cmc.html

infos=$(curl -s http://www.middlecoin.com/allusers.html | grep -A 6 "id=\"$1\"" | sed 's/<td>//g' | sed 's/<\/td>//g' | cut -d '>' -f2 | sed -e 's/<.*//' | tr '\n' ',')
hra=$(echo $infos | cut -d ',' -f2)
hrr=$(echo $infos | cut -d ',' -f3)
iub=$(echo $infos | cut -d ',' -f4)
ub=$(echo $infos | cut -d ',' -f5)
b=$(echo $infos | cut -d ',' -f6)
ubb=$(echo "$ub+$b" | bc )
po=$(curl -s http://www.middlecoin.com/reports/$1.html | grep -A 2 total | grep -Eo '[0-9]{0,9}\.[0-9]{0,9}')

cmc=$(wget http://coinmarketcap.com/ -O $TMP_CMC &>/dev/null)
cursbc=$(grep -A 2 StableCoin.png $TMP_CMC | grep -oE "data-usd=\"[0-9]\.[0-9]{0,5}\"" | grep -oE "[0-9]\.[0-9]{0,5}")
persbc=$(grep -A 5 StableCoin.png $TMP_CMC | grep -oE "[+|-][0-9]{1,4}.[0-9]{1,2} %")
curbtc=$(grep -A 2 Bitcoin.png $TMP_CMC | grep bitcoinaverage | grep -oE "data-usd=\"[0-9]{0,5}\.[0-9]{0,5}\"" | grep -oE "[0-9]{1,5}\.[0-9]{0,5}")
perbtc=$(grep -A 5 Bitcoin.png $TMP_CMC | grep -oE "[+|-][0-9]{1,4}.[0-9]{1,2} %")

ubusd=$(echo "$ub*$curbtc" | bc)
busd=$(echo "$b*$curbtc" | bc)
ubbusd=$(echo "$ubusd+$busd" | bc)

ubsbc=$(echo "$ubusd/$cursbc" | bc)
bsbc=$(echo "$busd/$cursbc" | bc)
ubbsbc=$(echo "$ubsbc+$bsbc" | bc)

echo "BTC address: $1"
echo "MH/s (accepted): $hra"
echo "MH/s (rejected): $hrr"
echo "Immature Unexchanged Balance (BTC): $iub"
echo "Unexchanged Balance: $ub BTC | $ubusd\$ | $ubsbc SBC"
echo "Balance: $b BTC | $busd\$ | $bsbc SBC"
echo "Unexchanged + Balance: $ubb BTC | $ubbusd\$ | $ubbsbc SBC"
echo "Paid out (BTC): $po"
echo -e "\nCurrent SBC (USD): $cursbc ($persbc)"
echo "Current BTC (USD): $curbtc ($perbtc)"
