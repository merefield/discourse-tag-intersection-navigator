import { action, set } from "@ember/object";
import { service } from "@ember/service";
import { addDiscoveryQueryParam } from "discourse/controllers/discovery/list";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import getURL from "discourse/lib/get-url";
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
import I18n from "discourse-i18n";

const NONE = "none";
const ALL = "all";
const NO_CATEGORIES_ID = "no-categories";
const ALL_CATEGORIES_ID = "all-categories";

export default {
  name: "tag-intersection-navigator",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const isMobile = container.lookup("service:site").mobileView;
    const allWord = siteSettings.discourse_tag_intersection_navigator_all_word;
    const intersectionRoute = `tags/intersection/${allWord}/${allWord}`;

    withPluginApi("1.39.0", (api) => {
      api.modifyClass(
        "component:tags-intersection-chooser",
        (Superclass) =>
          class extends Superclass {
            @service router;

            getTagIntersectionUrl(category, tag_1, tag_2, filter) {
              let url = `/tags/intersection/${tag_1}/${tag_2}`;
              let params = [];

              if (filter) {
                params.push(`int_filter=${filter}`);
              }
              if (category) {
                params.push(`category=${category}`);
              }
              if (params.length > 0) {
                url = url + "?" + params.join("&");
              }
              return getURL(url || "/");
            }

            didReceiveAttrs() {
              super.didReceiveAttrs(...arguments);

              if (this.mainTag === allWord) {
                this.mainTag = null;
              }

              this.additionalTags = this.additionalTags?.filter(
                (tag) => tag !== allWord
              );

              this.set(
                "value",
                makeArray(this.mainTag).concat(makeArray(this.additionalTags))
              );
            }

            @action
            onChange(tags) {
              if (tags.length < 1) {
                tags.push(allWord);
                tags.push(allWord);
              }
              if (tags.length < 2) {
                tags.push(allWord);
              }

              let route = this.getTagIntersectionUrl(
                this.router.currentRoute.queryParams.category,
                tags[0],
                tags.slice(1),
                this.navMode
              );
              DiscourseURL.routeToUrl(route);
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
              //remove the "all word" as a tag from the composer because it is not a real tag
              set(
                this.model,
                "tags",
                this.model.tags.filter((tag) => tag !== allWord)
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
            @service router;

            getAdditionalTags = () => {
              // Get the additional tags from the URL
              const additionalTags =
                this.router.currentRoute.params.additional_tags;
              if (additionalTags) {
                return additionalTags.split("/").map((t) => t);
              }
              return [];
            };
            getTagIntersectionUrl(category, tag_1, tag_2, filter) {
              let url = `/tags/intersection/${tag_1}/${tag_2}`;
              let params = [];

              if (filter) {
                params.push(`int_filter=${filter}`);
              }
              if (category) {
                params.push(`category=${category}`);
              }
              if (params.length > 0) {
                url = url + "?" + params.join("&");
              }
              return getURL(url || "/");
            }

            @action
            onChange(categoryId) {
              const category =
                categoryId === ALL_CATEGORIES_ID ||
                categoryId === NO_CATEGORIES_ID
                  ? this.selectKit.options.parentCategory
                  : Category.findById(parseInt(categoryId, 10));

              if (this.router.currentRouteName === "tags.intersection") {
                let route = this.getTagIntersectionUrl(
                  category.slug,
                  this.tagId,
                  this.router.currentRoute.params.additional_tags,
                  this.navMode
                );
                DiscourseURL.routeToUrl(route);
                this.router.refresh();
              } else {
                super.onChange(categoryId);
              }
            }
          }
      );

      api.modifyClass(
        "route:tag.show",
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
        "route:tags.intersection",
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
        !isMobile &&
        siteSettings.discourse_tag_intersection_navigator_make_intersection_homepage
      ) {
        setDefaultHomepage(intersectionRoute);
      }

      if (
        !isMobile &&
        siteSettings.discourse_tag_intersection_navigator_add_community_link
      ) {
        api.addCommunitySectionLink((baseSectionLink) => {
          return class CustomSectionLink extends baseSectionLink {
            get name() {
              return "tag-intersection-navigator";
            }

            get route() {
              return "tags.intersection";
            }

            get models() {
              return [allWord, allWord];
            }

            get title() {
              return I18n.t("tag_intersection_navigator.link.title");
            }

            get text() {
              return I18n.t("tag_intersection_navigator.link.text");
            }
          };
        });
      }
    });
  },
};
