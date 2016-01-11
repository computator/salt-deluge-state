# add PPA
deluge-ppa:
  pkgrepo.managed:
    - ppa: deluge-team/ppa

# daemon
deluged:
  pkg.installed:
    - require:
      - pkgrepo: deluge-ppa
  service.running:
    - name: deluged
    - enable: true
    - init_delay: 2

# add service related things if they are missing
deluged-service:
  file.managed:
    - name: /etc/init.d/deluged
    - source: salt://deluge/deluged_service
    - mode: 755
    - replace: false
    - require:
      - pkg: deluged
    - require_in:
      - service: deluged

deluged-service-config:
  file.managed:
    - name: /etc/default/deluged
    - source: salt://deluge/deluged_default
    - mode: 644
    - replace: false
    - require:
      - file: deluged-service
    - watch_in:
      - service: deluged

deluged-logrotate:
  file.managed:
    - name: /etc/logrotate.d/deluged
    - source: salt://deluge/deluged_logrotate
    - mode: 644
    - replace: false
    - require:
      - file: deluged-service

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
      - service: deluged

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
      - service: deluged

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
      - service: deluged

# CLI
deluge-console:
  pkg.installed:
    - require:
      - pkgrepo: deluge-ppa
    - require_in:
      - service: deluged

# local creds
{% set local_pass = salt['grains.get_or_set_hash']('deluge:localclient:hash', 40, '0123456789abcdef') %}

deluged-creds-root:
  file.append:
    - name: /var/lib/deluged/config/auth
    - text: localclient:{{ local_pass }}:10
    - require:
      - pkg: deluged
    - watch_in:
      - service: deluged

deluged-creds-root-config:
  file.append:
    - name: /root/.config/deluge/auth
    - text: localclient:{{ local_pass }}:10
    - makedirs: true
    - require:
      - pkg: deluged
      - file: deluged-creds-root

# config

deluged-enable-remote:
  cmd.run:
    - name: deluge-console config --set allow_remote true | sed '/successfully updated/,$!{$q1}'
    - unless: deluge-console config allow_remote | grep -q True
    - require:
      - service: deluged

# user config
{% if salt['pillar.get']('deluged:creds:user') %}
deluged-creds-user:
  file.append:
    - name: /var/lib/deluged/config/auth
    - text: {{ salt['pillar.get']('deluged:creds:user') }}:{{ salt['pillar.get']('deluged:creds:pass') }}:10
    - require:
      - pkg: deluged
    - watch_in:
      - service: deluged
{% endif %}
