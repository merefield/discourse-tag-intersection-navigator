# frozen_string_literal: true

require_relative '../plugin_helper'

RSpec.describe "Tag Intersection Navigator" do
  let(:discovery) { PageObjects::Pages::Discovery.new }
  let(:intersection_chooser) { PageObjects::Components::SelectKit.new(".tags-intersection-chooser") }
  fab!(:user)
  fab!(:tag_1) { Fabricate(:tag, name: "test-tag1") }
  fab!(:tag_2) { Fabricate(:tag,  name: "test-tag2") }
  fab!(:tag_3) { Fabricate(:tag, name: "test-tag3") }
  fab!(:category)
  fab!(:topic)
  fab!(:topic_1) { Fabricate(:topic, tags: [tag_1]) }
  fab!(:topic_2) { Fabricate(:topic, tags: [tag_1, tag_2], category: category) }
  fab!(:topic_3) { Fabricate(:topic, tags: [tag_1, tag_2, tag_3]) }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.discourse_tag_intersection_navigator_enabled = true
    SiteSetting.discourse_tag_intersection_navigator_all_word = "bananas"
  end

  def publish_new_topic(tags:, category: nil)
    new_topic = Fabricate(:topic, tags: tags, category: category)
    Fabricate(:post, topic: new_topic)
    TopicTrackingState.publish_new(new_topic)
    new_topic
  end

  describe "topic list results" do
    it "keeps all_word/all_word on the intersection route as an empty selection" do
      visit("/tags/intersection/bananas/bananas")

      expect(page).to have_current_path("/tags/intersection/bananas/bananas")
      expect(intersection_chooser).to be_visible
      expect(discovery.topic_list).to have_topics(count: 4)
    end

    it "filters topics by tags as expected" do
      visit("/tags/intersection/bananas/bananas")
      expect(page).to have_css(".tags-intersection-chooser")
      expect(page).to have_current_path("/tags/intersection/bananas/bananas")
      expect(discovery.topic_list).to have_topic(topic)
      expect(discovery.topic_list).to have_topic(topic_1)
      expect(discovery.topic_list).to have_topic(topic_2)
      expect(discovery.topic_list).to have_topic(topic_3)
      expect(discovery.topic_list).to have_topics(count: 4)
      visit("/tags/intersection/test-tag1/bananas")
      expect(page).to have_current_path("/tags/intersection/test-tag1/bananas")
      expect(discovery.topic_list).to have_topic(topic_1)
      expect(discovery.topic_list).to have_topic(topic_2)
      expect(discovery.topic_list).to have_topic(topic_3)
      expect(discovery.topic_list).to have_topics(count: 3)
      visit("/tags/intersection/test-tag1/test-tag2")
      expect(page).to have_current_path("/tags/intersection/test-tag1/test-tag2")
      expect(discovery.topic_list).to have_topic(topic_2)
      expect(discovery.topic_list).to have_topic(topic_3)
      expect(discovery.topic_list).to have_topics(count: 2)
    end
    it "filters topics by tags and category as expected" do
      visit("/tags/intersection/bananas/bananas?category=#{category.id}")
      expect(page).to have_css(".tags-intersection-chooser")
      visit("/tags/intersection/test-tag1/test-tag2?category=#{category.id}")
      expect(page).to have_current_path("/tags/intersection/test-tag1/test-tag2?category=#{category.id}")
      expect(discovery.topic_list).to have_topic(topic_2)
      expect(discovery.topic_list).to have_topics(count: 1)
    end

    it "switches filters using int_filter query param from the nav tabs" do
      visit("/tags/intersection/test-tag1/test-tag2")

      click_button("Top")
      expect(page).to have_current_path("/tags/intersection/test-tag1/test-tag2?int_filter=top")

      click_button("Latest")
      expect(page).to have_current_path("/tags/intersection/test-tag1/test-tag2?int_filter=latest")
    end

    it "allows moving between two, one, and zero tags using the chooser" do
      visit("/tags/intersection/test-tag1/test-tag2")
      expand_chooser = -> { intersection_chooser.expand if intersection_chooser.is_collapsed? }

      expand_chooser.call
      intersection_chooser.unselect_by_name("test-tag2")
      expect(page).to have_current_path("/tags/intersection/test-tag1/bananas")
      expect(discovery.topic_list).to have_topics(count: 3)

      expand_chooser.call
      intersection_chooser.unselect_by_name("test-tag1")
      expect(page).to have_current_path("/tags/intersection/bananas/bananas")
      expect(discovery.topic_list).to have_topics(count: 4)

      expand_chooser.call
      intersection_chooser.select_row_by_name("test-tag1")
      expect(page).to have_current_path("/tags/intersection/test-tag1/bananas")
      expect(discovery.topic_list).to have_topics(count: 3)

      expand_chooser.call
      intersection_chooser.select_row_by_name("test-tag2")
      expect(page).to have_current_path("/tags/intersection/test-tag1/test-tag2")
      expect(discovery.topic_list).to have_topics(count: 2)
    end

    it "preserves int_filter while changing tags in the chooser" do
      visit("/tags/intersection/test-tag1/test-tag2?int_filter=top")
      expand_chooser = -> { intersection_chooser.expand if intersection_chooser.is_collapsed? }

      expand_chooser.call
      intersection_chooser.unselect_by_name("test-tag2")
      expect(page).to have_current_path("/tags/intersection/test-tag1/bananas?int_filter=top")

      expand_chooser.call
      intersection_chooser.select_row_by_name("test-tag2")
      expect(page).to have_current_path("/tags/intersection/test-tag1/test-tag2?int_filter=top")
    end

    it "shows incoming count only for topics in the current intersection scope" do
      sign_in(user)
      visit("/tags/intersection/test-tag1/test-tag2?category=#{category.id}")

      expect(discovery.topic_list).to have_topics(count: 1)

      out_of_scope_tag_topic = publish_new_topic(tags: [tag_1], category: category)
      out_of_scope_category_topic = publish_new_topic(tags: [tag_1, tag_2])
      in_scope_topic = publish_new_topic(tags: [tag_1, tag_2], category: category)

      try_until_success(reason: "relies on MessageBus updates") do
        expect(page).to have_css(".show-more", text: /1.*new/)
      end

      find(".show-more").click

      expect(discovery.topic_list).to have_topic(in_scope_topic)
      expect(discovery.topic_list).to have_no_topic(out_of_scope_tag_topic)
      expect(discovery.topic_list).to have_no_topic(out_of_scope_category_topic)
    end
  end
end
