include:
  - deluge.daemon
  - deluge.cli

{% import_yaml "deluge/plugins.yaml" as plugins %}

{% for url in plugins -%}
{% set filename = url.rsplit('/', 1)[1] %}
deluged-plugin-{{loop.index}}:
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
    - watch_in:
      - service: deluged
  cmd.run:
    - name: deluge-console plugin --enable {{ filename.split('-', 1)[0] }} | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console plugin --show | grep -Fq {{ filename.split('-', 1)[0] }}
    - require:
      - file: deluged-plugin-{{loop.index}}
      - service: deluged
{% endfor %}
