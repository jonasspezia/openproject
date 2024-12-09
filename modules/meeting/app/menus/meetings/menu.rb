# -- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
# ++
module Meetings
  class Menu < Submenu
    def initialize(params:, project: nil)
      super(view_type: nil, project:, params:)
    end

    def menu_items
      [
        OpenProject::Menu::MenuGroup.new(header: nil, children: top_level_menu_items),
        meeting_series_menu_group,
        OpenProject::Menu::MenuGroup.new(header: I18n.t(:label_involvement), children: involvement_sidebar_menu_items)
      ].compact
    end

    def top_level_menu_items
      all_filter = [{ invited_user_id: { operator: "*", values: [] } }].to_json
      my_meetings_href = polymorphic_path([project, :meetings])

      [
        menu_item(title: I18n.t(:label_my_meetings),
                  selected: params[:current_href] == my_meetings_href && params[:filters].blank?),
        recurring_menu_item,
        menu_item(title: I18n.t(:label_all_meetings),
                  query_params: { filters: all_filter })
      ].compact
    end

    def meeting_series_menu_group
      return unless OpenProject::FeatureDecisions.recurring_meetings_active?

      OpenProject::Menu::MenuGroup.new(header: I18n.t(:label_meeting_series), children: meeting_series_menu_items)
    end

    def meeting_series_menu_items
      series = RecurringMeeting
        .visible
        .reorder("LOWER(title)")

      if project
        series = series.where(project_id: project.id)
      end

      series.pluck(:id, :title)
            .map do |id, title|
        href = polymorphic_path([project, :recurring_meeting], { id: })
        OpenProject::Menu::MenuItem.new(title:,
                                        selected: params[:current_href] == href,
                                        href:)
      end
    end

    def recurring_menu_item
      return unless OpenProject::FeatureDecisions.recurring_meetings_active?

      recurring_filter = [{ type: { operator: "=", values: ["t"] } }].to_json

      menu_item(title: I18n.t("label_recurring_meeting_plural"),
                query_params: { filters: recurring_filter, sort: "start_time" })
    end

    def involvement_sidebar_menu_items
      invitation_filter = [{ invited_user_id: { operator: "=", values: [User.current.id.to_s] } }].to_json

      [
        menu_item(title: I18n.t(:label_invitations),
                  query_params: { filters: invitation_filter, sort: "start_time" }),
        menu_item(title: I18n.t(:label_attended),
                  query_params: { filters: attendee_filter }),
        menu_item(title: I18n.t(:label_created_by_me),
                  query_params: { filters: author_filter })
      ]
    end

    def query_path(query_params)
      if project.present?
        project_meetings_path(project, params.permit(query_params.keys).merge!(query_params))
      else
        meetings_path(params.permit(query_params.keys).merge!(query_params))
      end
    end

    def past_filter
      [
        { time: { operator: "=", values: ["past"] } },
        { invited_user_id: { operator: "=", values: [User.current.id.to_s] } }
      ].to_json
    end

    def attendee_filter
      [{ attended_user_id: { operator: "=", values: [User.current.id.to_s] } }].to_json
    end

    def author_filter
      [{ author_id: { operator: "=", values: [User.current.id.to_s] } }].to_json
    end

    def recurring_meeting_type_filter
      [{ type: { operator: "=", values: [RecurringMeeting.to_s] } }].to_json
    end
  end
end
