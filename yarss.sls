include:
  - deluge
  - deluge.plugins
  - deluge.root

{% import_yaml 'deluge/defaults.yaml' as defaults %}

deluge-torrent-dir-queue:
  file.directory:
    - name: {{ defaults.torrent_root }}/queue
    - user: debian-deluged
    - group: debian-deluged
    - mode: 755
    - require:
      - user: debian-deluged
      - file: deluge-torrent-root
    - require_in:
      - service: deluged

deluged-stop-for-config:
  service.dead:
    - name: deluged
    - prereq:
      - file: deluge-yarss-config

deluge-yarss-config:
  file.managed:
    - name: /var/lib/deluged/config/yarss2.conf
    - source: salt://deluge/yarss_config
    - template: jinja
    - user: debian-deluged
    - group: debian-deluged
    - mode: 644
    - require:
      - user: debian-deluged
      - pkg: deluged
    - require_in:
      - file: deluge-enable-plugin-yarss2
    - watch_in:
      - service: deluged
