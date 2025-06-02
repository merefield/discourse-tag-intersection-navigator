# frozen_string_literal: true
module DiscourseTagIntersectionNavigator
  module TagsControllerExtension
    def show
      filter = params[:int_filter].presence&.to_sym

      if filter && Discourse.filters.include?(filter) && respond_to?("show_#{filter}", true)
        send("show_#{filter}")
      else
        show_latest
      end
    end

    Discourse.filters.each do |filter|
      define_method("show_#{filter}") do
        unless params[:tag_id] == SiteSetting.discourse_tag_intersection_navigator_all_word && params[:additional_tag_ids] == SiteSetting.discourse_tag_intersection_navigator_all_word
          @tag_id = params[:tag_id].force_encoding("UTF-8")
          @additional_tags =
            params[:additional_tag_ids].to_s.split("/").map { |t| t.force_encoding("UTF-8") }
        end

        list_opts = build_topic_list_options
        @list = nil

        if filter == :top
          period = params[:period] || SiteSetting.top_page_default_timeframe.to_sym
          TopTopic.validate_period(period)

          @list = TopicQuery.new(current_user, list_opts).public_send("list_top_for", period)
          @list.for_period = period
        else
          @list = TopicQuery.new(current_user, list_opts).public_send("list_#{filter}")
        end

        @list.more_topics_url = construct_url_with(:next, list_opts)
        @list.prev_topics_url = construct_url_with(:prev, list_opts)
        @rss = "tag"
        @description_meta = I18n.t("rss_by_tag", tag: tag_params.join(" & "))
        @title = @description_meta

        canonical_params = params.slice(:category_slug_path_with_id, :tag_id)
        canonical_method = url_method(canonical_params)
        canonical_url "#{Discourse.base_url_no_prefix}#{public_send(canonical_method, *(canonical_params.values.map { |t| t.force_encoding("UTF-8") }))}"

        respond_with_list(@list)
      end
    end

    def build_topic_list_options
      options =
        super.merge(
          page: params[:page],
          topic_ids: param_to_integer_list(:topic_ids),
          category: @filter_on_category ? @filter_on_category.id : params[:category],
          order: params[:order],
          ascending: params[:ascending],
          min_posts: params[:min_posts],
          max_posts: params[:max_posts],
          status: params[:status],
          filter: params[:filter],
          state: params[:state],
          search: params[:search],
          q: params[:q],
        )
      options[:no_subcategories] = true if params[:no_subcategories] == true ||
        params[:no_subcategories] == "true"
      options[:per_page] = params[:per_page].to_i.clamp(1, 30) if params[:per_page].present?

      if params[:tag_id] == "none" || (params[:tag_id] == SiteSetting.discourse_tag_intersection_navigator_all_word && params[:additional_tag_ids] == SiteSetting.discourse_tag_intersection_navigator_all_word)
        options.delete(:tags)
        options[:no_tags] = true
      else
        options[:tags] = tag_params.filter { |t| t != SiteSetting.discourse_tag_intersection_navigator_all_word }
        options[:match_all_tags] ||= true
      end
      options
    end
  end
end
