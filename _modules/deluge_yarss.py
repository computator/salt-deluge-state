import Queue
import logging
from salt.exceptions import CommandExecutionError
log = logging.getLogger(__name__)

DELUGE_EXISTS = True
try:
	from twisted.python.failure import Failure
	from deluge.ui.client import client, reactor
	from threading import Thread
except ImportError:
	DELUGE_EXISTS = False

try:
	from yarss2.yarss_config import get_fresh_rssfeed_config, get_fresh_subscription_config, _verify_types
	log.info("Successfully imported YaRSS2 default config methods")

	def _verify_feed(feed):
		has_key = 'key' in feed
		_verify_types(feed['key'] if has_key else "", feed, get_fresh_rssfeed_config())
		if not has_key and 'key' in feed:
			del feed['key']
		return feed

	def _verify_subscr(subscr):
		has_key = 'key' in subscr
		_verify_types(subscr['key'] if has_key else "", subscr, get_fresh_subscription_config())
		if not has_key and 'key' in subscr:
			del subscr['key']
		return subscr

except ImportError:
	log.warn("Failed to import YaRSS2 default config methods. Falling back to internal defaults with limited error checking.")

	def get_fresh_rssfeed_config(name=u"", url=u"", site=u"", active=True, last_update=u"",
								 update_interval=120, update_on_startup=False,
								 obey_ttl=False, user_agent=u"", key=None):
		"""Create a new config (dictionary) for a feed"""
		config_dict = {}
		config_dict["name"] = name
		config_dict["url"] = url
		config_dict["site"] = site
		config_dict["active"] = active
		config_dict["last_update"] = last_update
		config_dict["update_interval"] = update_interval
		config_dict["update_on_startup"] = update_on_startup
		config_dict["obey_ttl"] = obey_ttl
		config_dict["user_agent"] = user_agent
		config_dict["prefer_magnet"] = False
		if key:
			config_dict["key"] = key
		return config_dict

	def get_fresh_subscription_config(name=u"", rssfeed_key="", regex_include=u"", regex_exclude=u"",
									  active=True, move_completed=u"", download_location=u"", last_match=u"",
									  label=u"", ignore_timestamp=False, key=None):
		"""Create a new config """
		config_dict = {}
		config_dict["rssfeed_key"] = rssfeed_key
		config_dict["regex_include"] = regex_include
		config_dict["regex_include_ignorecase"] = True
		config_dict["regex_exclude"] = regex_exclude
		config_dict["regex_exclude_ignorecase"] = True
		config_dict["name"] = name
		config_dict["active"] = active
		config_dict["last_match"] = last_match
		config_dict["ignore_timestamp"] = False
		config_dict["move_completed"] = move_completed
		config_dict["download_location"] = download_location
		config_dict["custom_text_lines"] = u""
		config_dict["email_notifications"] = {}  # Dictionary where keys are the keys of email_messages dictionary
		config_dict["max_download_speed"] = -2
		config_dict["max_upload_speed"] = -2
		config_dict["max_connections"] = -2
		config_dict["max_upload_slots"] = -2
		config_dict["add_torrents_in_paused_state"] = u"Default"
		config_dict["auto_managed"] = u"Default"
		config_dict["sequential_download"] = u"Default"
		config_dict["prioritize_first_last_pieces"] = u"Default"
		config_dict["label"] = label

		if key is not None:
			config_dict["key"] = key
		return config_dict

	def _verify_feed(feed):
		return get_fresh_rssfeed_config(**feed)

	def _verify_subscr(subscr):
		return get_fresh_subscription_config(**subscr)

class BlockingTimeout(RuntimeError): pass

def _block_on(d, timeout=None):
	q = Queue.Queue()
	d.addBoth(q.put)
	try:
		ret = q.get(timeout=timeout)
	except Queue.Empty:
		raise BlockingTimeout
	if isinstance(ret, Failure):
		ret.raiseException()
	else:
		return ret

def _reactor_call(callable, *args, **kwargs):
	q = Queue.Queue()
	def helper():
		try:
			q.put(callable(*args, **kwargs))
		except Exception as e:
			q.put(e)
	reactor.callFromThread(helper)
	rv = q.get()
	if isinstance(rv, Exception):
		raise rv
	else:
		return rv

class _Connection:
	def __init__(self, **creds):
		self._creds = creds

	def __enter__(self):
		_block_on(_reactor_call(client.connect, **self._creds))

	def __exit__(self, *exception):
		_block_on(_reactor_call(client.disconnect))

if(DELUGE_EXISTS):
	reactor_thread = Thread(target=reactor.run, args=(False,))
	reactor_thread.daemon = True
	reactor_thread.start()

# end of deluge related helpers

def __virtual__():
	return True if DELUGE_EXISTS else (False, "The deluge_yarss module cannot be loaded: deluge is not installed.")

