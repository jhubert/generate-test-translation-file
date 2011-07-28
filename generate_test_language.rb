#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'

class Hash
  def deep_stringify_keys
    new_hash = {}
    self.each do |key, value|
      new_hash.merge!(key.to_s => (value.is_a?(Hash) ? value.deep_stringify_keys : value))
    end
  end

  def recursive_merge(h)
      self.merge!(h) {|key, _old, _new| if _old.class == Hash then _old.recursive_merge(_new) else _new end  } 
  end
end

module LanguageFile
  attr_accessor :data, :language_code, :extension, :dir

  def filename
    "#{dir}#{language_code}.#{extension}"
  end

  def keys
    read_yml_file[language_code] || {}
  end

  def map_to_flat_keys
    traverse_hash(map_to_grouped_keys)
  end

  def map_to_grouped_keys
    keys
  end

  def explode_keys(hash)
    cache = {}
    hash.sort.each do |k,v|
      next if v == '' || v.nil?
      key = k.split('.')
      cache[k] = key.reverse.inject(v) {|b,x| b = { x => b }  }
      puts cache.inspect
    end unless hash.nil?
    output = {}
    cache.each do |k,v|
      output.recursive_merge(v)
    end
    output
  end

  private

  def read_yml_file
    c = self.data
    c = "#{language_code}:\n" if c.nil?
    out = c.is_a?(String) ? YAML::load(c) : c
    out
  end

  def traverse_hash(hash, container={}, prefix='')
    hash.each do |k,v|
      key = prefix == '' ? k : "#{prefix}.#{k}"
      if v.is_a?(Hash)
        traverse_hash(v, container, key)
      else
        container[key] = v
      end
    end
    container
  end
end

class Source
  include LanguageFile

  def load!
    if !File.exists?(filename)
      puts "The source language file could not be found. Please make sure you're in the root of your rails app."
      return false
    end
    self.data = YAML::load(File.open(filename))
  end
end

class Destination
  include LanguageFile

  def keys
    read_yml_file || {}
  end

  def write!
    flat = self.map_to_flat_keys

    flat.each do |k,v|
      flat[k] = "x-#{v.split(' ')[0].downcase}"
    end

    File.open(filename, "w") do |f|
      f.write(yaml(self.explode_keys(flat)))
    end
  end

  def yaml(hash)
    method = hash.respond_to?(:ya2yaml) ? :ya2yaml : :to_yaml
    string = hash.deep_stringify_keys.send(method)
    string.gsub("!ruby/symbol ", ":").sub("---","").split("\n").map(&:rstrip).join("\n").strip
  end
end

if ARGV.size == 0
  puts "No arguments passed. Usage: ./generate_test_language.rb source_language_code [destination_language_code] [extension] [directory]"
  puts "Defaults:\n  destination_language_code: xx\n  extension: yml\n  directory: config/locales/"
  exit
end

source_language = ARGV[0]
output_language = ARGV[1] || 'xx'
extension = ARGV[2] || 'yml'
dir = ARGV[3] || 'config/locales/'

source = Source.new
source.dir = "config/locales/"
source.extension = "yml"
source.language_code = source_language

source.load!

destination = Destination.new
destination.dir = "config/locales/"
destination.extension = "yml"
destination.language_code = output_language
destination.data = source.data

destination.write!