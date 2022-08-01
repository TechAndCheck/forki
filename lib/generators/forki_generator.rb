class ForkiGenerator < Rails::Generators::Base
  source_root(File.expand_path(File.dirname(__FILE__)))
  def copy_initializer
    copy_file "forki.rb", "config/initializers/forki.rb"
  end
end
