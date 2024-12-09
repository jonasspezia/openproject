class RecurringMeeting < ApplicationRecord
  include ::Meeting::VirtualStartTime
  include Redmine::I18n

  belongs_to :project
  belongs_to :author, class_name: "User"

  validates_presence_of :start_time, :title, :frequency, :end_after
  validates_presence_of :end_date, if: -> { end_after_specific_date? }
  validates_numericality_of :iterations, if: -> { end_after_iterations? }
  validates_numericality_of :interval,
                            only_integer: true,
                            greater_than_or_equal_to: 1,
                            if: -> { !frequency_working_days? }

  validate :end_date_constraints,
           if: -> { end_after_specific_date? }

  after_save :unset_schedule

  enum frequency: {
    daily: 0,
    working_days: 1,
    weekly: 2
  }.freeze, _prefix: true, _default: "weekly"

  enum end_after: {
    specific_date: 0,
    iterations: 1
  }.freeze, _prefix: true, _default: "specific_date"

  has_many :meetings,
           inverse_of: :recurring_meeting,
           dependent: :destroy

  has_many :scheduled_meetings,
           inverse_of: :recurring_meeting,
           dependent: :delete_all

  has_one :template, -> { where(template: true) },
          class_name: "Meeting"

  scope :visible, ->(*args) {
    includes(:project)
      .references(:projects)
      .merge(Project.allowed_to(args.first || User.current, :view_meetings))
  }

  # Keep location and duration as a virtual attribute
  # so it can be passed to the template on save
  virtual_attribute :location do
    nil
  end
  virtual_attribute :duration do
    nil
  end

  def human_frequency
    I18n.t("recurring_meeting.frequency.#{frequency}")
  end

  def human_day_of_week
    I18n.t("recurring_meeting.frequency.every_weekday", day_of_the_week: weekday)
  end

  def weekday
    I18n.l(start_time, format: "%A")
  end

  def date
    start_time.day.ordinalize
  end

  def schedule
    @schedule ||= IceCube::Schedule.new(start_time, end_time: end_date).tap do |s|
      s.add_recurrence_rule count_rule(frequency_rule)
      exclude_non_working_days(s) if frequency_working_days?
    end
  end

  def schedule_in_words # rubocop:disable Metrics/AbcSize
    base =
      case frequency
      when "daily"
        interval == 1 ? human_frequency : I18n.t("recurring_meeting.in_words.daily_interval", interval: interval.ordinalize)
      when "working_days"
        if interval == 1
          I18n.t("recurring_meeting.in_words.working_days")
        else
          I18n.t("recurring_meeting.in_words.working_days_interval", interval: interval.ordinalize)
        end
      when "weekly"
        if interval == 1
          I18n.t("recurring_meeting.in_words.weekly", weekday:)
        else
          I18n.t("recurring_meeting.in_words.weekly_interval", interval: interval.ordinalize, weekday:)
        end
      end

    I18n.t("recurring_meeting.in_words.full",
           base:,
           time: format_time(start_time, include_date: false),
           end_date: format_date(last_occurrence))
  end

  def scheduled_occurrences(limit:)
    schedule.next_occurrences(limit, Time.current)
  end

  def first_occurrence
    schedule.first
  end

  def last_occurrence
    schedule.last
  end

  def next_occurrence(from_time: Time.current)
    schedule.next_occurrence(from_time)
  end

  def remaining_occurrences
    if end_date.present?
      schedule.occurrences_between(Time.current, end_date)
    else
      schedule.remaining_occurrences(Time.current)
    end
  end

  def scheduled_instances(upcoming: true)
    filter_scope = upcoming ? :upcoming : :past
    direction = upcoming ? :asc : :desc

    scheduled_meetings
      .includes(:meeting)
      .public_send(filter_scope)
      .then { |o| filter_scope == :past ? o.not_cancelled : o }
      .order(start_time: direction)
  end

  private

  def unset_schedule
    @schedule = nil
  end

  def end_date_constraints
    return if end_date.nil?

    if end_date < Date.current
      errors.add(:end_date, :after_today)
    end

    if parsed_start_date.present? && end_date < parsed_start_date
      errors.add(:end_date, :after, date: format_date(parsed_start_date))
    end
  end

  def exclude_non_working_days(schedule)
    NonWorkingDay
      .where(date: start_date...)
      .pluck(:date)
      .each do |date|
      schedule.add_exception_time(date.to_time(:utc))
    end
  end

  def frequency_rule
    case frequency
    when "daily"
      IceCube::Rule.daily(interval)
    when "working_days"
      IceCube::Rule
        .weekly(interval)
        .day(*Setting.working_day_names)
    when "weekly"
      IceCube::Rule.weekly(interval)
    else
      raise NotImplementedError
    end
  end

  def count_rule(rule)
    if end_after_iterations?
      rule.count(iterations)
    else
      rule.until(end_date.to_time(:utc))
    end
  end
end
