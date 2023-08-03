class VideoSieve
  def self.can_process_with_sieve?(graphql_objects)
    !sieve_class_for_graphql_objects(graphql_objects).nil?
  end

  def self.sieve_for_graphql_objects(graphql_objects)

    sieve = sieve_class_for_graphql_objects(graphql_objects)
    return nil if sieve.nil?

    sieve.sieve(graphql_objects)
  end

private

  def self.sieve_class_for_graphql_objects(graphql_objects)
    sieves = [VideoSieveWatchTab, VideoSieveVideoPage, VideoSieveReel]
    sieves.detect { |sieve| sieve.check(graphql_objects) }
  end
end

Dir[File.join(__dir__, '*.rb')].each do |file|
  require file unless file.end_with?("video_sieve.rb")
end
