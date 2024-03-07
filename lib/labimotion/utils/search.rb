# frozen_string_literal: true

module Labimotion
  class Search

    def self.unique_element_layers(id)
      Labimotion::ElementKlass.where(id: id).select("jsonb_object_keys((properties_release->>'layers')::jsonb) as keys").map(&:keys).uniq
    end

    def self.unique_segment_layers(id)
      Labimotion::SegmentKlass.where(id: id).select("jsonb_object_keys((properties_release->>'layers')::jsonb) as keys").map(&:keys).uniq
    end

    def self.elements_search(params, current_user, c_id, dl)
      collection = Collection.belongs_to_or_shared_by(current_user.id, current_user.group_ids).find(c_id)
      element_scope = Labimotion::Element.joins(:collections_elements).where('collections_elements.collection_id = ?', collection.id).joins(:element_klass).where('element_klasses.id = elements.element_klass_id AND element_klasses.name = ?', params[:selection][:genericElName])
      element_scope = element_scope.where('elements.name like (?)', "%#{params[:selection][:searchName]}%") if params[:selection][:searchName].present?
      element_scope = element_scope.where('elements.short_label like (?)', "%#{params[:selection][:searchShowLabel]}%") if params[:selection][:searchShowLabel].present?
      if params[:selection][:searchProperties].present?
        unique_layers = Labimotion::Search.unique_element_layers(params[:selection] && params[:selection][:genericKlassId])
        params[:selection][:searchProperties] && params[:selection][:searchProperties][:layers] && params[:selection][:searchProperties][:layers].keys.each do |lk|
          layer = params[:selection][:searchProperties][:layers][lk]
          reg_layer = /^#{lk}$|(^#{lk}\.)/
          uni_keys = unique_layers.select { |uni_key| uni_key.match(reg_layer) }
          qs = layer[:fields].select { |f| f[:value].present? || f[:type] == 'input-group' }
          qs.each do |f|
            query_field = {}
            if f[:type] == 'input-group'
              sfs = f[:sub_fields].map { |e| { "id": e[:id], "value": e[:value] } }
              query_field = { "fields": [{ "field": f[:field].to_s, "sub_fields": sfs }] } unless sfs.empty?
            elsif %w[checkbox integer system-defined].include? f[:type]
              query_field = { "fields": [{ "field": f[:field].to_s, "value": f[:value] }] }
            elsif Labimotion::FieldType::DRAG_ALL.include? f[:type]
              vfs = { "el_label": f[:value] }
              query_field = { "fields": [{ "field": f[:field].to_s, "value": vfs }] } unless f[:value].empty?
            else
              query_field = { "fields": [{ "field": f[:field].to_s, "value": f[:value].to_s }] }
            end
            next unless query_field.present?

            sqls = []
            uni_keys.select { |uni_key| uni_key.match(reg_layer) }.each do |e|
              sql = ActiveRecord::Base.send(:sanitize_sql_array, ["(properties->'layers' @> ?)", { "#{e}": query_field }.to_json])
              sqls = sqls.push(sql)
            end
            element_scope = element_scope.where(sqls.join(' OR '))
          end
        end
      end
      element_scope
    end

    def self.segments_search(ids, type)
      eids = ids
      seg_scope = Labimotion::Segment.where(element_type: type, element_id: ids)
      if params[:selection][:segSearchProperties].present? && params[:selection][:segSearchProperties].length > 0
        params[:selection][:segSearchProperties].each do |segmentSearch|
          has_params = false
          next unless segmentSearch[:id].present? && segmentSearch[:searchProperties].present? && segmentSearch[:searchProperties][:layers].present?
          unique_layers = Labimotion::Search.unique_segment_layers(segmentSearch[:id])
          segmentSearch[:searchProperties] && segmentSearch[:searchProperties][:layers] && segmentSearch[:searchProperties][:layers].keys.each do |lk|
            layer = segmentSearch[:searchProperties][:layers][lk]
            reg_layer = /^#{lk}$|(^#{lk}\.)/
            uni_keys = unique_layers.select { |uni_key| uni_key.match(reg_layer) }
            qs = layer[:fields].select { |f| f[:value].present? || f[:type] == 'input-group' }
            qs.each do |f|
              query_field = {}
              if f[:type] == 'input-group'
                sfs = f[:sub_fields].map { |e| { "id": e[:id], "value": e[:value] } }
                query_field = { "fields": [{ "field": f[:field].to_s, "sub_fields": sfs }] } unless sfs.empty?
              elsif %w[checkbox integer system-defined].include? f[:type]
                query_field = { "fields": [{ "field": f[:field].to_s, "value": f[:value] }] }
              elsif Labimotion::FieldType::DRAG_ALL.include? f[:type]
                vfs = { "el_label": f[:value] }
                query_field = { "fields": [{ "field": f[:field].to_s, "value": vfs }] } unless f[:value].empty?
              else
                query_field = { "fields": [{ "field": f[:field].to_s, "value": f[:value].to_s }] }
              end
              next unless query_field.present?

              has_params = true

              sqls = []
              uni_keys.select { |uni_key| uni_key.match(reg_layer) }.each do |e|
                sql = ActiveRecord::Base.send(:sanitize_sql_array, ["(properties->'layers' @> ?)", { "#{e}": query_field }.to_json])
                sqls = sqls.push(sql)
              end
              seg_scope = seg_scope.where(sqls.join(' OR '))
            end
          end
          eids = (seg_scope.pluck(:element_id)) & eids if has_params == true
        end
      end
      type.classify.constantize.where(id: eids)
    end

    def self.samples_search(c_id = @c_id)
      sqls = []
      sps = params[:selection][:searchProperties]
      collection = Collection.belongs_to_or_shared_by(current_user.id, current_user.group_ids).find(c_id)
      element_scope = Sample.joins(:collections_samples).where('collections_samples.collection_id = ?', collection.id)
      return element_scope if sps.empty?

      sps[:propCk].keys.each { |k| sqls.push(ActiveRecord::Base.send(:sanitize_sql_array, ["#{k} = (?)", sps[:propCk][k]])) if Sample.column_names.include?(k) } if sps[:propCk].present?
      sps[:stereo].keys.each { |k| sqls.push(ActiveRecord::Base.send(:sanitize_sql_array, ['(stereo->> ? = ?)', k, sps[:stereo][k]])) } if sps[:stereo].present?
      sps[:propTx].keys.each { |k| sqls = sqls.push(ActiveRecord::Base.send(:sanitize_sql, "#{k} like ('%#{sps[:propTx][k]}%')")) if Sample.column_names.include?(k) } if sps[:propTx].present?
      element_scope = element_scope.where(sqls.join(' AND '))
      element_scope
    end

  end
end
