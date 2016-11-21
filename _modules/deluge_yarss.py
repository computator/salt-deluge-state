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
