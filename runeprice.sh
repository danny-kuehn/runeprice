#!/usr/bin/env bash
#
#    runeprice - CLI tool for querying the OSRS Wiki Prices API.
#
#    Copyright (C) 2025 Daniel Kuehn <daniel@kuehn.foo>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

readonly RUNEPRICE_VERSION="0.3.0"
readonly RUNEPRICE_API_URL="https://prices.runescape.wiki/api/v1"
readonly RUNEPRICE_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/runeprice"
readonly RUNEPRICE_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/runeprice"
readonly RUNEPRICE_ITEMS_FILE="$RUNEPRICE_DATA_DIR/items.json"
readonly RUNEPRICE_CONF_FILE="$RUNEPRICE_CONF_DIR/config.ini"
readonly RUNEPRICE_USER_AGENT="runeprice/$RUNEPRICE_VERSION (+https://github.com/danny-kuehn/runeprice)"

RUNEPRICE_ENDPOINT=""
RUNEPRICE_ROUTE=""
RUNEPRICE_ITEM=""
RUNEPRICE_TIMESTAMP=""
RUNEPRICE_TIMESTEP=""
RUNEPRICE_COMPACT_OUTPUT=0
RUNEPRICE_MONOCHROME_OUTPUT=0
RUNEPRICE_TEXT_OUTPUT=0

info() {
	printf "%s\n" "$*" >&2
}

error() {
	printf "ERROR: %s\n" "$*" >&2
}

dependency_check() {
	local -a missing=()
	local cmd

	for cmd in "$@"; do
		command -v "$cmd" &>/dev/null || missing+=("$cmd")
	done

	((${#missing[@]} > 0)) && {
		error "missing dependencies: ${missing[*]}"
		return 1
	}

	return 0
}

validate_endpoint() {
	local -l endpoint="$1"
	local -A valid_endpoints=(
		[osrs]=1 [dmm]=1
	)

	[[ -z "$endpoint" ]] && {
		error "No endpoint provided"
		return 1
	}

	[[ ! -v "valid_endpoints[$endpoint]" ]] && {
		error "Invalid endpoint: $endpoint"
		info "Valid endpoints: ${!valid_endpoints[*]}"
		return 1
	}

	printf "%s" "$endpoint"
}

validate_route() {
	local -l route="$1"
	local -A valid_routes=(
		[latest]=1 [mapping]=1 [5m]=1 [1h]=1 [timeseries]=1
	)

	[[ -z "$route" ]] && {
		error "No route provided"
		return 1
	}

	[[ ! -v "valid_routes[$route]" ]] && {
		error "Invalid route: $route"
		info "Valid routes: ${!valid_routes[*]}"
		return 1
	}

	printf "%s" "$route"
}

validate_item() {
	local -l item="$1"
	local item_id

	[[ -z "$item" ]] && {
		error "No item name provided"
		return 1
	}

	item_id="$(jq -r --arg item "$item" '.[$item]' "$RUNEPRICE_ITEMS_FILE")" || {
		error "Failed to retreive item ID from: $RUNEPRICE_ITEMS_FILE"
		info "Please use the -u option to update the file"
		info "If the issue persists, please report it on GitHub"
		return 1
	}

	[[ "$item_id" == "null" ]] && {
		error "Invalid item name: $item"
		return 1
	}

	printf "%d" "$item_id"
}

validate_timestamp() {
	local timestamp="$1"

	[[ -z "$timestamp" ]] && {
		error "No timestamp provided"
		return 1
	}

	case "$timestamp" in
		*-*)
			timestamp="$(date -d "$timestamp" +%s)" || {
				error "Invalid date format: $timestamp"
				return 1
			}
			;;
		*)
			timestamp="$(date -d "@$timestamp" +%s)" || {
				error "Invalid Unix timestamp: $timestamp"
				return 1
			}
			;;
	esac

	printf "%d" "$timestamp"
}

validate_timestep() {
	local -l timestep="$1"
	local -A valid_timesteps=(
		[5m]=1 [1h]=1 [6h]=1 [24h]=1
	)

	[[ -z "$timestep" ]] && {
		error "No timestep provided"
		return 1
	}

	[[ ! -v "valid_timesteps[$timestep]" ]] && {
		error "Invalid timestep: $timestep"
		info "Valid timesteps: ${!valid_timesteps[*]}"
		return 1
	}

	printf "%s" "$timestep"
}

trim_all() {
	local -a words
	read -ra words <<<"$*"
	printf "%s\n" "${words[*]}"
}

