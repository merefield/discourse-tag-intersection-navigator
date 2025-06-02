
# frozen_string_literal: true
# name: discourse-tag-intersection-navigator
# about: Adds PMs to the tag topic list
# version: 0.0.1
# authors: merefield@gmail.com
# url: https://github.com/merefield/discourse-tag-intersection-navigator

enabled_site_setting :discourse_tag_intersection_navigator_enabled

# register_asset 'stylesheets/common/tag-topic-list-common.scss'

module ::DiscourseTagIntersectionNavigator
  PLUGIN_NAME = "discourse-tag-intersection-navigator".freeze
end

require_relative "lib/discourse_tag_intersection_navigator/engine"

after_initialize do
  reloadable_patch do
    TagsController.prepend(DiscourseTagIntersectionNavigator::TagsControllerExtension)
  end
end