def _check_yarss(ret=False):
	plugins = _block_on(_reactor_call(client.core.get_enabled_plugins), 120)
	log.debug("Enabled deluge plugins: %s", plugins)
	if 'YaRSS2' in plugins:
		return True
	log.warn("The deluge YaRSS2 plugin was not found")
	if not ret:
		raise CommandExecutionError("The deluge YaRSS2 plugin is not available")
	return False

def is_available(**connection_args):
	'''
	Checks if the deluge YaRSS2 plugin is is_available
	'''
	try:
		with _Connection(**{k[11:]: v for k, v in connection_args.iteritems() if k.startswith('connection_')}):
			return _check_yarss(True)
	except Exception as e:
		raise CommandExecutionError('Error calling deluge: {}: {}'.format(e.__class__.__name__, e))

def get_full_config(**connection_args):
	'''
	Gets the full YaRSS2 configuration
	'''
	try:
		with _Connection(**{k[11:]: v for k, v in connection_args.iteritems() if k.startswith('connection_')}):
			_check_yarss()
			config = _block_on(_reactor_call(client.yarss2.get_config), 120)
		return config
	except Exception as e:
		raise CommandExecutionError('Error calling deluge: {}: {}'.format(e.__class__.__name__, e))

def get_subscriptions(**connection_args):
	'''
	Gets a list of existing subscriptions
	'''
	try:
		with _Connection(**{k[11:]: v for k, v in connection_args.iteritems() if k.startswith('connection_')}):
			_check_yarss()
			config = _block_on(_reactor_call(client.yarss2.get_config), 120)
		return config['subscriptions']
	except Exception as e:
		raise CommandExecutionError('Error calling deluge: {}: {}'.format(e.__class__.__name__, e))

def get_subscription(name, **connection_args):
	'''
	Gets a subscription if it exists
	'''
	subscriptions = get_subscriptions(**connection_args)
	return next((subscriptions[i] for i in subscriptions if subscriptions[i]['name'] == name), None)

def get_subscription_key(name, **connection_args):
	'''
	Gets the key for a subscription if it exists
	'''
	subscription = get_subscription(name, **connection_args)
	return subscription['key'] if subscription else None

def get_feeds(**connection_args):
	'''
	Gets a list of existing rss feeds
	'''
	try:
		with _Connection(**{k[11:]: v for k, v in connection_args.iteritems() if k.startswith('connection_')}):
			_check_yarss()
			config = _block_on(_reactor_call(client.yarss2.get_config), 120)
		return config['rssfeeds']
	except Exception as e:
		raise CommandExecutionError('Error calling deluge: {}: {}'.format(e.__class__.__name__, e))

def get_feed(name, **connection_args):
	'''
	Gets a rss feed if it exists
	'''
	feeds = get_feeds(**connection_args)
	return next((feeds[i] for i in feeds if feeds[i]['name'] == name), None)

def get_feed_key(name, **connection_args):
	'''
	Gets the key for a rss feed if it exists
	'''
	feed = get_feed(name, **connection_args)
	return feed['key'] if feed else None

def set_subscription(data, **connection_args):
	'''
	Add a new subscription or update an existing subscription

	Updates an existing entry if data['key'] is set
	'''
	try:
		data = _verify_subscr(data)
		with _Connection(**{k[11:]: v for k, v in connection_args.iteritems() if k.startswith('connection_')}):
			_check_yarss()
			config = _block_on(_reactor_call(client.yarss2.save_subscription, subscription_data=data), 120)
	except Exception as e:
		raise CommandExecutionError('Error calling deluge: {}: {}'.format(e.__class__.__name__, e))

def set_feed(data, **connection_args):
	'''
	Add a new rss feed or update an existing rss feed

	Updates an existing entry if data['key'] is set
	'''
	try:
		data = _verify_feed(data)
		with _Connection(**{k[11:]: v for k, v in connection_args.iteritems() if k.startswith('connection_')}):
			_check_yarss()
			config = _block_on(_reactor_call(client.yarss2.save_rssfeed, rssfeed_data=data), 120)
	except Exception as e:
		raise CommandExecutionError('Error calling deluge: {}: {}'.format(e.__class__.__name__, e))

def remove_subscription(key, **connection_args):
	'''
	Deletes an existing subscription
	'''
	try:
		with _Connection(**{k[11:]: v for k, v in connection_args.iteritems() if k.startswith('connection_')}):
			_check_yarss()
			config = _block_on(_reactor_call(client.yarss2.save_subscription, dict_key=str(key), delete=True), 120)
	except Exception as e:
		raise CommandExecutionError('Error calling deluge: {}: {}'.format(e.__class__.__name__, e))

def remove_feed(key, **connection_args):
	'''
	Deletes an existing rss feed
	'''
	try:
		with _Connection(**{k[11:]: v for k, v in connection_args.iteritems() if k.startswith('connection_')}):
			_check_yarss()
			config = _block_on(_reactor_call(client.yarss2.save_rssfeed, dict_key=str(key), delete=True), 120)
	except Exception as e:
		raise CommandExecutionError('Error calling deluge: {}: {}'.format(e.__class__.__name__, e))
