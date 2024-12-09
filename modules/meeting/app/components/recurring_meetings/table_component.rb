# frozen_string_literal: true

#-- copyright
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
#++

module RecurringMeetings
  class TableComponent < ::OpPrimer::BorderBoxTableComponent
    options :current_project, :count, :direction, :max_count

    columns :start_time, :relative_time, :last_edited, :status, :create

    def has_actions?
      true
    end

    def has_footer?
      return false unless recurring_meeting

      options[:max_count] - count > 0
    end

    def footer
      render RecurringMeetings::FooterComponent.new(
        meeting: recurring_meeting,
        project: options[:current_project],
        direction: options[:direction],
        max_count: options[:max_count],
        count:
      )
    end

    def header_args(column)
      if column == :title
        { style: "grid-column: span 2" }
      else
        super
      end
    end

    def mobile_title
      I18n.t(:label_recurring_meeting_plural)
    end

    def headers
      @headers ||= [
        [:start_time, { caption: I18n.t(:label_meeting_date_and_time) }],
        [:relative_time, { caption: I18n.t("recurring_meeting.starts") }],
        [:last_edited, { caption: I18n.t(:label_meeting_last_updated) }],
        [:status, { caption: Meeting.human_attribute_name(:status) }],
        [:create, { caption: "" }]
      ].compact
    end

    def columns
      @columns ||= headers.map(&:first)
    end

    def recurring_meeting
      return if model.blank?

      @recurring_meeting ||= model.first.recurring_meeting
    end

    def count
      @count ||= [options[:count], rows.count].max
    end
  end
end
