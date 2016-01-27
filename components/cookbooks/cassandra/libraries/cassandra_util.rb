# A utility module to deal with cassandra storage
# config YAML and other helper methods.
#
# Cookbook Name:: cassandra
# Library:: cassandra_util
#
# Copyright 2015, @WalmartLabs.

module Cassandra

  module Util
    require 'json'
    require 'yaml'

    include Chef::Mixin::ShellOut

    # Checks if the YAML config directives are supported.
    # Applicable only if versions of Cassandra >= 1.2 and
    # has a non empty config directive map.
    #
    def conf_directive_supported?
      ci = node.workorder.rfcCi.ciAttributes
      ver = ci.version.to_f
      cfg = ci.config_directives if ci.has_key?("config_directives")
      cassandra_supported?(ver) && !cfg.nil? && !cfg.empty?
    end

    # Merge cassandra config directives to the given Cassandra
    # storage config YAML file. The method will error out if
    # it couldn't find the yaml config file.
    #
    # Note : Right now there is no way to preserve the comments in
    # YAML when you do the modification using libraries. Normally
    # this method call would be guarded by ::conf_directive_supported?
    #
    #  Eg:  merge_conf_directives(file, cfg) if conf_directive_supported?
    #
    # @param  config_file:: cassandra yaml config file
    # @param  cfg:: Configuration directives map.
    #
    def merge_conf_directives(config_file, cfg)
      Chef::Log.info "YAML config file: #{config_file}, conf directive entries: #{cfg}"
      # Always backup
      bak_file = config_file.sub('.yaml', '_template.yaml')
      File.rename(config_file, bak_file)
      yaml = YAML::load_file(bak_file)
      cfg.each_key { |key|
        val = parse_json(cfg[key])
        yaml[key] = val
      }
      Chef::Log.info "Merged cassandra YAML config: #{yaml.to_yaml}"

      File.open(config_file, 'w') { |f|
        f.write <<-EOF
# Cassandra storage config YAML
#
# NOTE:
#   See http://wiki.apache.org/cassandra/StorageConfiguration
#   or  #{bak_file} file for full
#   explanations of configuration directives
# /NOTE
#
# Auto generated by Cassandra cookbook
        EOF
        f.write yaml.to_yaml
        Chef::Log.info "Saved YAML config to #{config_file}"
      }
    end

    # Checks if the cassandra version is
    # supported for YAML config directives.
    #
    # @param ver:: cassandra version
    #
    def cassandra_supported?(ver)
      ver >= 1.2
    end


    # Checks whether the given string is a valid json or not.
    #
    # @param json:: input json string
    #
    def valid_json?(json)
      begin
        JSON.parse(json)
        return true
      rescue Exception => e
        return false
      end
    end

    # Returns the parsed json object if the input string is a valid json, else
    # returns the input by doing the type conversion. Currently boolean, float,
    # int and string types are supported. The type conversion is required for
    # yaml since the input from UI would always be string.
    #
    # @param json:: input json string
    #
    def parse_json (json)
      begin
        return JSON.parse(json)
      rescue Exception => e
        # Assuming it would be string.
        # Boolean type
        return true if  json =~ (/^(true)$/i)
        return false if  json =~ (/^(false)$/i)
        # Fixnum type
        return json.to_i if  (json.to_i.to_s == json)
        # Float type
        return json.to_f if  (json.to_f.to_s == json)
        return json
      end
    end


  end

end