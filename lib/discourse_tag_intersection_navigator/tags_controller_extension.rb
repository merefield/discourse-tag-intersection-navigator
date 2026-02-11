# frozen_string_literal: true
module DiscourseTagIntersectionNavigator
  module TagsControllerExtension
    ALL_PLACEHOLDER = "__discourse_tag_intersection_navigator_all__".freeze

    def show
      all_word = SiteSetting.discourse_tag_intersection_navigator_all_word

      # Preserve plugin semantics for "no tags selected" (/tags/intersection/all/all)
      # while avoiding core duplicate-tag intersection normalization.
      if params[:tag_name] == all_word && params[:additional_tag_names] == all_word
        params[:additional_tag_names] = ALL_PLACEHOLDER
      end

      filter = params[:int_filter].presence&.to_sym

      if filter && Discourse.filters.include?(filter) && respond_to?("show_#{filter}", true)
        send("show_#{filter}")
      else
        show_latest
      end
    end

    def build_topic_list_options
      options = super

      tag_name_param = @tag_name || params[:tag_name]
      if tag_name_param == "none"
        options.delete(:tags)
        options[:no_tags] = true
      else
        options[:tags] =
          tag_params.filter do |t|
            t != SiteSetting.discourse_tag_intersection_navigator_all_word && t != ALL_PLACEHOLDER
          end
        options[:match_all_tags] ||= true
      end
      options
    end
  end
end
