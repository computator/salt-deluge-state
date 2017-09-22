from salt.exceptions import SaltInvocationError
import logging
log = logging.getLogger(__name__)

def feed(name, url, **kwargs):
	'''
	Make sure a RSS feed exists with the specified values

	name
		The RSS feed title.
	url
		The RSS feed URL.

	Options that start with 'connection_' are used to connect to the deluge daemon. All other options override the corresponding subscription value.
	'''

	ret = {
			'name': name,
			'result': False,
			'changes': {},
			'comment': '',
		}

	conn_args = {}
	for k in kwargs:
		if k.startswith('connection_'):
			conn_args[k] = kwargs.pop(k)

	feed_state = kwargs
	if 'key' in feed_state:
		del feed_state['key']
	feed_state.update({
			'name': name,
			'url': url,
		})

	curr_feed = __salt__['deluge_yarss.get_feed'](name, **conn_args)
	if curr_feed:
		log.debug("Found matching RSS feed: %s", curr_feed)
	else:
		log.debug("No existing RSS feed found matching '%s'", name)

	if curr_feed and len(feed_state) == len(feed_state.viewitems() & {k: curr_feed[k] for k in curr_feed if k != 'key'}.viewitems()):
		ret.update(comment="RSS feed already up to date", result=True)
		return ret

	if curr_feed:
		new_state = curr_feed.copy()
		new_state.update(feed_state)
		changes = {k: {'old': curr_feed[k], 'new': v} for k, v in new_state.viewitems() - curr_feed.viewitems()}
	else:
		new_state = feed_state
		changes = {k: {'old': None, 'new': v} for k, v in new_state.iteritems()}

	if __opts__['test']:
		ret.update(comment="RSS feed will be " + ("updated" if curr_feed else "added"), pchanges=changes, result=None)
		return ret

	log.debug("Calling set_feed with values: %s", new_state)
	__salt__['deluge_yarss.set_feed'](new_state, **conn_args)

	ret.update(comment="RSS feed was " + ("updated" if curr_feed else "added"), changes=changes, result=True)
	return ret

def subscription(name, regex, **kwargs):
	'''
	Make sure a subscription exists with the specified values

	name
		The subscription title.
	regex
		The Regular Expression to match titles against. The regex_include value is set to this.
	feed_key
	feed_name
		The key or name of the RSS feed associated with this subscription. At least one of the two
		values must be specified. The rssfeed_key value is set to the key specified with feed_key if
		feed_key is set, otherwise the feeds are searched for a feed with a name that matches feed_name
		and rssfeed_key is set to the corresponding key.

	Options that start with 'connection_' are used to connect to the deluge daemon. All other options override the corresponding subscription value.
	'''

	ret = {
			'name': name,
			'result': False,
			'changes': {},
			'comment': '',
		}

	conn_args = {}
	for k in kwargs:
		if k.startswith('connection_'):
			conn_args[k] = kwargs.pop(k)

	if 'feed_key' in kwargs:
		feed_key = kwargs['feed_key']
	elif 'feed_name' in kwargs:
		feed_key = __salt__['deluge_yarss.get_feed_key'](kwargs['feed_name'], **conn_args)
	else:
		raise SaltInvocationError("Either 'feed_key' or 'feed_name' must be specified")

	# continue checking if the subscription could potentially be added or updated if we
	# are in test mode and the feed key doesn't exist, otherwise return an error that the
	# feed key is invalid
	if not __opts__['test'] and feed_key is not None:
		ret.update(comment="The specified feed key is invalid or could not be found", result=False)
		return ret

	subscr_state = {k: kwargs[k] for k in kwargs if k not in ['key', 'feed_key', 'feed_name']}
	subscr_state.update({
			'name': name,
			'regex_include': regex,
			'rssfeed_key': str(feed_key),
		})

	curr_subscr = __salt__['deluge_yarss.get_subscription'](name, **conn_args)
	if curr_subscr:
		log.debug("Found matching subscription: %s", curr_subscr)
	else:
		log.debug("No existing subscription found matching '%s'", name)

	# if we are in test mode and the feed key doesn't exist at the moment we
	# don't know whether the subscription will be added or updated
	if __opts__['test'] and not feed_key:
		ret.update(comment="Subscription will be added or updated", result=None)
		return ret

	if curr_subscr:
		if curr_subscr['email_notifications'] == (subscr_state['email_notifications'] if 'email_notifications' in subscr_state else {}):
			old_items = {k: curr_subscr[k] for k in curr_subscr if k not in ('key', 'email_notifications')}
			new_items = {k: subscr_state[k] for k in subscr_state if k != 'email_notifications'}
			if len(old_items) == len(old_items.viewitems() & new_items.viewitems()):
				ret.update(comment="Subscription already up to date", result=True)
				return ret

	if curr_subscr:
		new_state = curr_subscr.copy()
		new_state.update(subscr_state)
		old_items = {k: curr_subscr[k] for k in curr_subscr if k != 'email_notifications'}
		new_items = {k: new_state[k] for k in new_state if k != 'email_notifications'}
		changes = {k: {'old': old_items[k], 'new': v} for k, v in new_items.viewitems() - old_items.viewitems()}
		if curr_subscr['email_notifications'] != (new_state['email_notifications'] if 'email_notifications' in new_state else {}):
			changes['email_notifications'] = {'old': curr_subscr['email_notifications'], 'new': (new_state['email_notifications'] if 'email_notifications' in new_state else {})}
	else:
		new_state = subscr_state
		changes = {k: {'old': None, 'new': v} for k, v in new_state.iteritems()}

	if __opts__['test']:
		ret.update(comment="Subscription will be " + ("updated" if curr_subscr else "added"), pchanges=changes, result=None)
		return ret

	log.debug("Calling set_subscription with values: %s", new_state)
	__salt__['deluge_yarss.set_subscription'](new_state, **conn_args)

	ret.update(comment="Subscription was " + ("updated" if curr_subscr else "added"), changes=changes, result=True)
	return ret