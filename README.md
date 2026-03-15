# captive-firefox

A Bash script to launch Firefox with the DNS server provided by your Wi-Fi network, making it easy to access and pass through captive portals. Inspired by [@FiloSottile/captive-browser](https://github.com/FiloSottile/captive-browser), but designed for Firefox and Linux with no extra dependencies.

## Features

- Zero-install: just copy the script
- Auto-detects Wi-Fi DNS
- Uses a private, temporary Firefox profile
- Sandboxed with [firejail](https://firejail.wordpress.com/)
- Disables JIT and WebAssembly by default for a reduced attack surface on untrusted networks

## Usage

```sh
./captive-firefox.sh [OPTIONS]
```

Options:
- `-u, --url URL` URL to open (default: Firefox captive portal check)
- `-i, --iface IFACE` Wi-Fi interface (default: auto)
- `--no-disable-jit` Do not disable JIT and WebAssembly (they are disabled by default for security)
- `-h, --help` Show help

Example:
```sh
./captive-firefox.sh # this will work for most users
./captive-firefox.sh --iface wlan0 --url "http://example.com"
```

## How it works

- Detects your Wi-Fi interface and DNS
- Launches Firefox in a sandbox with a temporary profile and the correct DNS

## Requirements

- Bash, firejail, nmcli, iw, Firefox

## Security

- No data is saved; all traffic uses the Wi-Fi DNS; session is sandboxed
- JIT compilation and WebAssembly are disabled by default to reduce the attack surface on untrusted networks; use `--no-disable-jit` to opt out

## License

MIT
