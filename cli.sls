include:
  - deluge.daemon

deluge-console:
  pkg.installed:
    - require:
      - pkgrepo: deluge-ppa

# local creds
{% set local_pass = salt['grains.get_or_set_hash']('deluge:localclient:hash', 40, '0123456789abcdef') %}

deluged-creds-root:
  file.line:
    - name: /var/lib/deluged/config/auth
    - match: '^localclient:.*'
    - content: localclient:{{ local_pass }}:10
    - mode: insert
    - location: end
    - create: true
    - require:
      - file: deluged-config-dir
    - watch_in:
      - service: deluged

deluged-creds-root-config:
  file.append:
    - name: /root/.config/deluge/auth
    - text: localclient:{{ local_pass }}:10
    - makedirs: true
    - require:
      - file: deluged-creds-root
    - require_in:
      - pkg: deluge-console
