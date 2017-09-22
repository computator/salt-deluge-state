include:
  - deluge.daemon
  - deluge.cli

{% load_yaml as plugins %}
  - https://bitbucket.org/bendikro/deluge-yarss-plugin/downloads/YaRSS2-1.4.3-py2.7.egg
  - https://github.com/downloads/nicklan/Deluge-Pieces-Plugin/Pieces-0.5-py2.7.egg
  - https://github.com/downloads/ianmartin/Deluge-stats-plugin/Stats-0.3.2-py2.7.egg
  - http://forum.deluge-torrent.org/download/file.php?id=3047#/TotalTraffic-0.3.2-py2.7.egg
{% endload %}

{% for url in plugins -%}
{% set filename = url.rsplit('/', 1)[1] %}
deluge-plugin-{{loop.index}}:
  file.managed:
    - name: /var/lib/deluged/config/plugins/{{ filename }}
    - source: {{url}}
    - skip_verify: true
    - replace: false # avoids redownloading
    - user: debian-deluged
    - group: debian-deluged
    - mode: 664
    - makedirs: true
    - require:
      - file: deluged-config-dir
  cmd.run:
    - name: deluge-console plugin --enable {{ filename.split('-', 1)[0] }} | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console plugin --show | grep -Fq {{ filename.split('-', 1)[0] }}
    - require:
      - file: deluge-plugin-{{loop.index}}
      - service: deluged
{% endfor %}
