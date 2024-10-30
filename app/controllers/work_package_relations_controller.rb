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

class WorkPackageRelationsController < ApplicationController
  include OpTurbo::ComponentStream

  before_action :set_work_package
  before_action :set_relation
  before_action :authorize

  def destroy
    service_result = Relations::DeleteService.new(user: current_user, model: @relation).call

    if service_result.success?
      @children = WorkPackage.where(parent_id: @work_package.id)
      @relations = @work_package
        .relations
        .includes(:to, :from)

      component = WorkPackageRelationsTab::IndexComponent.new(work_package: @work_package,
                                                              relations: @relations,
                                                              children: @children)
      replace_via_turbo_stream(component:)
      respond_with_turbo_streams
    else
      respond_with_turbo_streams(status: :unprocessable_entity)
    end
  end

  private

  def set_work_package
    @work_package = WorkPackage.find(params[:work_package_id])
  end

  def set_relation
    @relation = @work_package.relations.find(params[:id])
  end
end
