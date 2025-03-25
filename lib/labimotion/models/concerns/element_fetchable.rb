# frozen_string_literal: true

module Labimotion
  module ElementFetchable
    extend ActiveSupport::Concern

    class_methods do
      def element_klass
        Labimotion::ElementKlass.find_by(name: element_klass_name)
      end

      def fetch_for_user(user_id, name: nil, short_label: nil, limit: 20)
        # Prevent abuse by capping and validating limit
        limit = [limit.to_i, 100].min
        limit = 20 if limit <= 0

        # Build base scope with common filters
        apply_filters = lambda do |scope|
          scope = scope.where("#{table_name}.name ILIKE ?", "%#{sanitize_sql_like(name)}%") if name.present?
          scope = scope.where("#{table_name}.short_label ILIKE ?", "%#{sanitize_sql_like(short_label)}%") if short_label.present? && column_names.include?('short_label')
          scope
        end

        # Owned records
        owned = apply_filters.call(
          joins(collections: :user).where(collections: { user_id: user_id })
        )

        # Shared (synced) records
        shared = apply_filters.call(
          joins(collections: :sync_collections_users).where(sync_collections_users: { user_id: user_id })
        )

        # Combine (remove duplicates), order, and limit
        order_column = column_names.include?('short_label') ? :short_label : :name
        from("(#{owned.to_sql} UNION #{shared.to_sql}) AS #{table_name}")
          .order(order_column => :desc)
          .limit(limit)
      end

      private

      def element_klass_name
        raise NotImplementedError, "Subclass must define element_klass_name"
      end
    end

    # Instance method to get element_klass for a record
    def element_klass
      self.class.element_klass
    end
  end
end
