#! /usr/bin/env bash
##
## watchcoins.bash by lachauj
## improved by lenormf
##

## Example address
## Change it with your own !
MULTIPOOL_USER="1KotnoAdpv8GGmqGcA6TmtM7S5M16HGqio"

## Do not modify anything below this line unless you know what you're doing
MARKET_CACHE=$(mktemp)

# underline
u=$(tput smul)
u_=$(tput rmul)
# red
r=$(tput setaf 1)
# green
g=$(tput setaf 2)
# color reset
nc=$(tput sgr0)

function fatal {
	echo "$@" && exit 1
}

function calc {
	echo "$@" | bc | sed -r "s/^\.([0-9]+)/0\.\1/g"
}

function print_fmt {
	local fmt="$1"

	shift
	if [ -z "$fmt" ]; then
		echo -n "$@"
	elif [ "$fmt" = u ]; then
		echo -ne "$u"
		echo -n "$@"
		echo -ne "$u_"
	else
		eval echo -ne "\$${fmt}"
		echo -n "$@"
		echo -ne "$nc"
	fi
}

function table_row {
	local fmt=( ${1//:/ } )
	local sep="|"

	shift
	local lw=5
	local lf=""
	local n=0
	for i in "$@"; do
		test $n -lt ${#fmt[@]} -a ${#fmt[@]} -gt 0 && lw="${fmt[$n]}"

		# Modify to allow format modifiers
		[[ "${lw:0:1}" =~ [urg] ]] && {
			lf="${lw:0:1}";
			lw="${lw:1}";
		} || {
			test $n -lt ${#fmt[@]} -a ${#fmt[@]} -gt 0 && lf="";
		}

		test "$n" -gt 0 -a "$n" -lt $# && echo -n " $sep "
		if [ "${#i}" -ge "$lw" ]; then
			print_fmt "$lf" "${i:0:$lw}"
		else
			printf "%$((lw - ${#i}))s" " "
			print_fmt "$lf" "$i"
		fi

		n=$((n + 1))
	done

	echo
}

function get_multipool_info {
	local multipool_user="$1"
	local multipool_addr="http://www.middlecoin.com/allusers.html"

	curl -s "$multipool_addr" | grep -m 1 -A 6 "id=\"${multipool_user}" | sed -r "s/[^a]><\//>0.0<\//g" | sed -r "s/(<[^>]+>)|\s//g"
}

function display_user_stats {
	local user="$1"
	local hashrate_accepted_mhs="$2"
	local hashrate_rejected_mhs="$3"
	local immature_unexchanged_balance_btc="$4"
	local unexchanged_balance_btc="$5"
	local balance_btc="$6"
	local balance_sum_btc=$(calc $unexchanged_balance_btc + $balance_btc)
	local paid_out_btc="$7"

	shift 7
	local rate_bitcoin_dollars="${3:1}"

	shift 6
	local rate_stablecoin_dollars="${3:1}"

	local immature_unexchanged_balance_usd=$(calc "$immature_unexchanged_balance_btc * $rate_bitcoin_dollars")
	local unexchanged_balance_usd=$(calc "$unexchanged_balance_btc * $rate_bitcoin_dollars")
	local balance_usd=$(calc "$balance_btc * $rate_bitcoin_dollars")
	local balance_sum_usd=$(calc "$balance_sum_btc * $rate_bitcoin_dollars")
	local paid_out_usd=$(calc "$paid_out_btc * $rate_bitcoin_dollars")

	local immature_unexchanged_balance_sbc=$(calc $immature_unexchanged_balance_usd / $rate_stablecoin_dollars)
	local unexchanged_balance_sbc=$(calc $unexchanged_balance_usd / $rate_stablecoin_dollars)
	local balance_sbc=$(calc $balance_usd / $rate_stablecoin_dollars)
	local balance_sum_sbc=$(calc $balance_sum_usd / $rate_stablecoin_dollars)
	local paid_out_sbc=$(calc $paid_out_usd / $rate_stablecoin_dollars)

	table_fmt=22:34
	table_row "$table_fmt" "User" "$user"
	echo

	table_fmt=22:u15:u15
	table_row "$table_fmt" "" "Accepted" "Rejected"
	table_fmt=22:15:15
	table_row "$table_fmt" "Hashrate" "${hashrate_accepted_mhs} Mh/s" "${hashrate_rejected_mhs} Mh/s"
	echo

	table_fmt=22:u15:u15:u11
	table_row "$table_fmt" "" "Bitcoin" "USD" "StableCoin"
	table_fmt=22:15:15:11
	table_row "$table_fmt" "Immature Unexchanged" "${immature_unexchanged_balance_btc} btc" "\$${immature_unexchanged_balance_usd}" "${immature_unexchanged_balance_sbc} sbc"
	table_row "$table_fmt" "Unexchanged" "${unexchanged_balance_btc} btc" "\$${unexchanged_balance_usd}" "${unexchanged_balance_sbc} sbc"
	table_row "$table_fmt" "Regular" "${balance_btc} btc" "\$${balance_usd}" "${balance_sbc} sbc"
	table_row "$table_fmt" "Unexchanged + Regular" "${balance_sum_btc} btc" "\$${balance_sum_usd}" "${balance_sum_sbc} sbc"
	table_row "$table_fmt" "Paid out" "${paid_out_btc} btc" "\$${paid_out_usd}" "${paid_out_sbc} sbc"
	echo
}

function get_currency_stats {
	local currency="$1"
	local market_addr="http://coinmarketcap.com/"

	if [ ! -s "$MARKET_CACHE" ]; then
		wget -O "$MARKET_CACHE" "$market_addr" -o /dev/null || echo -n
	fi

	grep -m 1 -A 6 ">${currency}" "$MARKET_CACHE" | sed -r "s/(<[^>]+>)|\s//g"
}

function display_currency_stats {
	local name="$1"
	local market_cap_dollars="$2"
	local exchange_rate_dollars="$3"
	local maximum_supply_coins="$4"
	local volume_last_24_percent="$5"
	local change_last_24_percent="$6"

	table_fmt=22:u15:u15:u15:u12
	table_row "$table_fmt" "" "Market Cap" "Exchange Rate" "Maximum Supply" "Volume 24h" "Change 24h"
	test "${change_last_24_percent:0:1}" = - && table_fmt=22:15:15:15:12:r12 || table_fmt=22:15:15:15:12:g12
	table_row "$table_fmt" "${name}" "${market_cap_dollars}" "${exchange_rate_dollars}" "${maximum_supply_coins}" "${volume_last_24_percent}" "${change_last_24_percent}"
}

function main {
	local multipool_info=( $(get_multipool_info "${MULTIPOOL_USER}") )
	local bitcoin_info=( $(get_currency_stats Bitcoin) )
	local stablecoin_info=( $(get_currency_stats StableCoin) )

	test 0 -eq "${#multipool_info[@]}" && fatal "Unable to get info from the multipool"
	test 0 -eq "${#bitcoin_info[@]}" && fatal "Unable to get info from the market (bitcoin)"
	test 0 -eq "${#stablecoin_info[@]}" && fatal "Unable to get info from the market (stablecoin)"

	display_user_stats "${multipool_info[@]}" "${bitcoin_info[@]}" "${stablecoin_info[@]}"
	display_currency_stats "${bitcoin_info[@]}"
	echo

	display_currency_stats "${stablecoin_info[@]}"

	rm -f "$MARKET_CACHE"
}

main "$@"
