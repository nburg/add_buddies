#!/usr/bin/ruby

require 'dbus'
require 'ldap'
require 'optparse'

class PidginStuff
  attr_accessor :opts
  @@sslport = LDAP::LDAPS_PORT
  @@scope   = LDAP::LDAP_SCOPE_SUBTREE

  def initialize
    session_bus = DBus::SessionBus.instance
    # Get the Pidgin Service
    purple_dbus = session_bus.service("im.pidgin.purple.PurpleService")
    # Get the object from this service
    @purple = purple_dbus.object("/im/pidgin/purple/PurpleObject")
    @purple.default_iface = "im.pidgin.purple.PurpleInterface"
    @purple.introspect
    @opts = {}
  end

  def check_group(target_group)
    if target_group == 0
      puts "Warning: Could not find #{@opts[:group]}. \nCreating it..."
      target_group = @purple.PurpleGroupNew(@opts[:group]).first
    end
    target_group
  end

  def account_ok?(target_account)
    if target_account == 0
      puts 'Error: Could not find account!'
      return false
    end
    true
  end

  def buddy_ok?(target_account, buddyname)
    @new_buddy = @purple.PurpleBuddyNew(target_account, buddyname, '').first
    if @new_buddy == 0
      puts "Error: Could not create #{buddyname}!"
      return false
    end
    true
  end

  def add_buddy(buddyname)
    target_group = @purple.PurpleFindGroup(@opts[:group]).first
    target_account = @purple.PurpleAccountsFind(@opts[:account], 'prpl-jabber').first
    target_group = check_group(target_group)
    exit 1 unless account_ok?(target_account) && buddy_ok?(target_account, buddyname)
    @purple.PurpleBlistAddBuddy(@new_buddy, 0, target_group, 0)
    @purple.PurpleAccountAddBuddy(target_account, @new_buddy)
    puts "Success! #{buddyname} added to #{@opts[:group]} on #{@opts[:account]}."
  end

  def add_buddies_from_list(list)
    list.each {|line| add_buddy(line.chomp + @opts[:suffix])}
  end

  def get_ldap_group_members(conn, host, base, attrs)
		filter = "(&(objectClass=groupOfUniqueNames)(cn=#{@opts[:ldap_group]}))"
		#conn.bind(@username, @password) if bind
    lgroup_attrs = {}
		conn.search(base, @@scope, filter, attrs) {|entry| lgroup_attrs = entry.to_hash}
    lgroup_attrs['hasMember']
  end

  def get_buddies_from_file(file)
    File.readlines(file)
  end


  def parse_flags
    opty = OptionParser.new do |op|
      op. banner = "Usage: #{$0} -a ACCOUNT -g GROUP -f FILE"
      op.separator ''
      op.separator "Specific Options:"
      op.on('-h', '--help', 'Display this screen') do
        puts op
        exit
      end
      op.on('-a', '--acount ACCOUNT', 'Set the pidgin account') do |account|
        @opts[:account] = account
      end
      op.on('-f', '--file FILE', 'Get list of buddies from FILE') do |file|
        @opts[:file] = file
      end
      op.on('-g', '--group GROUP', 'Set group to add buddies to') do |group|
        @opts[:group] = group
      end
      op.on('-l', '--ldap-group GROUP', 'Get list of buddies from ldap') do |ldap_group|
        @opts[:ldap_group] = ldap_group
      end
      @opts[:suffix] = ''
      op.on('-s', '--suffix SUFFIX', 'Set suffix to add to usernames') do |suffix|
        @opts[:suffix] = suffix
      end
    end
    opty.parse!
    @opts
  end

  def required_flags?
    message = ''
    message = message + "Error! No account specified.\n" if @opts[:account] == nil 
    message = "Error! No group specified.\n" if @opts[:group] == nil 
    puts message
    message == '' ? true : false
  end
end

if __FILE__ == $0
  pstuff = PidginStuff.new
  pstuff.parse_flags
  exit 1 unless pstuff.required_flags?
  if pstuff.opts[:ldap_group] != nil
    ldap_host = 'localhost'
    ldap_base = 'dc=example,dc=com'
    ldap_attrs = ['cn', 'hasMember']
    ldap_conn = LDAP::SSLConn.new(ldap_host, 636)
    buddylist = pstuff.get_ldap_group_members(ldap_conn, ldap_host, ldap_base, ldap_attrs)
  elsif pstuff.opts[:file] != nil
    buddlylist = File
    buddylist = pstuff.add_buddies_from_file(pstuff.opts[:file])
  else
    puts 'Error! -l or -g flag required.'
    exit 1
  end
  p buddylist
  pstuff.add_buddies_from_list(buddylist)
end
