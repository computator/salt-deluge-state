include:
  - deluge.ppa

deluge:
  pkg.installed:
    - require:
      - pkgrepo: deluge-ppa

deluge-setdefault:
  cmd.run:
    - name: xdg-settings set default-url-scheme-handler magnet deluge.desktop
    - unless: xdg-settings check default-url-scheme-handler magnet deluge.desktop | grep -q yes
    - runas: computator

{% import_yaml "deluge/plugins.yaml" as plugins %}

{% for url in plugins -%}
{% set filename = url.rsplit('/', 1)[1] %}
deluge-plugin-{{loop.index}}:
  file.managed:
    - name: /home/computator/.config/deluge/plugins/{{ filename }}
    - source: {{url}}
    - skip_verify: true
    - replace: false # avoids redownloading
    - user: computator
    - group: computator
    - mode: 664
    - makedirs: true
    - require:
      - pkg: deluge
{% endfor %}
