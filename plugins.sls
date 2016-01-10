include:
  - deluge

deluge-plugin-files:
  file.recurse:
    - name: /var/lib/deluged/config/plugins
    - source: salt://deluge/plugins
    - user: debian-deluged
    - group: debian-deluged
    - require:
      - pkg: deluged
      - user: debian-deluged
    - require_in:
      - service: deluged
