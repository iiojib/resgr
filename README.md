# resgr

Scopes ANSI SGR styles to individual output lines and prevents styles from leaking.

## Install

#### Using installer script

```bash
curl -fsSL https://github.com/iiojib/resgr/releases/latest/download/install.sh | sh
```

#### From source:

```sh
git clone https://github.com/iiojib/resgr.git
cd resgr
zig build install --release=small --prefix /usr/local
```

## Usage

```sh
FORCE_COLOR=1 some-app | resgr
```

Use `FORCE_COLOR` to force color output in apps that disable it when stdout is not a TTY.

## Options

- `-h` or `--help` Show this help message and exit.
- `-v` or `--version` Show the version and exit.
- `-i` Ignore the SIGINT signal.

## Buffering

Some apps may buffer output when they detect piped stdout. Here are a few ways
to disable buffering:

- Python and `sed` support the `-u` flag.
- Other programs may support flags such as `--line-buffered` or `--unbuffered`.
- For Python, set `PYTHONUNBUFFERED=1`.
- Apps that rely on C stdio may support `stdbuf`.
- Use `unbuffer` from the `expect` package to run the application in a PTY.
