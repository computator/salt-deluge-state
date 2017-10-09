include:
  - deluge.ppa

deluge:
  pkg.installed:
    - require:
      - pkgrepo: deluge-ppa

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
