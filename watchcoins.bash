#! /usr/bin/env bash
##
## watchcoins.bash by lachauj
## improved by lenormf
##

MULTIPOOL_USER=""
MARKET_CACHE=$(mktemp)

function fatal {
	echo "$@" && exit 1
}

function calc {
	echo "$@" | bc
}

function table_row {
	local fmt=( ${1//:/ } )
	local sep="|"

	shift
	local lw=5
	local n=0
	for i in "$@"; do
		test $n -lt ${#fmt[@]} -a ${#fmt[@]} -gt 0 && lw="${fmt[$n]}"

		test "$n" -gt 0 -a "$n" -lt $# && echo -n " $sep "
		if [ "${#i}" -ge "$lw" ]; then
			echo -ne "${i:0:$lw}"
		else
			printf "%$((lw - ${#i}))s" " "
			echo -ne "$i"
		fi

		n=$((n + 1))
	done

	echo
}

function get_multipool_info {
	local multipool_addr="http://www.middlecoin.com/allusers.html"

	curl -s "$multipool_addr" | grep -A 6 "id=\"${MULTIPOOL_USER}" | sed -r "s/><\/td>/>0.0<\/td>/g" | sed -r "s/(<[^>]+>)|\s//g"
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

	local immature_unexchanged_balance_sbc=$(calc "$immature_unexchanged_balance_usd / $rate_stablecoin_dollars")
	local unexchanged_balance_sbc=$(calc $unexchanged_balance_usd / $rate_stablecoin_dollars)
	local balance_sbc=$(calc $balance_usd / $rate_stablecoin_dollars)
	local balance_sum_sbc=$(calc $balance_sum_usd / $rate_stablecoin_dollars)
	local paid_out_sbc=$(calc $paid_out_usd / $rate_stablecoin_dollars)

	table_fmt=22:34
	table_row "$table_fmt" "User" "$user"
	echo

	table_fmt=22:15:15:11
	table_row "$table_fmt" "" "Accepted" "Rejected"
	table_row "$table_fmt" "Hashrate" "${hashrate_accepted_mhs} Mh/s" "${hashrate_rejected_mhs} Mh/s"
	echo

	table_row "$table_fmt" "Balance type/Currency" "Bitcoin" "USD" "StableCoin"
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

	table_fmt=22:15:15:15:12
	table_row "$table_fmt" "Currency Name" "Market Cap" "Exchange Rate" "Maximum Supply" "Volume 24h" "Change 24h"
	table_row "$table_fmt" "${name}" "${market_cap_dollars}" "${exchange_rate_dollars}" "${maximum_supply_coins}" "${volume_last_24_percent}" "${change_last_24_percent}"
}

function main {
	local multipool_info=( $(get_multipool_info) )
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
