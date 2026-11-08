#!/usr/bin/env bash
# Usage: netem.sh <profile> [clients]
# Shapes the egress of the interface on the publisher network (10.77.1.0/24).
# Run it at both ends of the publisher link: in each publisher container and in the broker's namespace.
# Everything is per direction. delay = RTT / 2 where the source gives an RTT.
# rate is the uplink rate per publisher, so the qdisc rate is rate x clients behind it.
# netem syntax: delay MEAN JITTER CORRELATION, loss PERCENT CORRELATION, reorder PERCENT CORRELATION.
# Without "distribution", jitter is uniform in MEAN +/- JITTER (sigma = JITTER / 1.73). With
# "distribution normal", sigma = JITTER, which is what the sigma figures from [10] need.
# Marks: [source] value taken from a source, [no source] arbitrary value kept for didactic effect.
# A [no source] value followed by "contradicted" has a measurement that disagrees with it.
#
# Sources (v = checked against the original text, c = read by Codex only, ? = not checked):
#  [1] v https://github.com/ChromeDevTools/devtools-frontend/blob/main/front_end/core/sdk/NetworkManager.ts
#      Fast 4G: 60 ms RTT, 9 Mbps down, 1.5 Mbps up. Slow 4G: 150 ms, 1.6 Mbps / 750 kbps. Slow 3G: 400 ms, ~500 kbps.
#  [2] v https://github.com/GoogleChrome/lighthouse/blob/main/docs/throttling.md   (150 ms, 1.6 Mbps / 750 kbps, no loss)
#  [3] ? https://insights.opensignal.com/reports/2019/07/brazil/mobile-network-experience   (Brazil 4G latency 58.7 to 68 ms)
#  [4] v https://raw.githubusercontent.com/WPO-Foundation/webpagetest/master/www/settings/connectivity.ini.sample
#      Mobile Edge: 240/200 kbps, 840 ms RTT
#  [5] v https://arxiv.org/abs/2310.15808   Raman et al. GEO median latency 673.5 ms, LEO 56 to 154 ms;
#      GEO jitter 100 ms or more in over 80% of traces; upload: Starlink 6 to 21 Mbps, Viasat and HughesNet about 3 Mbps
#  [6] ? https://irep.iium.edu.my/122700/   (GEO: physical minimum ~480 ms, measured 600 to 3000 ms at one terminal)
#  [7] ? https://arxiv.org/abs/2502.15552   (Starlink RTT medians, 33 ms NZ and Chile to 80 ms Philippines)
#  [8] v https://blog.apnic.net/2022/11/28/fact-checking-starlinks-performance-figures/   (Starlink QUIC loss: 0.40% down, 0.45% up under light load)
#  [9] ? IETF MNQEUWS interim 2021, Bonaventure and Michel, Wi-Fi packet delivery time (qualitative only: weak Wi-Fi gives delay and jitter)
#      https://datatracker.ietf.org/meeting/interim-2021-mnqeuws-02/materials/slides-interim-2021-mnqeuws-02-sessa-olivier-bonaventure-francois-michel-packet-delivery-time-as-a-tie-breaker-for-assessing-wi-fi-access-points-00.pdf
# [10] v https://vbn.aau.dk/ws/files/311896874/AAU_wirelessMES_implementation_and_evaluation_VTCFall2019.pdf
#      Mogensen et al., Aalborg 2019, Table II, one-way: public LTE sigma 17.9 ms, PER 0.5%;
#      Wi-Fi with interference median 4.43 ms, p99 217 ms, max 1187 ms, sigma 43 ms, PER 0.06%
set -euo pipefail
profile=${1:?profile: lan 4g 4g-slow 3g edge satellite-geo satellite-leo wifi-bad wifi-long congested}
n=${2:-1}
dev=$(ip -o -4 addr show | awk '/10\.77\.1\./ {print $2}')

case $profile in
  lan) args="" ;;
  # delay 30ms, rate 1500kbit: [1] Fast 4G (60 ms RTT, 1.5 Mbps up), [3] Brazil 4G 58.7 to 68 ms
  # jitter 18ms with distribution normal (sigma 17.9 ms) and loss 0.5%: [10] public LTE. correlation 25%: [no source]
  4g)            args="delay 30ms 18ms 25% distribution normal loss 0.5% rate $((1500 * n))kbit" ;;
  # delay 75ms, rate 750kbit, no loss: [1] Slow 4G, [2] Lighthouse (150 ms RTT, 750 kbps up)
  4g-slow)       args="delay 75ms rate $((750 * n))kbit" ;;
  # delay 200ms, rate 500kbit: [1] Slow 3G (400 ms RTT, ~500 kbps)
  # loss 1%: [no source], contradicted (UMTS uplink loss measured at 0.025% and 0.066%, Ferlin et al. 2013, c)
  3g)            args="delay 200ms loss 1% rate $((500 * n))kbit" ;;
  # delay 420ms, rate 200kbit: [4] Mobile Edge (840 ms RTT, 200 kbps up). jitter 100ms, loss 3%: [no source]
  edge)          args="delay 420ms 100ms loss 3% rate $((200 * n))kbit" ;;
  # delay 337ms: [5] median 673.5 ms RTT, [6] 600 ms or more. rate 3mbit: [5] Viasat and HughesNet upload about 3 Mbps
  # jitter 30ms: [no source], contradicted by [5] (jitter 100 ms or more, a different quantity). loss 1%: [no source]
  satellite-geo) args="delay 337ms 30ms loss 1% rate $((3000 * n))kbit" ;;
  # delay 25ms: [5][7] ~50 ms RTT. loss 0.45%: [8] uplink, light load. rate 10mbit: inside the Starlink upload range of [5], 6 to 21 Mbps
  # jitter 15ms: [no source] (FjordLink, TUHH 2025: Starlink jitter median 3.8 ms, p99 28 ms, c)
  satellite-leo) args="delay 25ms 15ms loss 0.45% rate $((10000 * n))kbit" ;;
  # delay 3ms 60ms distribution pareto: fitted to [10] interfered Wi-Fi (sigma 43 ms, p99 217 ms). Measured on netem:
  # sigma 40 ms, p99 235 ms, but median 0.1 ms (measured 4.43 ms, negative delays clamp) and max 246 ms (measured 1187 ms).
  # loss 8% 25% and rate 5mbit: [no source]. Contradicted: [10] measured PER of interfered Wi-Fi is 0.06%.
  # 8% is a didactic extreme. [9] is qualitative only.
  wifi-bad)      args="delay 3ms 60ms distribution pareto loss 8% 25% rate $((5000 * n))kbit" ;;
  # [no source] (similar to the Latency Ninja lossy Wi-Fi preset: 15 ms, 10 ms, 3%, 20 mbit, synthetic)
  wifi-long)     args="delay 15ms 10ms loss 3% rate $((10000 * n))kbit" ;;
  # [no source], contradicted: duplicate 1% and reorder 10% are far above backbone measurements
  # (about 0.022% duplicates and at most 0.5% reordering, Jaiswal et al. IMC 2002, c). A stress profile.
  congested)     args="delay 80ms 60ms loss 2% duplicate 1% reorder 10% 50% rate $((1000 * n))kbit" ;;
  *) echo "unknown profile: $profile" >&2; exit 1 ;;
esac

# del before add: replace or change would keep parameters of the previous profile
tc qdisc del dev "$dev" root 2>/dev/null || true
[ -z "$args" ] || tc qdisc add dev "$dev" root netem $args
