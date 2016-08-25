require File.expand_path( 'item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config; end

# Builds an Array of Config::Items
class Simp::Cli::Config::ItemListFactory
  def initialize( options )
    @options = {
      :verbose            => 0,
      :puppet_system_file => '/tmp/out.yaml',
    }.merge( options )

    # A hash to look up Config::Item values set from other sources (files, cli).
    # for each Hash element:
    # - the key will be the the Config::Item#key
    # - the value will be the @options#value
    @answers_hash = {}
  end


  def process( yaml=nil, answers_hash={} )
    @answers_hash = answers_hash

    # Require the config items
    rb_files = File.expand_path( '../config/item/*.rb', File.dirname(__FILE__))
    Dir.glob( rb_files ).sort_by(&:to_s).each { |file| require file }

    items_yaml = yaml || <<-EOF.gsub(/^ {6}/,'')
      # The Config::Item list is really a conditional tree.  Some Items can
      # prepend additional Items to the queue, depending on the answer.
      #
      # This YAML describes the full Item structure.  The format is:
      #
      # - ItemA
      # - ItemB
      #   answer1:
      #     - ItemC
      #     - ItemD
      #   answer2:
      #     - ItemE
      #     - ItemF
      # - ItemG
      #
      # modifers:
      #   FILE=value   = set the Item's .file flag to value
      #   NEWKEY=value = set the Item's .key to value
      #   NOAPPLY      = set the Item's .skip_apply flag to true
      #   NOYAML       = set the Item's .skip_yaml flag to true
      #   SILENT       = set the Item's .silent flag to true
      #   SKIPQUERY    = set the Item's .skip_query flag to true
      #   USERAPPLY    = execute apply() even when running non-privileged
      ---
      # ==== network ====
      - UseFips
      - NetworkInterface
      - SetupNIC:
         true:
         - DHCP:
            static:                # gather info first, then configure network
             - Hostname
             - IPAddress
             - Netmask
             - Gateway
             - DNSServers
             - DNSSearch
             - NetworkConf
            dhcp:                  # configure network, then get info (silently)
             - NetworkConf
             - Hostname     SILENT
             - IPAddress    SILENT
             - Netmask      SILENT
             - Gateway      SILENT
             - DNSServers   SILENT
             - DNSSearch    SILENT
         false:                    # don't configure network (but ask for info)
         - Hostname
         - IPAddress
         - Netmask
         - Gateway
         - DNSServers
         - DNSSearch
      - HostnameConf
      - ClientNets

      # ==== globals ====
      - NTPServers          NOAPPLY
      - LogServers
      - FailoverLogServers
      - SimpYumServers
      - UseAuditd
      - UseIPtables
      - CommonRunLevelDefault
      - UseSELinux
      - SetGrubPassword:
         true:
          - GrubPassword
      - Certificates
      # Move the hieradata/hosts/puppet.your.domain.yaml template to
      # hieradata/hosts/<domain>.yaml file (as appropriate) before
      # dealing with any features that modify that file
      - RenameFqdnYaml
      - IsMasterYumServer
      - YumRepositories

      # ==== puppet ====
      - PuppetServer
      - PuppetServerIP
      - PuppetCA
      - PuppetCAPort
      ### NOTE: removed since update to puppet server: - PuppetFileServer
      - PuppetAutosign
      - PuppetConf
      - PuppetHostsEntry
      - PuppetDBServer
      - PuppetDBPort

      # ==== ldap ====
      - UseLdap:
         true:
          - AddLdapToHiera
          - LdapBaseDn
          - LdapBindDn
          - LdapBindPw
          - LdapBindHash
          - LdapSyncDn
          - LdapSyncPw
          - LdapSyncHash
          - LdapRootDn
          - LdapRootHash
          - LdapMaster
          - LdapUri
         false:
          - RemoveLdapFromHiera
      - SssdDomains

      # ==== rsync ====
      - RsyncBase
      - RsyncServer         SILENT
      - RsyncTimeout        SILENT

      # ==== writers ====
      # The answers Hash returned by Questionnaire::process uses Item.key as the Hash key.  So,
      # only the apply results for the last AnswersYAMLFileWriter will be recorded in that Hash.
      # Since we want to see the results for both writers, below, we need to make the keys distinct.
      # Note the results of the safety-save writers will be effectivey squashed, as they will be
      # overwritten in the Hash with results for the writer that has the default key.
      - AnswersYAMLFileWriter FILE=#{ @options.fetch( :puppet_system_file, '/dev/null') } NEWKEY=yaml::production_file_writer
      - AnswersYAMLFileWriter FILE=#{ @options.fetch( :output_file, '/dev/null') } USERAPPLY
    EOF
    items = YAML.load items_yaml
    item_queue = build_item_queue( [], items )
    item_queue
  end



  def assign_value_from_hash( hash, item )
    value = hash.fetch( item.key, nil )
    if !value.nil?
      # workaround to allow cli/env var arrays
      value = value.split(',,') if item.is_a?(Simp::Cli::Config::ListItem) && !value.is_a?(Array)
      if ! item.validate value
        print_warning "'#{value}' is not an acceptable answer for '#{item.key}' (skipping)."
      else
        item.value = value
      end
    end
    item
  end


  # returns an instance of an Config::Item based on a String of its class name
  def create_item item_string
    # create item instance
    parts = item_string.split( /\s+/ )
    name  = parts.shift
    item  = Simp::Cli::Config::Item.const_get(name).new

    # set item options
    #   ...based on YAML keywords
    while !parts.empty?
      part = parts.shift
      if part =~ /^#/
        parts = []
        next
      end
      item.silent           = true if part == 'SILENT'
      item.skip_apply       = true if part == 'NOAPPLY'
      item.skip_query       = true if part == 'SKIPQUERY'
      item.skip_yaml        = true if part == 'NOYAML'
      item.allow_user_apply = true if part == 'USERAPPLY'
      if part =~ /^FILE=(.+)/
        item.file = $1
      end
      if part =~ /^NEWKEY=(.+)/
        item.key = $1
      end

    end
    #  ...based on cli options
    item.silent     = true if @options.fetch( :verbose ) < 0
    item.skip_apply = true if @options.fetch( :dry_run, false )

    # (try to) assign item values from various sources
    item = assign_value_from_hash( @answers_hash, item )
  end


  # recursively build an item queue
  def build_item_queue( item_queue, items )
    writer = create_safety_writer_item
    if !items.empty?
      item = items.shift
      item_queue << writer if writer

      if item.is_a? String
        item_queue << create_item( item )

      elsif item.is_a? Hash
        answers_tree = {}
        item.values.first.each{ |answer, values|
          answers_tree[ answer ] = build_item_queue( [], values )
        }
        _item = create_item( item.keys.first )
        _item.next_items_tree = answers_tree
        item_queue << _item
        item_queue << writer if writer
      end

      item_queue = build_item_queue( item_queue, items )
    end

    # append a silent YAML writer to save progress after each item

    item_queue
  end


  # create a YAML writer that will "safety save" after each answer
  def create_safety_writer_item
    if file =  @options.fetch( :output_file, nil)
      FileUtils.mkdir_p File.dirname( file ), :verbose => false
      writer = Simp::Cli::Config::Item::AnswersYAMLFileWriter.new
      file   = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      writer.file             = file
      writer.allow_user_apply = true
      writer.silent           = true  if @options.fetch(:verbose, 0) < 2
      writer
    end
  end

  def print_warning error
    say "<%= color(%q{WARNING: }, YELLOW,BOLD) %><%= color(%q{#{error}}, YELLOW) %>\n"
  end
end
