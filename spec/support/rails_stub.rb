# frozen_string_literal: true

require 'pathname'
require 'tmpdir'
require 'logger'

# Shared Rails stand-in for gem-level specs. The host app provides the real
# `Rails` constant; in the gem's spec process it doesn't exist, so loading any
# code that calls `Rails.root` / `Rails.configuration` / `Rails.logger` blows
# up at load time. This stub satisfies those calls with deterministic no-ops.
class Rails
  def self.root
    Pathname.new(Dir.tmpdir)
  end

  def self.configuration
    Struct.new(:converter).new(nil)
  end

  def self.env
    Struct.new(:production?, :test?).new(false, true)
  end

  def self.logger
    @logger ||= Logger.new($stdout)
  end
end

unless defined?(ActiveRecord)
  module ActiveRecord
    class RecordNotFound < StandardError; end
  end
end
