# Third-party components added by Raman VPN

Raman VPN is based on [Hiddify](https://github.com/hiddify/hiddify-app) (Hiddify Extended GPL v3, see
[LICENSE.md](LICENSE.md)). On top of it, these open-source components ship in the Android app:

| Tab | Component | Author | License | Notices in the app |
|---|---|---|---|---|
| Google Relay (1.7) | [mhrv-rs](https://github.com/therealaleph/MasterHttpRelayVPN-RUST) v1.9.38, Rust port of [MasterHttpRelayVPN](https://github.com/masterking32/MasterHttpRelayVPN) | therealaleph, masterking32 | MIT | `assets/raman/relay/LICENSE-mhrv-rs.txt` |
| DNS قطعی (1.8) | [Soar](https://github.com/getlantern/soar) v0.2.4 | the Lantern team | Apache-2.0 | `assets/raman/dnstunnel/LICENSE-soar.txt`, `THIRD_PARTY-soar-data.md` |
| DNS قطعی (1.8) | [CottenDNS](https://github.com/TaJirax/cottenDNS) v2026.11.04.181149-ac8e86e (derivative of StormDNS by NullRoute1970 and MasterDnsVPN by Amin Mahmoudi) | tajirax | MIT | `assets/raman/dnstunnel/LICENSE-cottendns.txt`, `THIRD_PARTY_NOTICES-cottendns.md`, `LICENSE-quic-go.txt`, `LICENSE-qpack.txt` |

The Go modules compiled into the DNS tunnel engines and their licenses: `assets/raman/dnstunnel/LICENSES-go-modules.txt`.
Summary notice: `assets/raman/dnstunnel/NOTICE.txt`. The engines are built by CI from the pinned versions
(`raman/relay/`, `raman/dnstunnel/`); no prebuilt binaries are committed.
