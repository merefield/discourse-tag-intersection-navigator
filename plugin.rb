
# frozen_string_literal: true
# name: discourse-tag-intersection-navigator
# about: Improves the Tag Intersections experience allow you to specify no, one or many tags to filter by
# version: 0.2.0
# authors: merefield@gmail.com
# url: https://github.com/merefield/discourse-tag-intersection-navigator

enabled_site_setting :discourse_tag_intersection_navigator_enabled

module ::DiscourseTagIntersectionNavigator
  PLUGIN_NAME = "discourse-tag-intersection-navigator".freeze
end

register_asset 'stylesheets/common/tags-int-common.scss'

require_relative "lib/discourse_tag_intersection_navigator/engine"

after_initialize do
  reloadable_patch do
    TagsController.prepend(DiscourseTagIntersectionNavigator::TagsControllerExtension)
  end
end
