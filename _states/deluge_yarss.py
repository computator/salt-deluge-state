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

def subscription(name, regex, feed_id, **kwargs):
	'''
	Make sure a subscription exists with the specified values

	name
		The subscription title.
	regex
		The Regular Expression to match titles against. The regex_include value is set to this.
	feed_id
		The id of the RSS feed associated with this subscription. The rssfeed_key value is set to this.

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

	subscr_state = kwargs
	if 'key' in subscr_state:
		del subscr_state['key']
	subscr_state.update({
			'name': name,
			'regex_include': regex,
			'rssfeed_key': feed_id,
		})

	curr_subscr = __salt__['deluge_yarss.get_subscription'](name, **conn_args)
	if curr_subscr:
		log.debug("Found matching subscription: %s", curr_subscr)
	else:
		log.debug("No existing subscription found matching '%s'", name)

	if curr_subscr and len(subscr_state) == len(subscr_state.viewitems() & {k: curr_subscr[k] for k in curr_subscr if k != 'key'}.viewitems()):
		ret.update(comment="Subscription already up to date", result=True)
		return ret

	if curr_subscr:
		new_state = curr_subscr.copy()
		new_state.update(subscr_state)
		changes = {k: {'old': curr_subscr[k], 'new': v} for k, v in new_state.viewitems() - curr_subscr.viewitems()}
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