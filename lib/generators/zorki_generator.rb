class ZorkiGenerator < Rails::Generators::Base
  source_root(File.expand_path(File.dirname(__FILE__)))
  def copy_initializer
    copy_file 'zorki.rb', 'config/initializers/zorki.rb'
  end
end
