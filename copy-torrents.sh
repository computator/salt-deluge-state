{% set torrent_root = '/var/lib/deluged/torrents' -%}
{% set subscription_file = salt['pillar.get']('deluge:yarss:subscription_file') -%}
{% if subscription_file -%}
{% import_yaml salt['pillar.get']('deluge:yarss:subscription_file') as subscriptions -%}
{% endif -%}
{% set subscriptions = salt['pillar.get']('deluge:yarss:subscriptions', subscriptions|default({}), merge=true) -%}
{% set r = subscriptions.regex|default() -%}
{% set ext_pattern = '[^/]*\\.(?:' + subscriptions.file_ext_pattern|default('mkv|mp4|avi') + ')' -%}
#!/bin/bash
declare -A torrent_match

torrent_match=(
	{%- for name, pattern in subscriptions.patterns.iteritems() %}
		{%- if pattern.regex|default() %}
			['{{ name }}']='{{ pattern.regex + ext_pattern }}'
		{%- else %}
			['{{ name }}']='{{ r.script_prefix|default('') + (pattern.match if pattern.match|default() else (pattern if pattern else name))|replace(' ', '.') + r.suffix|default('.*S\\d{2}E\\d{2}.*(?:720|1080)p') + ext_pattern }}'
		{%- endif -%}
	{%- endfor %}
)

for torrent in "${!torrent_match[@]}"
do
	src=$(find '{{ torrent_root }}/queue' -type f | grep -iP "${torrent_match[$torrent]}")
	if [[ "$src" ]]
	then
		[ -d "{{ subscriptions.copy_target }}/$torrent/" ] || mkdir "{{ subscriptions.copy_target }}/$torrent/"
		echo "$src" | xargs -d '\n' cp -uvt "{{ subscriptions.copy_target }}/$torrent/"
	fi
done