text_handler() {
	local response="$1"

	case "$RUNEPRICE_ROUTE" in
		latest)
			jq -r '
				.data
					| to_entries
					| map(
						"itemId: \(.key)\nhigh: \(.value.high)\nhighTime: \(.value.highTime)\nlow: \(.value.low)\nlowTime: \(.value.lowTime)"
					)
					| join("\n\n")
			' <<<"$response"
			;;
		mapping)
			jq -r '
				map(
					"examine: \(.examine)\nid: \(.id)\nmembers: \(.members)\nlowalch: \(.lowalch)\nlimit: \(.limit)\nvalue: \(.value)\nhighalch: \(.highalch)\nicon: \(.icon)\nname: \(.name)"
				)
				| join("\n\n")
			' <<<"$response"
			;;
		5m | 1h)
			jq -r '
				(.data
					| to_entries
					| map(
						"itemId: \(.key)\navgHighPrice: \(.value.avgHighPrice)\nhighPriceVolume: \(.value.highPriceVolume)\navgLowPrice: \(.value.avgLowPrice)\nlowPriceVolume: \(.value.lowPriceVolume)"
					)
					| join("\n\n")
				)
				+ "\n\ntimestamp: \(.timestamp)"
			' <<<"$response"
			;;
		timeseries)
			jq -r '
				(.data
					| map(
						"timestamp: \(.timestamp)\navgHighPrice: \(.avgHighPrice)\navgLowPrice: \(.avgLowPrice)\nhighPriceVolume: \(.highPriceVolume)\nlowPriceVolume: \(.lowPriceVolume)"
					)
					| join("\n\n")
				)
				+ "\n\nitemId: \(.itemId)"
			' <<<"$response"
			;;
	esac
}

response_handler() {
	local response="$1"
	local jq_args=()
	local error

	error="$(jq -r 'try .error catch ""' <<<"$response")"

	[[ -n "$error" && "$error" != "null" ]] && {
		error "$error"
		return 1
	}

	((RUNEPRICE_TEXT_OUTPUT)) && {
		text_handler "$response"
		return 0
	}

	((RUNEPRICE_COMPACT_OUTPUT)) && jq_args+=("-c")
	((RUNEPRICE_MONOCHROME_OUTPUT)) && jq_args+=("-M")

	jq "${jq_args[@]}" <<<"$response"
}

