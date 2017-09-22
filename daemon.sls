deluge-ppa:
  pkgrepo.managed:
    - ppa: deluge-team/ppa
    - require_in:
      - pkg: deluged

deluged:
  pkg.installed:
    - name: deluged
  file.managed:
    - name: /usr/local/lib/systemd/system/deluged.service
    - source: salt://deluge/deluged.service
    - makedirs: true
    - require:
      - pkg: deluged
  user.present:
    - name: debian-deluged
    - gid_from_name: true
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
        /var/log/deluged/daemon.log {
            weekly
            rotate 8
            compress
            missingok
            copytruncate
        }
    - replace: false
    - require:
      - file: deluged
