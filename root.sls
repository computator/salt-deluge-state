include:
  - deluge

{% import_yaml 'deluge/defaults.yaml' as defaults %}

deluge-torrent-root:
  file.directory:
    - name: {{ defaults.torrent_root }}
    - user: debian-deluged
    - group: debian-deluged
    - mode: 755
    - require:
      - user: debian-deluged
      - file: /var/lib/deluged
    - require_in:
      - service: deluged-service

deluge-torrent-dir-downloading:
  file.directory:
    - name: {{ defaults.torrent_root }}/downloading
    - user: debian-deluged
    - group: debian-deluged
    - mode: 755
    - require:
      - user: debian-deluged
      - file: deluge-torrent-root
    - require_in:
      - service: deluged-service
  cmd.run:
    - name: deluge-console config --set download_location {{ defaults.torrent_root }}/downloading | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config download_location | grep -Fq {{ defaults.torrent_root }}/downloading
    - require:
      - service: deluged-service
      - file: deluge-torrent-dir-downloading

deluge-torrent-dir-completed:
  file.directory:
    - name: {{ defaults.torrent_root }}/completed
    - user: debian-deluged
    - group: debian-deluged
    - mode: 755
    - require:
      - user: debian-deluged
      - file: deluge-torrent-root
    - require_in:
      - service: deluged-service
  cmd.run:
    - name: deluge-console config --set move_completed_path {{ defaults.torrent_root }}/completed | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config move_completed_path | grep -Fq {{ defaults.torrent_root }}/completed
    - require:
      - service: deluged-service
      - file: deluge-torrent-dir-completed

deluge-move-completed-setting:
  cmd.run:
    - name: deluge-console config --set move_completed true | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config move_completed | grep -q True
    - require:
      - service: deluged-service
      - file: deluge-torrent-dir-completed

deluge-stop-at-ratio-setting:
  cmd.run:
    - name: deluge-console config --set stop_seed_at_ratio true | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config stop_seed_at_ratio | grep -q True
    - require:
      - service: deluged-service
