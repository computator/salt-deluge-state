include:
  - deluge.daemon
  - deluge.cli

deluged-enable-remote:
  cmd.run:
    - name: deluge-console config --set allow_remote true | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config allow_remote | grep -q True
    - require:
      - service: deluged
    - listen_in:
      - service: deluged

{% if salt['pillar.get']('deluged:settings') %}
{% for setting, val in salt['pillar.get']('deluged:settings').items() %}
deluged-custom-setting_{{ setting }}:
  cmd.run:
    - name: deluge-console config --set {{ setting }} {{ val }} | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config {{ setting }} | grep -Fqe '{{ val }}'
    - require:
      - service: deluged
{% endfor %}
{% endif %}

# user config
{% if salt['pillar.get']('deluged:creds:user') %}
deluged-creds-user:
  file.append:
    - name: /var/lib/deluged/config/auth
    - text: {{ salt['pillar.get']('deluged:creds:user') }}:{{ salt['pillar.get']('deluged:creds:pass') }}:10
{% endif %}