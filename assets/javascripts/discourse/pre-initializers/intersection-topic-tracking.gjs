import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import TopicTrackingState from "discourse/models/topic-tracking-state";

export default {
  name: "intersection-topic-tracking",
  before: "inject-discourse-objects",

  initialize(container) {
    TopicTrackingState.reopen({
      filterTagIds: null,

      trackIncoming(filter, opts = {}) {
        this.set("filterTagIds", null);
        return this._super(filter, opts);
      },

      trackIncomingIntersection({ filter, category = null, tagIds = [] }) {
        this.trackIncoming(filter);
        this.setProperties({
          filterCategory: category,
          filterTagName: null,
          filterTagId: null,
          filterTagIds: tagIds,
        });
      },

      notifyIncoming(data) {
        if (!this.filterTagIds) {
          return this._super(data);
        }

        if (!this.newIncoming) {
          return;
        }

        const filter = this.filter;
        const filterCategory = this.filterCategory;
        const categoryId = data.payload?.category_id;

        if (filterCategory && filterCategory.get("id") !== categoryId) {
          const category = categoryId && Category.findById(categoryId);
          if (
            !category ||
            category.get("parentCategory.id") !== filterCategory.get("id")
          ) {
            return;
          }
        }

        const payloadTagIds =
          data.payload?.tags?.map((tag) => tag.id).filter(Boolean) || [];

        if (
          this.filterTagIds.length > 0 &&
          !this.filterTagIds.every((tagId) => payloadTagIds.includes(tagId))
        ) {
          return;
        }

        if (
          ["all", "latest", "new", "unseen"].includes(filter) &&
          data.message_type === "new_topic"
        ) {
          this._addIncoming(data.topic_id);
        }

        const unreadRecipients = ["all", "unread", "unseen"];
        if (this.currentUser?.new_new_view_enabled) {
          unreadRecipients.push("new");
        }

        if (
          unreadRecipients.includes(filter) &&
          data.message_type === "unread"
        ) {
          const old = this.findState(data);

          if (!old || old.highest_post_number === old.last_read_post_number) {
            this._addIncoming(data.topic_id);
          }
        }

        if (filter === "latest" && data.message_type === "latest") {
          this._addIncoming(data.topic_id);
        }

        this.incomingCount = this.newIncoming.length;
      },
    });

    withPluginApi((api) => {
      const router = container.lookup("service:router");

      api.onPageChange(() => {
        if (!router.currentRouteName?.startsWith("tags.intersection")) {
          return;
        }

        const tracking = container.lookup("service:topic-tracking-state");
        const attributes = router.currentRoute.attributes || {};
        const tagLookup = attributes.list?.topic_list?.tags || [];
        const tagIds = [
          attributes.tag?.id,
          ...(attributes.additionalTags || []).map(
            (tagName) =>
              tagLookup.find(
                (tag) => tag.name === tagName || tag.slug === tagName
              )?.id
          ),
        ].filter(Boolean);

        tracking.trackIncomingIntersection({
          filter: router.currentRoute.queryParams?.int_filter || "latest",
          category: attributes.category,
          tagIds,
        });
      });
    });
  },
};
