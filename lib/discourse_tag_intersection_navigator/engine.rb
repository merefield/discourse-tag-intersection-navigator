# frozen_string_literal: true

module ::DiscourseTagIntersectionNavigator
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseTagIntersectionNavigator
    config.autoload_paths << File.join(config.root, "lib")
  end
end
