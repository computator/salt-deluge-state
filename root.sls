include:
  - deluge.daemon
  - deluge.cli

{% set torrent_root = '/var/lib/deluged/torrents' %}

deluge-torrent-root:
  file.directory:
    - name: {{ torrent_root }}
    - user: debian-deluged
    - group: debian-deluged
    - mode: 775
    - require:
      - user: deluged

deluge-torrent-dir-downloading:
  file.directory:
    - name: {{ torrent_root }}/downloading
    - user: debian-deluged
    - group: debian-deluged
    - mode: 775
    - require:
      - file: deluge-torrent-root
  cmd.run:
    - name: deluge-console config --set download_location {{ torrent_root }}/downloading | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config download_location | grep -Fq {{ torrent_root }}/downloading
    - require:
      - service: deluged
      - file: deluge-torrent-dir-downloading

deluge-torrent-dir-completed:
  file.directory:
    - name: {{ torrent_root }}/completed
    - user: debian-deluged
    - group: debian-deluged
    - mode: 775
    - require:
      - file: deluge-torrent-root
  cmd.run:
    - name: deluge-console config --set move_completed_path {{ torrent_root }}/completed | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config move_completed_path | grep -Fq {{ torrent_root }}/completed
    - require:
      - service: deluged
      - file: deluge-torrent-dir-completed

deluge-move-completed-setting:
  cmd.run:
    - name: deluge-console config --set move_completed true | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config move_completed | grep -q True
    - require:
      - service: deluged
      - cmd: deluge-torrent-dir-completed

deluge-stop-at-ratio-setting:
  cmd.run:
    - name: deluge-console config --set stop_seed_at_ratio true | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config stop_seed_at_ratio | grep -q True
    - require:
      - service: deluged
