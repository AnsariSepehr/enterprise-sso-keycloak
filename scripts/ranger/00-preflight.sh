#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 6 - READ-ONLY checks on the Ranger node, before touching anything.
# Every finding below cost real time in the original build (docs/troubleshooting.md, problems 25-27).
ok(){ printf '  [ok]   %s\n' "$*"; }; bad(){ printf '  [FAIL] %s\n' "$*"; rc=1; }; note(){ printf '  [info] %s\n' "$*"; }
rc=0
conf="$RANGER_CONF_DIR/ranger-admin-site.xml"

echo "Which configuration does Ranger really read?"
pid="$(pgrep -f 'org.apache.ranger.server.tomcat.EmbeddedServer|ranger-admin' | head -1 || true)"
if [ -n "$pid" ]; then
  note "running process $pid; conf entries on its class path:"
  ps -o args= -p "$pid" | tr ' :' '\n\n' | grep -iE '/conf($|/)' | sort -u | sed 's/^/         /' || true
else
  note "Ranger Admin is not running (fine before the first start, wrong after)"
fi
if [ -L /etc/ranger/admin/conf ]; then note "/etc/ranger/admin/conf -> $(readlink -f /etc/ranger/admin/conf)"; fi
[ -f "$conf" ] && ok "found $conf" || bad "$conf not found: set RANGER_CONF_DIR to the directory the process uses"

echo "Existing SSO settings (a stale attempt redirects every browser to the wrong place)"
if [ -f "$conf" ]; then
  prop(){ grep -A1 "<name>$1</name>" "$conf" | sed -n 's:.*<value>\(.*\)</value>.*:\1:p' | head -1; }
  enabled="$(prop ranger.sso.enabled)"; url="$(prop ranger.sso.providerurl)"
  note "ranger.sso.enabled     = ${enabled:-<unset>}"
  note "ranger.sso.providerurl = ${url:-<unset>}"
  note "ranger.externalurl     = $(prop ranger.externalurl)"
  case "$url" in
    "") note "no provider URL yet: clean install" ;;
    https://"$KNOX_HOSTNAME"/*) ok "provider URL already points at Knox" ;;
    *) bad "provider URL does not point at $KNOX_HOSTNAME: a stale attempt; 01-configure-knox-sso.sh replaces it" ;;
  esac
fi

echo "JMX exporter agent (a missing rules file makes the JVM exit at start)"
agent_files="$(grep -rl 'javaagent' "$RANGER_CONF_DIR"/*jmx*.sh 2>/dev/null || true)"
if [ -z "$agent_files" ]; then
  note "no JMX exporter agent configured for Ranger"
else
  for f in $agent_files; do
    rules="$(sed -nE 's|.*-javaagent:[^=]*=[0-9]+:(/[^ "]*).*|\1|p' "$f" | head -1)"
    if [ -z "$rules" ]; then note "$f: could not read the rules path"; elif [ -f "$rules" ]; then ok "rules file present: $rules"; else
      bad "rules file MISSING: $rules (create it, see docs/services/ranger.md section 2.3; minimal content: rules: - pattern: \".*\")"; fi
  done
fi

echo "Web server prerequisites"
if command -v getenforce >/dev/null; then
  mode="$(getenforce)"; note "SELinux: $mode"
  if [ "$mode" = Enforcing ]; then
    getsebool httpd_can_network_connect 2>/dev/null | grep -q '> on' && ok "httpd_can_network_connect is on" || note "httpd_can_network_connect is off: 02-setup-nginx.sh turns it on"
  fi
fi
rpm -q nginx >/dev/null 2>&1 && ok "nginx installed" || note "nginx not installed: 02-setup-nginx.sh installs it"
systemctl is-active --quiet firewalld && note "firewalld is running: 02-setup-nginx.sh opens http and https" || note "firewalld is not running: nothing filters port 6080 on this node (docs/known-limitations.md)"
ss -ltn 2>/dev/null | grep -q ':6080 ' && ok "port 6080 is listening" || note "nothing listens on 6080 yet"
[ -f "$KNOX_CERT_FILE" ] && ok "Knox certificate present: $KNOX_CERT_FILE" || bad "$KNOX_CERT_FILE missing: copy Knox's PEM certificate to this node first"
exit "$rc"
