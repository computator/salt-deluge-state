#!pydsl
include('deluge')

state('deluge-plugin-files') \
  .file.recurse(
    '/var/lib/deluged/config/plugins',
    source='salt://deluge/plugins',
    user='debian-deluged',
    group='debian-deluged'
  ) \
    .require(
      pkg='deluged',
      user='debian-deluged'
    ) \
    .require_in(
      service='deluged-service'
    )

plugins = [path.rsplit('/', 1)[1].split('-', 1)[0] for path in __salt__['cp.list_master'](prefix='deluge/plugins') if path.endswith('.egg')]

for plugin in plugins:
  state('deluge-enable-plugin-{0}'.format(plugin.lower())) \
    .cmd.run(
      name="deluge-console plugin --enable {0} | sed '/successfully updated/,$!{{$q1}}'".format(plugin),
      unless="deluge-console plugin --show | grep -Fq {0}".format(plugin)
    ) \
      .require(
        service='deluged-service',
        file='deluge-plugin-files'
      )
