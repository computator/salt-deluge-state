include:
  - deluge.daemon
  - deluge.cli
  - deluge.plugins
  - deluge.root

{% set torrent_root = '/var/lib/deluged/torrents' %}

deluge-torrent-dir-queue:
  file.directory:
    - name: {{ torrent_root }}/queue
    - user: debian-deluged
    - group: debian-deluged
    - mode: 755
    - require:
      - file: deluge-torrent-root

deluge-yarss-copy-script:
  file.managed:
    - name: /var/lib/deluged/copy-torrents.sh
    - source: salt://deluge/copy-torrents.sh
    - template: jinja
    - user: debian-deluged
    - group: debian-deluged
    - mode: 755
    - require:
      - user: deluged
      - file: deluge-torrent-dir-queue

deluge-yarss-link-script:
  file.symlink:
    - name: /usr/local/bin/copy-torrents
    - target: /var/lib/deluged/copy-torrents.sh
    - require:
      - file: deluge-yarss-copy-script

# load subscription data
{% set subscription_file = salt['pillar.get']('deluge:yarss:subscription_file') -%}
{% if subscription_file -%}
{% import_yaml salt['pillar.get']('deluge:yarss:subscription_file') as subscriptions -%}
{% endif -%}
{% set subscriptions = salt['pillar.get']('deluge:yarss:subscriptions', subscriptions|default({}), merge=true) -%}
{% set r = subscriptions.regex|default() -%}

# process feeds
{% for feed, args in subscriptions.feeds.iteritems() %}
deluge-yarss-feeds_{{ feed|replace(' ', '_') }}:
  deluge_yarss.feed:
    - name: {{ feed }}
    - url: {{ (args.url if args.url|default() else args) }}
    - site: '{{ args.site|default( (args.url if args.url|default() else args)|regex_match('\w+://(?:[^/@]*@)?([^:/]+)(?::\d+)?/', ignorecase=True)|first ) }}'
    - update_interval: {{ args.interval|default(10) }}
    - require:
      - file: deluge-torrent-dir-queue
      - service: deluged
{% endfor %}

# process subscriptions
{% for name, pattern in subscriptions.patterns.iteritems() %}
deluge-yarss-subscriptions_{{ name|replace(' ', '_') }}:
  deluge_yarss.subscription:
    - name: {{ name }}
    {% if pattern.regex|default() %}
    - regex: {{ pattern.regex|default() }}
    {% else %}
    - regex: {{ ( r.prefix|default('^') + (pattern.match if pattern.match|default() else (pattern if pattern else name))|replace(' ', '.') + r.suffix|default('.*S\\d{2}E\\d{2}.*(?:720|1080)p') ) }}
    {% endif %}
    - regex_exclude: '{{ pattern.exclude|default('') }}'
    - feed_key: {{ pattern.feed|default(0) }}
    - download_location: {{ torrent_root }}/downloading
    - move_completed: {{ torrent_root }}/queue
    - require:
      - file: deluge-torrent-dir-queue
      - service: deluged
      {% if pattern.feed|default() %}
      - deluge_yarss: deluge-yarss-feeds_{{ pattern.feed|replace(' ', '_') }}
      {% endif %}
{% endfor %}