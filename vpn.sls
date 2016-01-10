include:
  - deluge
  - pia

extend:
  deluged:
    service:
      - watch:
        - service: openvpn

deluge-update-address-script:
  file.accumulated:
    - name: on_up
    - filename: /etc/openvpn/pia_manage.sh
    - text: |
        if /etc/init.d/deluged status > /dev/null; then
          deluge-console "config --set listen_interface $4" &
        fi
    - require_in:
      - file: pia-script

deluge-update-address:
  cmd.wait:
    - name: |
        deluge-console config --set listen_interface \
          $(\
            ip -4 -o addr show $(\
              ip route show 0/0 table 100 | grep -Po '(?<=dev )\w+' \
            ) \
            | grep -Po '(?<=inet )(\d+\.){3}\d+' \
          ) | sed '/successfully updated/,$!{$q1}'
    - watch:
      - service: deluged
      - service: openvpn
