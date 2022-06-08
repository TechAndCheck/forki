# frozen_string_literal: true

require_relative "forki/version"

# Representative objects we create
require_relative "forki/user"
require_relative "forki/post"

require "helpers/configuration"
require_relative "forki/scrapers/scraper"

module Forki
  extend Configuration

  @@logger = Logger.new(STDOUT)

  class Error < StandardError; end
  class RetryableError < Error; end

  class InvalidUrlError < StandardError
    def initialize(msg = "Url must be a proper Facebook Url")
      super
    end
  end

  class ContentUnavailableError < StandardError
    def initialize(msg = "Post no longer available")
      super
    end
  end

  class MissingCredentialsError < StandardError
    def initalize(msg = "Missing FACEBOOK_EMAIL or FACEBOOK_PASSWORD environment variable")
      super
    end
  end

  define_setting :temp_storage_location, "tmp/forki"


  # Get an image from a URL and save to a temp folder set in the configuration under
  # temp_storage_location
  def self.retrieve_media(url)
    @@logger.info("Forki is downloading media from #{url}")
    response = Typhoeus.get(url)
    @@logger.info("Forki has finished downloading media from #{url}")

    # Get the file extension if it's in the file
    extension = url.split(".").last

    # Do some basic checks so we just empty out if there's something weird in the file extension
    # that could do some harm.
    if extension.length.positive?
      extension = nil unless /^[a-zA-Z0-9]+$/.match?(extension)
      extension = ".#{extension}" unless extension.nil?
    end

    temp_file = "#{Forki.temp_storage_location}/#{SecureRandom.uuid}#{extension}"

    # We do this in case the folder isn't created yet, since it's a temp folder we'll just do so
    create_temp_storage_location
    File.binwrite(temp_file, response.body)
    temp_file
  end

  def self.create_temp_storage_location
    return if File.exist?(Forki.temp_storage_location) && File.directory?(Forki.temp_storage_location)

    FileUtils.mkdir_p Forki.temp_storage_location
  end

  def self.set_logger_level
    if ENV["RAILS_ENV"] == "test" || ENV["RAILS_ENV"] == "development"
      @@logger.level = Logger::INFO
    else
      @@logger.level = Logger::WARN
    end
  end
end
