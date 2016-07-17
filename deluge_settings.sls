deluge-custom-default-settings:
  cmd.wait:
    - names:
      {% for setting, val in {
          'dont_count_slow_torrents': 'true',
          'max_active_downloading': '20',
          'max_active_limit': '30',
          'max_active_seeding': '10',
          'max_connections_global': '-1',
          'max_upload_slots_global': '-1',
        }.items() %}
      - deluge-console config --set {{ setting }} {{ val }} | sed '/successfully updated/,$!{$q1}'
      {% endfor %}
    - require:
      - service: deluged-service
    - watch:
      - pkg: deluged

deluged-umask:
  file.replace:
    - name: /etc/default/deluged
    - pattern: ^MASK=.*
    - repl: MASK=0022
    - append_if_not_found: true
    - require:
      - file: deluged-service-config
    - watch_in:
      - service: deluged-service
