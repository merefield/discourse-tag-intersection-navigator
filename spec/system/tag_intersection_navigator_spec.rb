# frozen_string_literal: true

require_relative '../plugin_helper'

RSpec.describe "Tag Intersection Navigator" do
  let(:discovery) { PageObjects::Pages::Discovery.new }
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

  describe "topic list results" do
    it "filters topics by tags as expected" do
      visit("/tags/intersection/bananas/bananas")
      within("details.mini-tag-chooser span.formatted-selection") do
        expect(page).to have_text("optional tags")
      end
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
      visit("/tags/intersection/test-tag1/test-tag2?category=#{category.id}")
      expect(page).to have_current_path("/tags/intersection/test-tag1/test-tag2?category=#{category.id}")
      expect(discovery.topic_list).to have_topic(topic_2)
      expect(discovery.topic_list).to have_topics(count: 1)
    end
  end
end
