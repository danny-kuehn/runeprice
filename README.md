# runeprice

CLI tool for querying the [OSRS Wiki Prices API], written in Bash.

## Dependencies

- `bash`
- `coreutils`
- `curl`
- `jq`

## Installation

### AUR

Use your preferred AUR helper to install `runeprice`.

[![runeprice][badge-url]][aur-url]

Or clone and build:

```
git clone https://aur.archlinux.org/runeprice.git
cd runeprice
makepkg -si
```

### Non-AUR

#### Install

`git clone` the repository and use the installer script inside the cloned
repository:

```
git clone https://github.com/danny-kuehn/runeprice.git
cd runeprice
sudo scripts/installer.sh -i
```

#### Update

```
git pull
sudo scripts/installer.sh -i
```

#### Uninstall

```
sudo scripts/installer.sh -u
```

## Usage

Before making your first request, you need to run:

```
runeprice -u -C
```

The `-u` option will download a [JSON file] provided by the OSRS Wiki that has
all item IDs. When new items are added to the API, you will use this option to
update the local JSON file.

The `-C` option generates a config file with default values. Most people will
probably want to set `RUNEPRICE_ENDPOINT` to "osrs" and `RUNEPRICE_ROUTE` to
"latest".

All settings in the config file can be set with options when running the
script.

See `-h` or `--help` for a full list of options.

## License

All files in this repository are licensed under the GNU Affero General Public
License v3.0 or later - see the [LICENSE] file for details.


<!-- links -->
[OSRS Wiki Prices API]: https://oldschool.runescape.wiki/w/RuneScape:Real-time_Prices
[badge-url]: https://img.shields.io/aur/version/runeprice?label=runeprice&logo=arch-linux&style=plastic
[aur-url]: https://aur.archlinux.org/packages/runeprice
[JSON file]: https://oldschool.runescape.wiki/w/Module:GEIDs/data.json
[LICENSE]: LICENSE
