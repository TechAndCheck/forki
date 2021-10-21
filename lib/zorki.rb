# frozen_string_literal: true

require_relative "zorki/version"

# Representative objects we create
require_relative "zorki/user"
require_relative "zorki/post"
require_relative "zorki/poster"

require "helpers/configuration"
require_relative "zorki/scrapers/scraper"

module Zorki
  extend Configuration

  class Error < StandardError
    def initialize(msg = "Zorki encountered an error scraping Instagram")
      super
    end
  end

  define_setting :temp_storage_location, "tmp/zorki"

  # Get an image from a URL and save to a temp folder set in the configuration under
  # temp_storage_location
  def self.retrieve_media(url)
    response = Typhoeus.get(url)

    # Get the file extension if it's in the file
    extension = url.split(".").last

    # Do some basic checks so we just empty out if there's something weird in the file extension
    # that could do some harm.
    if extension.length > 0
      extension = nil unless /^[a-zA-Z0-9]+$/.match?(extension)
      extension = ".#{extension}" unless extension.nil?
    end

    temp_file_name = "#{Zorki.temp_storage_location}/#{SecureRandom.uuid}#{extension}"

    # We do this in case the folder isn't created yet, since it's a temp folder we'll just do so
    self.create_temp_storage_location
    File.binwrite(temp_file_name, response.body)
    temp_file_name
  end

private

  def self.create_temp_storage_location
    return if File.exist?(Zorki.temp_storage_location) && File.directory?(Zorki.temp_storage_location)
    FileUtils.mkdir_p Zorki.temp_storage_location
  end

end
