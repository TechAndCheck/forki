# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "zorki"

require "minitest/autorun"

def cleanup_temp_folder
  # Delete the temp folder that'll be created here
  if File.exist?("tmp") && File.directory?("tmp")
    FileUtils.rm_r "tmp"
  end
end

require "minitest/assertions"
module Minitest::Assertions
  #  Fails unless +object+ is not nil.
  def assert_not_nil(object)
    assert object.nil? == false, "Expected a non-nil object but received nil"
  end
end