request_handler() {
	local url="$RUNEPRICE_API_URL/$RUNEPRICE_ENDPOINT/$RUNEPRICE_ROUTE"
	local -a params=()
	local query response

	[[ -n "$RUNEPRICE_ENDPOINT" && -n "$RUNEPRICE_ROUTE" ]] || {
		error "Endpoint or route was not provided. See -h or --help"
		return 1
	}

	case "$RUNEPRICE_ROUTE" in
		latest)
			[[ -n "$RUNEPRICE_ITEM" ]] && params+=("id=$RUNEPRICE_ITEM")
			;;
		5m | 1h)
			[[ -n "$RUNEPRICE_TIMESTAMP" ]] && params+=("timestamp=$RUNEPRICE_TIMESTAMP")
			;;
		timeseries)
			[[ -n "$RUNEPRICE_ITEM" && -n "$RUNEPRICE_TIMESTEP" ]] || {
				error "Item or timestep not provided. See -h or --help"
				return 1
			}

			params+=("id=$RUNEPRICE_ITEM")
			params+=("timestep=$RUNEPRICE_TIMESTEP")
			;;
	esac

	((${#params[@]} > 0)) && {
		query="$(printf "&%s" "${params[@]}")"
		query="${query:1}"
		url+="?$query"
	}

	response="$(curl -sS "$url" -A "$RUNEPRICE_USER_AGENT")"

	response_handler "$response"
}

update_items() {
	mkdir -p "$RUNEPRICE_DATA_DIR"

	curl -sS -o "$RUNEPRICE_ITEMS_FILE.new" \
		'https://oldschool.runescape.wiki/?title=Module:GEIDs/data.json&action=raw&ctype=application%2Fjson' \
		-A "$RUNEPRICE_USER_AGENT"

	jq 'with_entries(.key |= ascii_downcase)' "$RUNEPRICE_ITEMS_FILE.new" >"$RUNEPRICE_ITEMS_FILE.norm" || {
		error "Failed to normalize items file"
		return 1
	}

	mv "$RUNEPRICE_ITEMS_FILE.norm" "$RUNEPRICE_ITEMS_FILE"
	rm -f "$RUNEPRICE_ITEMS_FILE.new"

	info "Created file: $RUNEPRICE_ITEMS_FILE"
}

make_conf_file() {
	[[ -f "$RUNEPRICE_CONF_FILE" ]] && {
		local choice
		read -rp "Overwrite config file with default values? (y/N): " choice

		[[ "${choice,,}" != "y" && "${choice,,}" != "yes" ]] && {
			info "Canceled"
			return 1
		}
	}

	mkdir -p "$RUNEPRICE_CONF_DIR"

	cat >"$RUNEPRICE_CONF_FILE" <<EOF
# osrs, dmm
RUNEPRICE_ENDPOINT=""

# latest, mapping, 5m, 1h, timeseries
RUNEPRICE_ROUTE=""

# item name ingame
RUNEPRICE_ITEM=""

# unix or YYYY-MM-DD HH:MM:SS
RUNEPRICE_TIMESTAMP=""

# 5m, 1h, 6h, 24h
RUNEPRICE_TIMESTEP=""

# 0: off
# 1: on
RUNEPRICE_COMPACT_OUTPUT=0
RUNEPRICE_MONOCHROME_OUTPUT=0
RUNEPRICE_TEXT_OUTPUT=0
EOF

	info "Made config file at: $RUNEPRICE_CONF_FILE"
}

print_version() {
	printf "runeprice %s\n" "$RUNEPRICE_VERSION"
}

usage() {
	cat <<EOF
Usage: runeprice -e ENDPOINT -r ROUTE [options]

API Documentation:
 https://oldschool.runescape.wiki/w/RuneScape:Real-time_Prices

Options:
 -c, --compact-output           print JSON as one line

 -C, --conf-file                generate a config file with default values

 -e, --endpoint <ENDPOINT>      set the endpoint for the request
                                possible values: osrs, dmm

 -h, --help                     display this message and exit

 -i, --item <ITEM_NAME>         set the item for the request
                                possible values: item name ingame

 -M, --monochrome-output        print JSON without color

 -r, --route <ROUTE>            set the route for the request
                                possible values: latest, mapping, 5m, 1h, timeseries

 -t, --timestamp <TIMESTAMP>    set the timestamp for the request
                                possible values: unix or YYYY-MM-DD HH:MM:SS

 -T, --timestep  <TIMESTEP>     set the timestep for the request
                                possible values: 5m, 1h, 6h, 24h

 -u, --update-items             update local JSON file containing item IDs

 -x, --text                     print text instead of JSON
EOF
}

parse_opts() {
	while (($#)); do
		case "$1" in
			-c | --compact-output)
				RUNEPRICE_COMPACT_OUTPUT=1
				shift 1
				;;
			-C | --conf-file)
				make_conf_file
				shift 1
				(($# == 0)) && exit 0
				;;
			-e | --endpoint)
				RUNEPRICE_ENDPOINT="$(validate_endpoint "$(trim_all "${2:-}")")"
				shift 2
				;;
			-h | --help)
				usage
				exit 0
				;;
			-i | --item)
				RUNEPRICE_ITEM="$(validate_item "$(trim_all "${2:-}")")"
				shift 2
				;;
			-M | --monochrome-output)
				RUNEPRICE_MONOCHROME_OUTPUT=1
				shift 1
				;;
			-r | --route)
				RUNEPRICE_ROUTE="$(validate_route "$(trim_all "${2:-}")")"
				shift 2
				;;
			-t | --timestamp)
				RUNEPRICE_TIMESTAMP="$(validate_timestamp "$(trim_all "${2:-}")")"
				shift 2
				;;
			-T | --timestep)
				RUNEPRICE_TIMESTEP="$(validate_timestep "$(trim_all "${2:-}")")"
				shift 2
				;;
			-u | --update-items)
				update_items
				shift 1
				(($# == 0)) && exit 0
				;;
			-V | --version)
				print_version
				exit 0
				;;
			-x | --text)
				RUNEPRICE_TEXT_OUTPUT=1
				shift 1
				;;
			*)
				error "Invalid option: $1"
				return 1
				;;
		esac
	done
}

main() {
	set -euo pipefail

	dependency_check "curl" "jq"

	# shellcheck source=/dev/null
	[[ -f "$RUNEPRICE_CONF_FILE" ]] && source "$RUNEPRICE_CONF_FILE"

	parse_opts "$@"
	request_handler
}

(return 0 2>/dev/null) || main "$@"
