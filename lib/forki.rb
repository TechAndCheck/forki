# frozen_string_literal: true

require_relative "forki/version"

# Representative objects we create
require_relative "forki/user"
require_relative "forki/post"

require "helpers/configuration"
require_relative "forki/scrapers/scraper"
require_relative "forki/scrapers/sieves/video_sieves/video_sieve"

module Forki
  extend Configuration

  @@forki_logger = Logger.new(STDOUT)

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

  class BlockedCredentialsError < StandardError
    def initalize(msg = "Credentials are most likely being blocked")
      super
    end
  end

  class UnhandledContentError < StandardError
    def initialize(msg = "Forki does not know how to handle the post")
      super
    end
  end

  define_setting :temp_storage_location, "tmp/forki"

  # Extract the file extension from a media URL
  # E.g. ".png" from https://scontent-atl3-2.xx.fbcdn.net/v/t39.30808-1.png?stp=dst-png_p148x148
  def self.extract_file_extension_from_url(url)
    return nil if url.nil?

    stripped_url = url.split("?").first  # remove URL query params
    extension = stripped_url.split(".").last

    extension = nil unless /^[a-zA-Z0-9]{3}$/.match?(extension)  # extension must be a 3-character alphanumeric string
    extension = ".#{extension}" unless extension.nil?
    extension
  end

  # Get an image from a URL and save to a temp folder set in the configuration under
  # temp_storage_location
  def self.retrieve_media(url)
    @@forki_logger.debug("Forki download started: #{url}")
    start_time = Time.now

    response = Typhoeus.get(url)

    extension = Forki.extract_file_extension_from_url(url)
    temp_file = "#{Forki.temp_storage_location}/facebook_media_#{SecureRandom.uuid}#{extension}"

    # We do this in case the folder isn't created yet, since it's a temp folder we'll just do so
    create_temp_storage_location
    File.binwrite(temp_file, response.body)

    @@forki_logger.debug("Forki download finished")
    @@forki_logger.debug("Save Location: #{temp_file}")
    @@forki_logger.debug("Size: #{(File.size("./#{temp_file}").to_f / 1024 / 1024).round(4)} MB")
    @@forki_logger.debug("Time to Download: #{(Time.now - start_time).round(3)} seconds")
    temp_file
  end

  def self.create_temp_storage_location
    return if File.exist?(Forki.temp_storage_location) && File.directory?(Forki.temp_storage_location)

    FileUtils.mkdir_p Forki.temp_storage_location
  end

  def self.set_logger_level
    if ENV["RAILS_ENV"] == "test" || ENV["RAILS_ENV"] == "development"
      @@forki_logger.level = Logger::INFO
    else
      @@forki_logger.level = Logger::WARN
    end
  end
end
