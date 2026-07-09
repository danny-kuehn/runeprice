# runeprice

> [!WARNING]
> This is the legacy Bash implementation of `runeprice`.
>
> Active development has moved to [osrs-prices on Codeberg].
>
> The final Bash implementation is tagged as `last-bash`.

CLI tool for querying the [OSRS Wiki Prices API], written in Bash.

## Dependencies

- `bash`
- `coreutils`
- `curl`
- `jq`

## Installation

### AUR

The AUR package installs the legacy Bash version of `runeprice`.

Use your preferred AUR helper to install `runeprice`.

[![runeprice][badge-url]][aur-url]

Or clone and build:

```sh
git clone https://aur.archlinux.org/runeprice.git
cd runeprice
makepkg -si
```

### Manual installation

#### Install

Clone the repository and run the installer script:

```sh
git clone https://github.com/danny-kuehn/runeprice.git
cd runeprice
sudo scripts/installer.sh -i
```

#### Uninstall

```sh
sudo scripts/installer.sh -u
```

## Usage

Before making your first request, run:

```sh
runeprice -u -C
```

The `-u` option downloads a [JSON file] provided by the OSRS Wiki that contains
item IDs. Run it again when new items are added to the API.

The `-C` option generates a config file with default values. Most users will
probably want to set `RUNEPRICE_ENDPOINT` to `osrs` and `RUNEPRICE_ROUTE` to
`latest`.

All config settings can also be set with command-line options.

See `-h` or `--help` for a full list of options.

## License

All files in this repository are licensed under the GNU Affero General Public
License v3.0 or later. See the [LICENSE] file for details.

<!-- links -->

[osrs-prices on Codeberg]: https://codeberg.org/daniel-kuehn/osrs-prices
[OSRS Wiki Prices API]: https://oldschool.runescape.wiki/w/RuneScape:Real-time_Prices
[badge-url]: https://img.shields.io/aur/version/runeprice?label=runeprice&logo=arch-linux&style=plastic
[aur-url]: https://aur.archlinux.org/packages/runeprice
[JSON file]: https://oldschool.runescape.wiki/w/Module:GEIDs/data.json
[LICENSE]: LICENSE.txt
