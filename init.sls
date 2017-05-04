{% if grains['os'] == "Ubuntu" %}
# add PPA
deluge-ppa:
  pkgrepo.managed:
    - ppa: deluge-team/ppa
{% endif %}

# daemon
deluged-service:
  pkg.installed:
    - name: deluged
    {% if grains['os'] == "Ubuntu" %}
    - require:
      - pkgrepo: deluge-ppa
    {% endif %}
  service.running:
    - name: deluged
    - enable: true
    - init_delay: 2

# add service related things if they are missing
deluged-service-script:
  file.managed:
    - name: /etc/init.d/deluged
    - source: salt://deluge/deluged_service
    - mode: 755
    - replace: false
    - require:
      - pkg: deluged
    - require_in:
      - service: deluged-service

deluged-systemd-reload:
  module.wait:
    - name: service.systemctl_reload
    - watch:
      - pkg: deluged-service
      - file: deluged-service-script
    - require_in:
      - service: deluged-service

deluged-service-config:
  file.managed:
    - name: /etc/default/deluged
    - source: salt://deluge/deluged_default
    - mode: 644
    - replace: false
    - require:
      - file: deluged-service-script
    - watch_in:
      - service: deluged-service

deluged-service-enable:
  file.replace:
    - name: /etc/default/deluged
    - pattern: ^ENABLE_DELUGED=.*
    - repl: ENABLE_DELUGED=1
    - append_if_not_found: true
    - require:
      - file: deluged-service-config
    - watch_in:
      - service: deluged-service

deluged-service-umask:
  file.replace:
    - name: /etc/default/deluged
    - pattern: ^MASK=.*
    - repl: MASK=0002
    - append_if_not_found: true
    - require:
      - file: deluged-service-config
    - watch_in:
      - service: deluged-service

deluged-logrotate:
  file.managed:
    - name: /etc/logrotate.d/deluged
    - source: salt://deluge/deluged_logrotate
    - mode: 644
    - replace: false
    - require:
      - file: deluged-service-script

deluged-user:
  user.present:
    - name: debian-deluged
    - gid_from_name: true
    - home: /var/lib/deluged
    - createhome: false
    - system: true
    - require:
      - pkg: deluged
    - require_in:
      - service: deluged-service

deluged-dir-home:
  file.directory:
    - name: /var/lib/deluged
    - require:
      - pkg: deluged

deluged-dir-config:
  file.directory:
    - name: /var/lib/deluged/config
    - user: debian-deluged
    - group: debian-deluged
    - mode: 750
    - require:
      - file: deluged-dir-home
      - user: deluged-user
    - require_in:
      - service: deluged-service

deluged-dir-log:
  file.directory:
    - name: /var/log/deluged
    - user: debian-deluged
    - group: adm
    - mode: 2750
    - require:
      - pkg: deluged
      - user: deluged-user
    - require_in:
      - service: deluged-service

# CLI
deluge-console:
  pkg.installed:
    {% if grains['os'] == "Ubuntu" %}
    - require:
      - pkgrepo: deluge-ppa
    {% endif %}
    - require_in:
      - service: deluged-service

# local creds
{% set local_pass = salt['grains.get_or_set_hash']('deluge:localclient:hash', 40, '0123456789abcdef') %}

deluged-creds-root:
  file.append:
    - name: /var/lib/deluged/config/auth
    - text: localclient:{{ local_pass }}:10
    - require:
      - pkg: deluged
    - watch_in:
      - service: deluged-service

deluged-creds-root-config:
  file.append:
    - name: /root/.config/deluge/auth
    - text: localclient:{{ local_pass }}:10
    - makedirs: true
    - require:
      - pkg: deluged
      - file: deluged-creds-root
    - require_in:
      - pkg: deluge-console

# config

deluged-enable-remote:
  cmd.run:
    - name: deluge-console config --set allow_remote true | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config allow_remote | grep -q True
    - require:
      - service: deluged-service
    - listen_in:
      - service: deluged-service

{% if salt['pillar.get']('deluged:settings') %}
{% for setting, val in salt['pillar.get']('deluged:settings').items() %}
deluged-custom-setting_{{ setting }}:
  cmd.run:
    - name: deluge-console config --set {{ setting }} {{ val }} | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config {{ setting }} | grep -Fqe '{{ val }}'
    - require:
      - service: deluged-service
{% endfor %}
{% endif %}

# user config
{% if salt['pillar.get']('deluged:creds:user') %}
deluged-creds-user:
  file.append:
    - name: /var/lib/deluged/config/auth
    - text: {{ salt['pillar.get']('deluged:creds:user') }}:{{ salt['pillar.get']('deluged:creds:pass') }}:10
    - require:
      - pkg: deluged
    - watch_in:
      - service: deluged-service
{% endif %}
