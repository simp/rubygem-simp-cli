require 'yaml'

module Simp::Cli::Config

  # YAML utilities for parsing and modifying a YAML file
  module YamlUtils

    # Add a tag directive to a YAML file
    #
    # - Will add tag_directive before the 1st key that matches
    #  'before_key_regex', when that regex is set
    # - The tag_directive must have been generated with the standard Ruby YAML
    #   library
    # - In order to make sure all the indentation in the resulting file is
    #   consistent, the file will be recreated with the standard Ruby
    #   YAML library, preserving blocks of comments (including empty lines)
    #   before the '---' and each major key.
    #   - Unnecessary quotes around string values will be removed and spacing
    #     will be normalized to that of the standard Ruby YAML output formatter.
    #     However, these formatting changes are insignificant.
    #   - TODO: Preserve other comments
    #
    # @param tag_directive tag directive to add
    # @param file_info Hash returned by load_yaml_with_comment_blocks
    # @param before_key_regex Optional regex specifying where tag directive
    #   should be inserted. When nil or no matching key is found,
    #   tag directive is appended the file.
    #
    # @raise Exception if file_info[:filename] cannot be opened for writing
    #   or any write fails
    #
    def add_yaml_tag_directive(tag_directive, file_info, before_key_regex = nil)
      tag_added = false
      File.open(file_info[:filename], 'w') do |file|
        file.puts(file_info[:preamble].join("\n")) unless file_info[:preamble].empty?
        file.puts('---')
        file_info[:content].each do |k, info|
          if before_key_regex && !tag_added && k.match?(before_key_regex)
            file.puts
            file.puts(tag_directive.strip)
            tag_added = true
          end
          # use write + \n to eliminate puts dedup of \n
          file.write(info[:comments].join("\n") +  "\n") unless info[:comments].empty?
          file.puts(pair_to_yaml_tag(k, info[:value]))
        end

        unless tag_added
          file.puts
          file.puts(tag_directive.strip)
        end
      end
    end

    # Parses a YAML file and returns a Hash with following structure
    #  {
    #    :filename => '/the/file/path',
    #    :preamble => [ ... ],  # comment lines that precede '---'
    #    :content  => {
    #      'key1' => {
    #        :comments => [ ... ],  # comment lines that precede the key
    #        :value    => < value for key 1>
    #      },
    #      'key2' => {
    #        :comments => [ ... ],  # comment lines that precede the key
    #        :value    => < value for key 2>
    #      },
    #      ...
    #    }
    #  }
    #
    #  Has no mechanism to evaluate Hieradata functions such as `alias`. So,
    #  the type of value that contains such a function will be String, even
    #  if after Hieradata evaluation the type would be something else. For
    #  example, "%{alias('simp_options::trusted_nets')}" would be considered
    #  a String, even though the evaluated type is an Array.
    #
    # @raise Exception if filename cannot be opened or standard YAML parsing of
    #   its content fails
    #
    def load_yaml_with_comment_blocks(filename)
      yaml_hash = YAML.load(IO.read(filename))
      keys = yaml_hash.keys

      content = {}
      start_found = false
      key_index = 0
      key = keys[key_index]
      initial_comment_block = []
      comment_block = []
      raw_lines = IO.readlines(filename)
      raw_lines.each do |line|
        if line.start_with?('---')
          start_found = true
          initial_comment_block = comment_block.dup
          comment_block.clear
          next
        end

        if start_found
          if line.match(/^'?#{key}'?\s*:/)
            content[key] = { :comments => comment_block.dup, :value => yaml_hash[key] }
            key_index += 1
            key = keys[key_index]
            comment_block.clear
          elsif (line[0] == '#') || line.strip.empty?
            comment_block << line.strip
          end
        else
          comment_block << line.strip
        end
      end

      {
        :filename => filename,
        :preamble => initial_comment_block,
        :content  => content
      }
    end

    # @return true if both inputs are Hashes or both inputs are Arrays
    def mergeable?(x, y)
      (x.is_a?(Hash) && y.is_a?(Hash)) || (x.is_a?(Array) && y.is_a?(Array))
    end

    # Merge/replace value of a key's tag directive in a YAML file
    #
    # - Leaves file untouched when
    #   - No changes are required.
    #   - Key specified does not already exist in file
    # - Merging is controlled by the 'merge' parameter and can only be enabled
    #   for Arrays or Hashes, when both the new and old values are of the same
    #   type
    #   - Will replace otherwise
    #   - Hash merges are limited to primary keys. In other words, **no**
    #     deep merging is provided.
    # - In order to make sure all the indentation in the resulting file is
    #   consistent, the file will be recreated with the standard Ruby
    #   YAML library, preserving blocks of comments (including empty lines)
    #   before the '---' and each major key.
    #   - Unnecessary quotes around string values will be removed and spacing
    #     will be normalized to that of the standard Ruby YAML output formatter.
    #     However, these formatting changes are insignificant.
    #   - TODO: Preserve other comments
    # - Has no mechanism to evaluate Hieradata functions such as `alias`. So,
    #   the type of value that contains such a function will be String, even
    #   if after Hieradata evaluation the type would be something else. For
    #   example, "%{alias('simp_options::trusted_nets')}" would be considered
    #   a String, even though the evaluated type is an Array.
    #
    # @param key key to update
    # @param new_value value to be merged/replaced
    # @param file_info Hash returned by load_yaml_with_comment_blocks
    # @param merge Whether to merge values for Array or Hash values. When false or
    #   value is not an Array or Hash, the value is replaced instead.
    #
    # @return operation performed: :none, :replace, :merge
    # @raise Exception if the file_info[:filename] cannot be opened for writing
    #   or any write fails
    #
    def merge_or_replace_yaml_tag(key, new_value, file_info, merge = false)
      change_type = :none
      return change_type unless file_info[:content].key?(key)

      old_value = file_info[:content][key][:value]
      return change_type if new_value == old_value

      if new_value.nil? || old_value.nil?
        change_type = :replace
        replace_yaml_tag(key, new_value, file_info)
      else
        if merge && mergeable?(old_value, new_value)
          if merge_required?(old_value, new_value)
            change_type = :merge
            merge_yaml_tag(key, new_value, file_info)
          end
        else
          change_type = :replace
          replace_yaml_tag(key, new_value, file_info)
        end
      end

      change_type
    end

    # @return true if new_value is not contained in old_value, when both are
    #   either Arrays or Hashes
    #
    def merge_required?(old_value, new_value)
      return false unless mergeable?(old_value, new_value)

      merge_required = false
      if old_value.is_a?(Array)
        merge_required = !( (new_value & old_value) == new_value)
      elsif old_value.is_a?(Hash)
        if (new_value.keys & old_value.keys) == new_value.keys
          new_value.each do |key,value|
            if old_value[key] != value
              merge_required = true
              break
            end
          end
        else
          merge_required = true
        end
      end

      merge_required
    end

    # Merge the new value for a key into its existing value and then replace
    # its tag directive in the YAML file
    #
    # - Only supports Arrays and Hashes
    # - Hash merges are limited to primary keys. In other words, **no** deep
    #   merging is provided.
    # - In order to make sure all the indentation in the resulting file is
    #   consistent, the file will be recreated with the standard Ruby
    #   YAML library, preserving blocks of comments (including empty lines)
    #   before the '---' and each major key.
    #   - Unnecessary quotes around string values will be removed and spacing
    #     will be normalized to that of the standard Ruby YAML output formatter.
    #     However, these formatting changes are insignificant.
    #   - TODO: Preserve other comments
    # - Has no mechanism to evaluate Hieradata functions such as `alias`. So,
    #   the type of value that contains such a function will be String, even
    #   if after Hieradata evaluation the type would be something else. For
    #   example, "%{alias('simp_options::trusted_nets')}" would be considered
    #   a String, even though the evaluated type is an Array.
    #
    # @param key key
    # @param new_value value to be merged
    # @param file_info Hash returned by load_yaml_with_comment_blocks
    #
    # @raise Exception if a tag directive for key is not present in the file,
    #   the type of new_value and the existing value are not both Arrays or
    #   Hashes, if the file_info[:filename] cannot be opened for writing
    #   or any write fails
    #
    def merge_yaml_tag(key, new_value, file_info)
      unless file_info[:content].key?(key)
        err_msg = "Unable to merge values for #{:key}:\n" +
          "#{key} does not exist in #{file_info[:filename]}"
        raise err_msg
      end

      old_value = file_info[:content][key][:value]

      unless mergeable?(old_value, new_value)
        err_msg = "Unable to merge values for #{key}:\n" +
          "old type (#{old_value.class}) and new type (#{new_value.class}) cannot be merged"
        raise err_msg
      end

      merged_value = nil
      if new_value.is_a?(Array)
        merged_value = (new_value + old_value).uniq
      else
        merged_value = old_value.merge(new_value)
      end

      replace_yaml_tag(key, merged_value, file_info)
    end

    # @return String containing the YAML tag directive for the <key,value> pair
    #
    # Examples:
    # * pair_to_yaml('key', 'value') would return "key: value"
    # * pair_to_yaml('key', [1, 2] would return
    #     <<~EOM
    #     key:
    #     - 1
    #     - 2
    #     EOM
    #
    def pair_to_yaml_tag(key, value)
      # TODO: should we be using SafeYAML?  http://danieltao.com/safe_yaml/
      { key => value }.to_yaml.gsub(/^---\s*\n/m, '')
    end

    # Replace tag directive for a key in a YAML file, preserving any existing
    # comment block prior that tag directive
    #
    # - Does nothing the if the key is not present in file_info
    # - Does **NOT** check if the existing value is of the same type as the
    #   original value.
    #
    # @param key key
    # @param new_value replacement value
    # @param file_info Hash returned by load_yaml_with_comment_blocks
    #
    def replace_yaml_tag(key, new_value, file_info)
      return unless file_info[:content].keys.include?(key)

      File.open(file_info[:filename], 'w') do |file|
        file.puts(file_info[:preamble].join("\n")) unless file_info[:preamble].empty?
        file.puts('---')
        file_info[:content].each do |k, info|
          # use write + \n to eliminate puts dedup of \n
          file.write(info[:comments].join("\n") +  "\n") unless info[:comments].empty?
          yaml_str = ''
          if k == key
            yaml_str = pair_to_yaml_tag(k, new_value)
          else
            yaml_str = pair_to_yaml_tag(k, info[:value])
          end

          file.puts(yaml_str)
        end
      end
    end
  end
end

