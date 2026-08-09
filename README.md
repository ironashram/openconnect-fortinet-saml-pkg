# openconnect-fortinet-saml-pkg

Packaging artifacts and build tooling for
[openconnect-fortinet-saml](https://github.com/ironashram/openconnect-fortinet-saml).

The source code lives in the linked repo; this one only carries
distro packaging.

## What's in the fork

- Tom Kolosionek's Fortinet SAML/SSO MR !632 from upstream openconnect
- Restored `gnutls_pkcs11_init()` workaround (gnutls#1798) that the MR
  removed for unrelated reasons
- Local per-host overrides framework
  (`/etc/openconnect/local-overrides.conf`)

## Arch Linux

The PKGBUILD moved to
[ironashram/arch-pkgbuilds](https://github.com/ironashram/arch-pkgbuilds),
directory `openconnect-fortinet-saml/`.

Provides `openconnect` and conflicts with the stock package, so it
replaces it cleanly. `networkmanager-openconnect` /
`networkmanager-vpn-plugin-openconnect` keep working via the provides.

## Ubuntu / Debian

Runs `dpkg-buildpackage` inside a container of the target distro.
Needs docker or podman; nothing else on the host.

```
packaging/build-deb.sh ubuntu:26.04           # current LTS
packaging/build-deb.sh ubuntu:24.04           # previous LTS
packaging/build-deb.sh debian:bookworm        # Debian stable
```

Any apt-based image works; the script forwards the tag verbatim to
the container engine. Output `.deb` files land in `dist/<tag>/`.
Install with:

```
sudo dpkg -i dist/ubuntu-26.04/openconnect-fortinet-saml_*.deb
sudo apt-get -f install
```

## Per-host overrides

After installation, create `/etc/openconnect/local-overrides.conf`:

```
# <hostname>  [force-saml] [force-ext-browser] [disable-ipv6]
fortinet-vpn.example.com  force-saml  force-ext-browser  disable-ipv6
```

Flags:

- `force-saml` — skip auto-detection, go directly to the SAML flow.
  Use when the gateway supports SAML but the response page doesn't
  carry the `saml_login=1` marker auto-detection looks for.
- `force-ext-browser` — open the SSO page in the system default
  browser instead of the embedded webview. Use when the embedded
  QtWebEngine view (KDE) or WebKitGTK view (GNOME) can't validate the
  gateway's self-signed cert because the CN is the appliance serial
  rather than the public hostname.
- `disable-ipv6` — disable IPv6 advertisement during VPN negotiation.

`$XDG_CONFIG_HOME/openconnect/local-overrides.conf` (typically
`~/.config/openconnect/local-overrides.conf`) is checked if the system
file is absent. First match wins.

## Version

The fork uses its own SemVer starting at `1.0.0`, decoupled from
upstream openconnect's `9.x` line. Bump manually in the
arch-pkgbuilds `PKGBUILD` (`pkgver`) and `debian/changelog` when
cutting a release.
