import { action, set } from "@ember/object";
import { service } from "@ember/service";
import { addDiscoveryQueryParam } from "discourse/controllers/discovery/list";
import getURL from "discourse/lib/get-url";
import { makeArray } from "discourse/lib/helpers";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
import { setDefaultHomepage } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

const NO_CATEGORIES_ID = "no-categories";
const ALL_CATEGORIES_ID = "all-categories";

export default {
  name: "tag-intersection-navigator",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const allWord = siteSettings.discourse_tag_intersection_navigator_all_word;
    const intersectionRoute = `tags/intersection/${allWord}/${allWord}`;

    withPluginApi((api) => {
      api.modifyClass(
        "component:tags-intersection-chooser",
        (Superclass) =>
          class extends Superclass {
            @service router;

            getTagIntersectionUrl(category, tag_1, tag_2, filter) {
              const additionalTagPath = Array.isArray(tag_2)
                ? tag_2.join("/")
                : String(tag_2 || "");
              let url = `/tags/intersection/${tag_1}/${additionalTagPath}`;
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

              const mainTagName = this.mainTag?.name || this.mainTag;
              const additionalTagNames = makeArray(this.additionalTags)
                .map((tag) => tag?.name || tag)
                .filter((tag) => tag !== allWord);
              const visibleMainTag = mainTagName === allWord ? null : mainTagName;

              this.set("value", makeArray(visibleMainTag).concat(additionalTagNames));
            }

            @action
            onChange(tags) {
              const tagNames = tags.map((tag) => tag?.name || tag).filter(Boolean);
              const normalized = [...tagNames];
              const filter =
                this.router.currentRoute.queryParams?.int_filter || this.navMode;

              while (normalized.length < 2) {
                normalized.push(allWord);
              }

              let route = this.getTagIntersectionUrl(
                this.router.currentRoute.queryParams.category,
                normalized[0],
                normalized.slice(1),
                filter
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
                (this.model.tags || [])
                  .map((tag) => tag?.name || tag)
                  .filter((tag) => tag !== allWord)
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
                const mainTagName = this.tag?.name || this.tag || allWord;
                const additionalTagPath =
                  this.router.currentRoute.params.additional_tags || allWord;
                const filter =
                  this.router.currentRoute.queryParams?.int_filter || this.navMode;

                let route = this.getTagIntersectionUrl(
                  category?.slug,
                  mainTagName,
                  additionalTagPath,
                  filter
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

      if (siteSettings.discourse_tag_intersection_navigator_make_intersection_homepage) {
        setDefaultHomepage(intersectionRoute);
      }

      if (siteSettings.discourse_tag_intersection_navigator_add_community_link) {
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
              return i18n("tag_intersection_navigator.link.title");
            }

            get text() {
              return i18n("tag_intersection_navigator.link.text");
            }
          };
        });
      }
    });
  },
};
