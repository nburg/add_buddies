#!/usr/bin/ruby
#

require 'ldap'

host = 'localhost'
base = 'dc=example,dc=com'
username = ''
password = ''
conn = LDAP::SSLConn.new(host, 636)
attrs = ['cn', 'hasMember']
group = ''
bind = true

filter = "(&(objectClass=groupOfUniqueNames)(cn=#{group}))"
$attrs1 = {}
conn.search(base, LDAP::LDAP_SCOPE_SUBTREE, filter, attrs) {|entry| $attrs1 = entry.to_hash}
p $attrs1
