import { action, set } from "@ember/object";
import { addDiscoveryQueryParam } from "discourse/controllers/discovery/list";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { makeArray } from "discourse/lib/helpers";
import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseURL from "discourse/lib/url";
import { escapeExpression, setDefaultHomepage } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import PermissionType from "discourse/models/permission-type";
import {
  filterQueryParams,
  findTopicList,
} from "discourse/routes/build-topic-route";

const intersectionRoute = "tags/intersection/everything/everything";
const NONE = "none";
const ALL = "all";

export default {
  name: "tag-intersection-navigator",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const isMobile = container.lookup("service:site").mobileView;

    withPluginApi("1.39.0", (api) => {
      api.modifyClass(
        "component:tags-intersection-chooser",
        (Superclass) =>
          class extends Superclass {
            didReceiveAttrs() {
              super.didReceiveAttrs(...arguments);

              if (
                this.mainTag ===
                siteSettings.discourse_tag_intersection_navigator_all_word
              ) {
                this.mainTag = null;
              }

              this.additionalTags = this.additionalTags?.filter(
                (tag) =>
                  tag !==
                  siteSettings.discourse_tag_intersection_navigator_all_word
              );

              this.set(
                "value",
                makeArray(this.mainTag).concat(makeArray(this.additionalTags))
              );
            }

            @action
            onChange(tags) {
              if (tags.length < 1) {
                tags.push(
                  siteSettings.discourse_tag_intersection_navigator_all_word
                );
                tags.push(
                  siteSettings.discourse_tag_intersection_navigator_all_word
                );
              }
              if (tags.length < 2) {
                tags.push(
                  siteSettings.discourse_tag_intersection_navigator_all_word
                );
              }
              DiscourseURL.routeTo(`/tags/intersection/${tags.join("/")}`);
            }
          }
      );

      api.modifyClass(
        "service:composer",
        (Superclass) =>
          class extends Superclass {
            // Given a potential instance and options, set the model for this composer.
            async _setModel(optionalComposerModel, opts) {
              await super._setModel(optionalComposerModel, opts);
              //remove the "all_word" as a tag from the composer because it is not a real tag
              set(
                this.model,
                "tags",
                this.model.tags.filter(
                  (tag) =>
                    tag !==
                    siteSettings.discourse_tag_intersection_navigator_all_word
                )
              );
            }
          }
      );

      addDiscoveryQueryParam("int_filter", {
        replace: true,
        refreshModel: true,
        default: null,
        as: "int_filter",
      });

      api.modifyClass(
        "component:category-drop",
        (Superclass) =>
          class extends Superclass {
            @action
            onChange(categoryId) {
              if (this.tagId === siteSettings.discourse_tag_intersection_navigator_all_word) {
                this.tagId = null;
              }
              super.onChange(categoryId);
            }
          }
      )

      api.modifyClass(
        "route:tag-show",
        (Superclass) =>
          class extends Superclass {
            async model(params, transition) {
              const tagIdFromParams = escapeExpression(params.tag_id);
              let tag;
              if (tagIdFromParams !== NONE) {
                tag = this.store.createRecord("tag", {
                  id: tagIdFromParams,
                });
              } else {
                tag = this.store.createRecord("tag", {
                  id: NONE,
                });
              }

              if (tag.id !== tagIdFromParams) {
                tag.set("id", tagIdFromParams);
              }

              let additionalTags;

              if (params.additional_tags) {
                additionalTags = params.additional_tags.split("/").map((t) => {
                  return this.store.createRecord("tag", {
                    id: escapeExpression(t),
                  }).id;
                });
              }

              const filterType = filterTypeForMode(this.navMode);

              let tagNotification;
              if (
                tag &&
                tag.id !== NONE &&
                this.currentUser &&
                !additionalTags
              ) {
                // If logged in, we should get the tag's user settings
                tagNotification = await this.store.find(
                  "tagNotification",
                  tag.id.toLowerCase()
                );
              }

              let category = params.category_slug_path_with_id
                ? Category.findBySlugPathWithID(
                    params.category_slug_path_with_id
                  )
                : null;
              const filteredQueryParams = filterQueryParams(
                transition.to.queryParams,
                {}
              );
              const topicFilter = this.navMode;
              const tagId = tag ? tag.id.toLowerCase() : NONE;
              let filter;

              if (category) {
                category.setupGroupsAndPermissions();
                filter = `tags/c/${Category.slugFor(category)}/${category.id}`;

                if (this.noSubcategories !== undefined) {
                  filter += this.noSubcategories ? `/${NONE}` : `/${ALL}`;
                }

                filter += `/${tagId}/l/${topicFilter}`;
              } else if (additionalTags) {
                filter = `tags/intersection/${tagId}/${additionalTags.join(
                  "/"
                )}`;

                if (transition.to.queryParams["category"]) {
                  filteredQueryParams["category"] =
                    transition.to.queryParams["category"];
                  category = Category.findBySlugPathWithID(
                    transition.to.queryParams["category"]
                  );
                }
              } else {
                filter = `tag/${tagId}/l/${topicFilter}`;
              }

              if (
                this.noSubcategories === undefined &&
                category?.default_list_filter === "none" &&
                topicFilter === "latest"
              ) {
                // TODO: avoid throwing away preload data by redirecting on the server
                PreloadStore.getAndRemove("topic_list");
                return this.router.replaceWith(
                  "tags.showCategoryNone",
                  params.category_slug_path_with_id,
                  tagId
                );
              }

              const list = await findTopicList(
                this.store,
                this.topicTrackingState,
                filter,
                filteredQueryParams,
                {
                  cached: this.historyStore.isPoppedState,
                }
              );

              if (list.topic_list.tags && list.topic_list.tags.length === 1) {
                // Update name of tag (case might be different)
                tag.setProperties({
                  id: list.topic_list.tags[0].name,
                  staff: list.topic_list.tags[0].staff,
                });
              }

              return {
                tag,
                category,
                list,
                additionalTags,
                filterType,
                tagNotification,
                canCreateTopic: list.can_create_topic,
                canCreateTopicOnCategory:
                  category?.permission === PermissionType.FULL,
                canCreateTopicOnTag: !tag.staff || this.currentUser?.staff,
                noSubcategories: this.noSubcategories,
              };
            }
          }
      );

      api.modifyClass(
        "route:tags-intersection",
        (Superclass) =>
          class extends Superclass {
            get navMode() {
              return (
                this.controllerFor("discovery/list").int_filter || "latest"
              );
            }
          }
      );

      if (
        !isMobile && siteSettings.discourse_tag_intersection_navigator_make_intersection_homepage
      ) {
        setDefaultHomepage(intersectionRoute);
      }
    });
  },
};
