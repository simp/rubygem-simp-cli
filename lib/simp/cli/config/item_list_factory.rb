require File.expand_path( 'items', File.dirname(__FILE__) )
require File.expand_path( 'logging', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config; end

# Builds an Array of Config::Items
class Simp::Cli::Config::ItemListFactory

  include Simp::Cli::Config::Logging

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


  def process( answers_hash={}, items_yaml = nil )
    @answers_hash = answers_hash

    # Require the config items
    rb_files = File.expand_path( '../config/item/*.rb', File.dirname(__FILE__))
    Dir.glob( rb_files ).sort_by(&:to_s).each { |file| require file }

    if items_yaml.nil?
      case @answers_hash.fetch('cli::simp::scenario')
      when 'simp', 'simp-lite'
        items_yaml  = create_simp_item_factory_yaml(false)
      when 'poss'
        items_yaml  = create_simp_item_factory_yaml(true)
      else
        raise "ERROR:  Unsupported scenario '#{@answers_hash['cli::simp::scenario']}'"
      end
    end

    begin
      items = YAML.load items_yaml
    rescue Psych::SyntaxError => e
      $stderr.puts "Invalid Items list YAML: #{e.message}"
      $stderr.puts '>'*80
      $stderr.puts items_yaml
      $stderr.puts '<'*80
      raise 'Internal error:  invalid Items list YAML'
    end
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
    dry_run_apply = false
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
      item.generate_option  = :generate_no_query if part == 'GENERATENOQUERY'
      item.generate_option  = :never_generate    if part == 'NEVERGENERATE'
      dry_run_apply         = true if part == 'DRYRUNAPPLY'
      if part =~ /^FILE=(.+)/
        item.file = $1
      end

    end
    #  ...based on cli options
    if (@options.fetch( :dry_run, false ) and !dry_run_apply)
      item.skip_apply = true 
      item.skip_apply_reason = '[**dry run**]'
    end
    item.start_time = @options.fetch( :start_time, Time.now )

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
        # append a silent YAML writer to save progress after each item
        item_queue << writer if writer
      end

      item_queue = build_item_queue( item_queue, items )
    end

    item_queue
  end


  # create a YAML writer that will "safety save" after each answer
  def create_safety_writer_item
    if file =  @options.fetch( :answers_output_file, nil)
      FileUtils.mkdir_p File.dirname( file ), :verbose => false
      writer = Simp::Cli::Config::Item::AnswersYAMLFileWriter.new
      file   = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      writer.file             = file
      writer.allow_user_apply = true
      writer.silent           = true  if @options.fetch(:verbose, 0) < 2
      writer.start_time       = @options.fetch( :start_time, Time.now )
      # don't sort the output so we figure out the last item answered
      writer.sort_output      = false
      writer
    end
  end

  # create SIMP-specific Item tree represented in YAML
  # explicit_query_required = Whether to query for items not in the answers file
  # for which the defaults should not be silently used.
  def create_simp_item_factory_yaml(explicit_query_required)
    if (explicit_query_required)
      query_options = '' 
    else
      query_options = 'SKIPQUERY SILENT'
    end
    <<-EOF.gsub(/^ {6}/,'')
      # The Config::Item list is really a conditional tree.  Some Items can
      # prepend additional Items to the queue, depending on the answer.
      #
      # This YAML describes the Item structure appropriate for 'simp'
      # 'simp-lite', and 'poss' scenarios.  The format is:
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
      #   FILE=value   = set the Item's .file to value
      #   DRYRUNAPPLY  = make sure this Item's apply() is called when the 
      #                 :dry_run option is selected; (Normally an Item's
      #                 .skip_apply is set to prevent the apply() from running
      #                 when :dry_run is selected.)
      #   NOAPPLY      = set the Item's .skip_apply ; Item.apply() will do nothing
      #   USERAPPLY    = execute Item's apply() even when running non-privileged
      #   SILENT       = set the Item's .silent ; suppresses stdout console/log output;
      #                  This option is best used in conjuction with SKIPQUERY for
      #                  Items for which no user interaction is required (i.e., 
      #                  Items for which internal logic can be used to figure
      #                  out their correct values).
      #   SKIPQUERY    = set the Item's .skip_query ; Item will use default_value
      #   NOYAML       = set the Item's .skip_yaml ; no YAML for Item will be written
      #   GENERATENOQUERY = set the PasswordItem's .generate_option to :generate_no_query
      #   NEVERGENERATE   = set the PasswordItem's .generate_option to :never_generate
      #
      #
      # WARNING:  Order matters, as some Items require settings from other Items.
      #           For example, several Items require cli::network::hostname, which is
      #           set by CliNetworkHostname.
      ---
      # ==== Initial actions ====
      - CliIsSimpEnvironmentInstalled  SKIPQUERY SILENT: # don't ever prompt, just discover current value
         false:
          - CopySimpToEnvironmentsAction  # Can't do our config, if this hasn't happened
      - CliSimpScenario SKIPQUERY SILENT # don't prompt; this value should already set
      - SetSiteScenarioAction
      - SimpOptionsFips SKIPQUERY SILENT: # don't ever prompt, just discover current setting
         true:
          - SetPuppetDigestAlgorithmAction # digest algorithm affects any puppet actions, so do it first!

      # ==== Network ====
      - CliNetworkInterface
      - CliSetUpNIC:  # Network info gathered and/or set here is needed by many Items
         true:
         - CliNetworkDHCP:
            static:                # gather info first, then configure network
             - CliNetworkHostname
             - CliNetworkIPAddress
             - CliNetworkNetmask
             - CliNetworkGateway
             - SimpOptionsDNSServers
             - SimpOptionsDNSSearch
             - ConfigureNetworkAction
            dhcp:                  # (minimally) configure network, then get info (silently)
             - ConfigureNetworkAction
             - CliNetworkHostname      SKIPQUERY SILENT
             - CliNetworkIPAddress     SKIPQUERY SILENT
             - CliNetworkNetmask       SKIPQUERY SILENT
             - CliNetworkGateway       SKIPQUERY SILENT
             - SimpOptionsDNSServers   SKIPQUERY SILENT
             - SimpOptionsDNSSearch    SKIPQUERY SILENT
         false:                    # don't configure network (but ask for info)
          - CliNetworkHostname
          - CliNetworkIPAddress
          - CliNetworkNetmask
          - CliNetworkGateway
          - SimpOptionsDNSServers
          - SimpOptionsDNSSearch
      - SetHostnameAction
      - SimpOptionsTrustedNets
      - SimpOptionsNTPServers

      # ==== General actions and related configuration ====
      - CliSetGrubPassword:
         true:
          - GrubPassword
          - SetGrubPasswordAction
      - SimpRunLevel                   SKIPQUERY SILENT # this is needed for compliance mapping

      # ==== Puppet actions and related configuration ====
      - CliSetProductionToSimp:
         true:
          - SetProductionToSimpAction
      - SimpOptionsPuppetServer            SKIPQUERY SILENT # default is correct
      - CliPuppetServerIP                  SKIPQUERY SILENT # don't ever prompt, just discover current value
      - SimpOptionsPuppetCA                SKIPQUERY SILENT # default is correct
      - SimpOptionsPuppetCAPort            SKIPQUERY SILENT # default is correct
      - PuppetDBMasterConfigPuppetDBServer SKIPQUERY SILENT # default is correct
      - PuppetDBMasterConfigPuppetDBPort   SKIPQUERY SILENT # default is correct
      - SetUpPuppetAutosignAction
      - UpdatePuppetConfAction
      - AddPuppetHostsEntryAction
      # Move the hieradata/hosts/puppet.your.domain.yaml template to
      # hieradata/hosts/<host>.yaml file (as appropriate) before
      # dealing with any features that modify that file
      - CreateSimpServerFqdnYamlAction
      - SetServerPuppetDBMasterConfigAction

      # ==== YUM actions and related configuration ====
      - CliHasLocalYumRepos                SKIPQUERY SILENT: # don't ever prompt, just discover current value
         true:
          - SimpYumServers                 SKIPQUERY SILENT # default is correct
          - UpdateOsYumRepositoriesAction
          - AddYumServerClassToServerAction
         false:
          - SimpYumServers
          - SimpYumOsUpdateUrl
          - SimpYumSimpUpdateUrl
          - SimpYumEnableOsRepos           SKIPQUERY SILENT # default is correct
          - SimpYumEnableSimpRepos         SKIPQUERY SILENT # default is correct
          - EnableOsAndSimpYumReposAction
          - CheckRemoteYumConfigAction

      # ==== Remaining global catalysts and their actions ===
      - SimpOptionsLdap                    #{query_options}: # make sure to query if not set in scenario
         true:
          - SimpOptionsSSSD                SKIPQUERY SILENT  # default is correct
          - SssdDomains                    SKIPQUERY SILENT  # default is correct
          - CliIsLdapServer:
             true:
              - SimpOptionsLdapBaseDn      SKIPQUERY SILENT       # default is correct
              - SimpOptionsLdapBindPw      GENERATENOQUERY SILENT # automatically generate
              - SimpOptionsLdapBindHash    SILENT                 # never queries 
              - SimpOptionsLdapSyncPw      GENERATENOQUERY SILENT # automatically generate
              - SimpOptionsLdapSyncHash    SILENT                 # never queries
              - SimpOpenldapServerConfRootpw
              - AddLdapServerClassToServerAction
              - SetServerLdapServerConfigAction
             false:
              - SimpOptionsLdapBaseDn
              - SimpOptionsLdapBindDn
              - SimpOptionsLdapBindPw      NEVERGENERATE
              - SimpOptionsLdapBindHash    SILENT #never queries
              - SimpOptionsLdapSyncDn
              - SimpOptionsLdapSyncPw      NEVERGENERATE
              - SimpOptionsLdapSyncHash    SILENT # never queries
              - SimpOptionsLdapMaster
              - SimpOptionsLdapUri
         false:
           - SimpOptionsSSSD:
              true:
               - SssdDomains
      - SimpOptionsSyslogLogServers
      - CliLogServersSpecified             SKIPQUERY SILENT: # don't ever prompt, just discover current value
         true:
          - SimpOptionsSyslogFailoverLogServers
      - GenerateCertificatesAction   # needed for SIMP server independent of scenario

      # ==== Writers ====
      - HieradataYAMLFileWriter FILE=#{ @options.fetch( :puppet_system_file, '/dev/null') }
      # This is the ONLY action that can be run as non-root user, as all it
      # does is create a file that is not within the Puppet environment.
      - AnswersYAMLFileWriter   FILE=#{ @options.fetch( :answers_output_file, '/dev/null') } USERAPPLY DRYRUNAPPLY
    EOF
  end

  def print_warning error
    logger.warn( "WARNING: ", [:YELLOW, :BOLD], error, [:YELLOW])
  end
end
