include:
  - deluge.ppa

deluged:
  pkg.installed:
    - name: deluged
    - require:
      - pkgrepo: deluge-ppa
  file.managed:
    - name: /usr/local/lib/systemd/system/deluged.service
    - source: salt://deluge/deluged.service
    - makedirs: true
    - require:
      - pkg: deluged
  user.present:
    - name: debian-deluged
    {% if grains['saltversioninfo'][0] > 2019 or (grains['saltversioninfo'][0] == 2019 and grains['saltversioninfo'][1] > 2) %}
    - usergroup: true
    {% endif %}
    - home: /var/lib/deluged
    - system: true
    - require:
      - pkg: deluged
  service.running:
    - name: deluged
    - enable: true
    - init_delay: 2
    - require:
      - file: deluged
      - user: deluged
      - file: deluged-config-dir
      - file: deluged-log-dir

deluged-config-dir:
  file.directory:
    - name: /var/lib/deluged/config
    - user: debian-deluged
    - group: debian-deluged
    - mode: 750
    - require:
      - user: deluged

deluged-log-dir:
  file.directory:
    - name: /var/log/deluged
    - user: debian-deluged
    - group: adm
    - mode: 2755
    - require:
      - user: deluged

deluged-logrotate:
  file.managed:
    - name: /etc/logrotate.d/deluged
    - contents: |
        /var/log/deluged/deluged.log {
            weekly
            rotate 8
            compress
            missingok
            copytruncate
        }
    - replace: false
    - require:
      - file: deluged
