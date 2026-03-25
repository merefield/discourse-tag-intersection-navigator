# frozen_string_literal: true

module PageObjects
  module Components
    class IntersectionsNavBar < PageObjects::Components::Base
      SELECTOR = ".category-breadcrumb .nav.nav-pills"

      def visible?
        has_css?(SELECTOR)
      end

      def has_filter?(name)
        has_css?("#{SELECTOR} .filter-item button", text: name)
      end

      def has_active_filter?(name)
        has_css?("#{SELECTOR} .filter-item button.active", text: name)
      end

      def click_filter(name)
        find("#{SELECTOR} .filter-item button", text: name).click
        self
      end
    end
  end
end
