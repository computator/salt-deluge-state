#!pydsl

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
      service='deluged'
    )

plugins = [path.rsplit('/', 1)[1].split('-', 1)[0] for path in __salt__['cp.list_master'](prefix='deluge/plugins') if path.endswith('.egg')]

state('deluge-enable-plugins') \
  .cmd.wait(
    names=["deluge-console plugin --enable {0} | sed '/successfully updated/,$!{{$q1}}'".format(plugin) for plugin in plugins]
  ) \
    .require(
      service='deluged'
    ) \
    .watch(
      file='deluge-plugin-files'
    )