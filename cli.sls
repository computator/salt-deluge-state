include:
  - deluge.daemon

deluge-console:
  pkg.installed:
    - require:
      - pkgrepo: deluge-ppa

# local creds
{% set local_pass = salt['grains.get_or_set_hash']('deluge:localclient:hash', 40, '0123456789abcdef') %}

deluged-creds-root:
  file.replace:
    - name: /var/lib/deluged/config/auth
    - pattern: '^localclient:.*'
    - repl: localclient:{{ local_pass }}:10
    - append_if_not_found: true

deluged-creds-root-config:
  file.append:
    - name: /root/.config/deluge/auth
    - text: localclient:{{ local_pass }}:10
    - makedirs: true
    - require:
      - file: deluged-creds-root
    - require_in:
      - pkg: deluge-console
