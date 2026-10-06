class DashboardController < ApplicationController
  before_action :require_login_unless_public

  def index
    @projects = Project.includes(environments: :drift_checks).order(:name)
    @project_environments = []
    @projects.each do |project|
      project.environments.order(:name).each do |env|
        @project_environments << [ project, env ]
      end
    end
    # Count each project/environment pair by environment status (per project in environment)
    @project_environment_status_counts = Hash.new(0)
    @project_environments.each do |(_project, env)|
      @project_environment_status_counts[env.last_check_status] += 1
    end

    # Build chart data
    @drift_chart_data = build_drift_chart_data
    @status_distribution_data = build_status_distribution_data
    @checks_per_project_data = build_checks_per_project_data
    @weekly_trend_data = build_weekly_trend_data
    @environment_health_data = build_environment_health_data
    @check_duration_data = build_check_duration_data
    @resource_changes_data = build_resource_changes_data
    @drift_rate_data = build_drift_rate_data
    @check_volume_data = build_check_volume_data
    @top_drifting_data = build_top_drifting_data
    @change_impact_data = build_change_impact_data
    @stability_score_data = build_stability_score_data
  end

  private

  def metrics_environments
    Environment.included_in_metrics
  end

  def metrics_drift_checks
    DriftCheck.where(environment_id: metrics_environments.select(:id))
  end

  def build_drift_chart_data
    # Get all environment names
    env_names = metrics_environments.distinct.pluck(:name)

    # Generate all dates in range
    dates = (30.days.ago.to_date..Date.current).to_a
    date_labels = dates.map { |d| d.strftime("%b %d") }

    # Get counts grouped by environment name, date and status
    raw_data = metrics_drift_checks
      .joins(environment: :project)
      .where(created_at: 30.days.ago.beginning_of_day..)
      .group("environments.name")
      .group("DATE(drift_checks.created_at)")
      .group(:status)
      .count

    # Build data for "all" environments (aggregated)
    all_drift = []
    all_error = []
    all_ok = []

    dates.each do |date|
      drift_sum = 0
      error_sum = 0
      ok_sum = 0
      env_names.each do |env_name|
        drift_sum += (raw_data[[ env_name, date, "drift" ]] || 0)
        error_sum += (raw_data[[ env_name, date, "error" ]] || 0)
        ok_sum += (raw_data[[ env_name, date, "ok" ]] || 0)
      end
      all_drift << drift_sum
      all_error << error_sum
      all_ok << ok_sum
    end

    # Build per-environment data
    by_environment = {}
    env_names.each do |env_name|
      drift_counts = []
      error_counts = []
      ok_counts = []

      dates.each do |date|
        drift_counts << (raw_data[[ env_name, date, "drift" ]] || 0)
        error_counts << (raw_data[[ env_name, date, "error" ]] || 0)
        ok_counts << (raw_data[[ env_name, date, "ok" ]] || 0)
      end

      by_environment[env_name] = {
        drift: drift_counts,
        error: error_counts,
        ok: ok_counts
      }
    end

    {
      dates: date_labels,
      all: { drift: all_drift, error: all_error, ok: all_ok },
      by_environment: by_environment
    }
  end

  def build_status_distribution_data
    # Get all environment names for filtering
    env_names = metrics_environments.distinct.pluck(:name)

    # Overall status distribution (last 30 days)
    all_counts = metrics_drift_checks
      .where(created_at: 30.days.ago.beginning_of_day..)
      .group(:status)
      .count

    # Per-environment status distribution
    by_environment = {}
    env_names.each do |env_name|
      counts = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 30.days.ago.beginning_of_day..)
        .group(:status)
        .count

      by_environment[env_name] = {
        ok: counts["ok"] || 0,
        drift: counts["drift"] || 0,
        error: counts["error"] || 0
      }
    end

    {
      all: {
        ok: all_counts["ok"] || 0,
        drift: all_counts["drift"] || 0,
        error: all_counts["error"] || 0
      },
      by_environment: by_environment
    }
  end

  def build_checks_per_project_data
    # Get all environment names for filtering
    env_names = metrics_environments.distinct.pluck(:name)

    # Checks per project (last 30 days) - all environments
    all_data = metrics_drift_checks
      .joins(environment: :project)
      .where(created_at: 30.days.ago.beginning_of_day..)
      .group("projects.name")
      .group(:status)
      .count

    project_names = all_data.keys.map(&:first).uniq.sort

    all_ok = []
    all_drift = []
    all_error = []

    project_names.each do |name|
      all_ok << (all_data[[ name, "ok" ]] || 0)
      all_drift << (all_data[[ name, "drift" ]] || 0)
      all_error << (all_data[[ name, "error" ]] || 0)
    end

    # Per-environment data
    by_environment = {}
    env_names.each do |env_name|
      env_data = metrics_drift_checks
        .joins(environment: :project)
        .where(environments: { name: env_name })
        .where(created_at: 30.days.ago.beginning_of_day..)
        .group("projects.name")
        .group(:status)
        .count

      env_projects = env_data.keys.map(&:first).uniq.sort
      ok = []
      drift = []
      error = []

      env_projects.each do |name|
        ok << (env_data[[ name, "ok" ]] || 0)
        drift << (env_data[[ name, "drift" ]] || 0)
        error << (env_data[[ name, "error" ]] || 0)
      end

      by_environment[env_name] = {
        labels: env_projects,
        ok: ok,
        drift: drift,
        error: error
      }
    end

    {
      labels: project_names,
      all: { ok: all_ok, drift: all_drift, error: all_error },
      by_environment: by_environment
    }
  end

  def build_weekly_trend_data
    # Get all environment names for filtering
    env_names = metrics_environments.distinct.pluck(:name)

    # Weekly averages (last 8 weeks)
    weeks = 8.times.map { |i| i.weeks.ago.beginning_of_week.to_date }
    week_labels = weeks.reverse.map { |w| w.strftime("%b %d") }

    # All environments
    all_ok_avg = []
    all_drift_avg = []
    all_error_avg = []

    weeks.reverse.each do |week_start|
      week_end = week_start + 6.days
      counts = metrics_drift_checks
        .where(created_at: week_start.beginning_of_day..week_end.end_of_day)
        .group(:status)
        .count

      total = counts.values.sum.to_f
      if total > 0
        all_ok_avg << ((counts["ok"] || 0) / total * 100).round(1)
        all_drift_avg << ((counts["drift"] || 0) / total * 100).round(1)
        all_error_avg << ((counts["error"] || 0) / total * 100).round(1)
      else
        all_ok_avg << 0
        all_drift_avg << 0
        all_error_avg << 0
      end
    end

    # Per-environment weekly data
    by_environment = {}
    env_names.each do |env_name|
      ok_avg = []
      drift_avg = []
      error_avg = []

      weeks.reverse.each do |week_start|
        week_end = week_start + 6.days
        counts = metrics_drift_checks
          .joins(:environment)
          .where(environments: { name: env_name })
          .where(created_at: week_start.beginning_of_day..week_end.end_of_day)
          .group(:status)
          .count

        total = counts.values.sum.to_f
        if total > 0
          ok_avg << ((counts["ok"] || 0) / total * 100).round(1)
          drift_avg << ((counts["drift"] || 0) / total * 100).round(1)
          error_avg << ((counts["error"] || 0) / total * 100).round(1)
        else
          ok_avg << 0
          drift_avg << 0
          error_avg << 0
        end
      end

      by_environment[env_name] = {
        ok: ok_avg,
        drift: drift_avg,
        error: error_avg
      }
    end

    {
      labels: week_labels,
      all: { ok: all_ok_avg, drift: all_drift_avg, error: all_error_avg },
      by_environment: by_environment
    }
  end

  def build_environment_health_data
    # Status breakdown per environment type (horizontal bar chart)
    env_names = metrics_environments.distinct.pluck(:name).sort

    labels = env_names
    ok_data = []
    drift_data = []
    error_data = []

    env_names.each do |env_name|
      counts = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 30.days.ago.beginning_of_day..)
        .group(:status)
        .count

      ok_data << (counts["ok"] || 0)
      drift_data << (counts["drift"] || 0)
      error_data << (counts["error"] || 0)
    end

    {
      labels: labels,
      ok: ok_data,
      drift: drift_data,
      error: error_data
    }
  end

  def build_check_duration_data
    # Average check duration over time (line chart)
    dates = (14.days.ago.to_date..Date.current).to_a
    date_labels = dates.map { |d| d.strftime("%b %d") }

    # Get average durations by date
    raw_data = metrics_drift_checks
      .where(created_at: 14.days.ago.beginning_of_day..)
      .where.not(duration: nil)
      .group("DATE(created_at)")
      .average(:duration)

    durations = dates.map { |date| (raw_data[date]&.round(1)) || 0 }

    # Per-environment data
    env_names = metrics_environments.distinct.pluck(:name)
    by_environment = {}

    env_names.each do |env_name|
      env_raw = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 14.days.ago.beginning_of_day..)
        .where.not(duration: nil)
        .group("DATE(drift_checks.created_at)")
        .average(:duration)

      env_durations = dates.map { |date| (env_raw[date]&.round(1)) || 0 }
      by_environment[env_name] = env_durations
    end

    {
      labels: date_labels,
      all: durations,
      by_environment: by_environment
    }
  end

  def build_resource_changes_data
    # Resource changes over time (add/change/destroy counts)
    dates = (14.days.ago.to_date..Date.current).to_a
    date_labels = dates.map { |d| d.strftime("%b %d") }
    env_names = metrics_environments.distinct.pluck(:name)

    # Aggregate data by date using separate sum queries
    adds_raw = metrics_drift_checks
      .where(created_at: 14.days.ago.beginning_of_day..)
      .group("DATE(created_at)")
      .sum(:add_count)

    changes_raw = metrics_drift_checks
      .where(created_at: 14.days.ago.beginning_of_day..)
      .group("DATE(created_at)")
      .sum(:change_count)

    destroys_raw = metrics_drift_checks
      .where(created_at: 14.days.ago.beginning_of_day..)
      .group("DATE(created_at)")
      .sum(:destroy_count)

    adds = dates.map { |d| adds_raw[d] || 0 }
    changes = dates.map { |d| changes_raw[d] || 0 }
    destroys = dates.map { |d| destroys_raw[d] || 0 }

    # Per-environment data
    by_environment = {}
    env_names.each do |env_name|
      env_adds = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 14.days.ago.beginning_of_day..)
        .group("DATE(drift_checks.created_at)")
        .sum(:add_count)

      env_changes = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 14.days.ago.beginning_of_day..)
        .group("DATE(drift_checks.created_at)")
        .sum(:change_count)

      env_destroys = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 14.days.ago.beginning_of_day..)
        .group("DATE(drift_checks.created_at)")
        .sum(:destroy_count)

      by_environment[env_name] = {
        adds: dates.map { |d| env_adds[d] || 0 },
        changes: dates.map { |d| env_changes[d] || 0 },
        destroys: dates.map { |d| env_destroys[d] || 0 }
      }
    end

    {
      labels: date_labels,
      all: { adds: adds, changes: changes, destroys: destroys },
      by_environment: by_environment
    }
  end

  def build_drift_rate_data
    # Drift rate percentage over time
    dates = (14.days.ago.to_date..Date.current).to_a
    date_labels = dates.map { |d| d.strftime("%b %d") }
    env_names = metrics_environments.distinct.pluck(:name)

    # Get counts by date and status
    raw_data = metrics_drift_checks
      .where(created_at: 14.days.ago.beginning_of_day..)
      .group("DATE(created_at)")
      .group(:status)
      .count

    drift_rates = dates.map do |date|
      total = (raw_data[[ date, "ok" ]] || 0) + (raw_data[[ date, "drift" ]] || 0) + (raw_data[[ date, "error" ]] || 0)
      drift_count = raw_data[[ date, "drift" ]] || 0
      total > 0 ? (drift_count.to_f / total * 100).round(1) : 0
    end

    # Per-environment drift rates
    by_environment = {}
    env_names.each do |env_name|
      env_raw = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 14.days.ago.beginning_of_day..)
        .group("DATE(drift_checks.created_at)")
        .group(:status)
        .count

      env_rates = dates.map do |date|
        total = (env_raw[[ date, "ok" ]] || 0) + (env_raw[[ date, "drift" ]] || 0) + (env_raw[[ date, "error" ]] || 0)
        drift_count = env_raw[[ date, "drift" ]] || 0
        total > 0 ? (drift_count.to_f / total * 100).round(1) : 0
      end

      by_environment[env_name] = env_rates
    end

    {
      labels: date_labels,
      all: drift_rates,
      by_environment: by_environment
    }
  end

  def build_check_volume_data
    # Number of checks per day
    dates = (14.days.ago.to_date..Date.current).to_a
    date_labels = dates.map { |d| d.strftime("%b %d") }
    env_names = metrics_environments.distinct.pluck(:name)

    # Count checks per day
    raw_data = metrics_drift_checks
      .where(created_at: 14.days.ago.beginning_of_day..)
      .group("DATE(created_at)")
      .count

    volumes = dates.map { |d| raw_data[d] || 0 }

    # Per-environment volumes
    by_environment = {}
    env_names.each do |env_name|
      env_raw = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 14.days.ago.beginning_of_day..)
        .group("DATE(drift_checks.created_at)")
        .count

      by_environment[env_name] = dates.map { |d| env_raw[d] || 0 }
    end

    {
      labels: date_labels,
      all: volumes,
      by_environment: by_environment
    }
  end

  def build_top_drifting_data
    # Top projects by drift count/rate (last 30 days)
    env_names = metrics_environments.distinct.pluck(:name)

    # Get drift counts per project
    drift_counts = metrics_drift_checks
      .joins(environment: :project)
      .where(status: :drift)
      .where(created_at: 30.days.ago.beginning_of_day..)
      .group("projects.name")
      .count

    # Get total counts per project for calculating rate
    total_counts = metrics_drift_checks
      .joins(environment: :project)
      .where(created_at: 30.days.ago.beginning_of_day..)
      .group("projects.name")
      .count

    # Calculate drift rate and sort by it
    project_stats = drift_counts.map do |project_name, drift_count|
      total = total_counts[project_name] || 1
      rate = (drift_count.to_f / total * 100).round(1)
      { name: project_name, drift_count: drift_count, total: total, rate: rate }
    end

    # Sort by drift rate descending, take top 10
    top_projects = project_stats.sort_by { |p| -p[:rate] }.first(10)

    labels = top_projects.map { |p| p[:name] }
    rates = top_projects.map { |p| p[:rate] }
    counts = top_projects.map { |p| p[:drift_count] }

    # Per-environment data
    by_environment = {}
    env_names.each do |env_name|
      env_drift = metrics_drift_checks
        .joins(environment: :project)
        .where(environments: { name: env_name })
        .where(status: :drift)
        .where(created_at: 30.days.ago.beginning_of_day..)
        .group("projects.name")
        .count

      env_total = metrics_drift_checks
        .joins(environment: :project)
        .where(environments: { name: env_name })
        .where(created_at: 30.days.ago.beginning_of_day..)
        .group("projects.name")
        .count

      env_stats = env_drift.map do |project_name, drift_count|
        total = env_total[project_name] || 1
        rate = (drift_count.to_f / total * 100).round(1)
        { name: project_name, drift_count: drift_count, rate: rate }
      end

      env_top = env_stats.sort_by { |p| -p[:rate] }.first(10)

      by_environment[env_name] = {
        labels: env_top.map { |p| p[:name] },
        rates: env_top.map { |p| p[:rate] },
        counts: env_top.map { |p| p[:drift_count] }
      }
    end

    {
      labels: labels,
      all: { rates: rates, counts: counts },
      by_environment: by_environment
    }
  end

  def build_change_impact_data
    # Stacked area: proportion of adds vs changes vs destroys over time
    dates = (14.days.ago.to_date..Date.current).to_a
    date_labels = dates.map { |d| d.strftime("%b %d") }
    env_names = metrics_environments.distinct.pluck(:name)

    adds_raw = metrics_drift_checks
      .where(created_at: 14.days.ago.beginning_of_day..)
      .group("DATE(created_at)")
      .sum(:add_count)

    changes_raw = metrics_drift_checks
      .where(created_at: 14.days.ago.beginning_of_day..)
      .group("DATE(created_at)")
      .sum(:change_count)

    destroys_raw = metrics_drift_checks
      .where(created_at: 14.days.ago.beginning_of_day..)
      .group("DATE(created_at)")
      .sum(:destroy_count)

    adds = dates.map { |d| adds_raw[d] || 0 }
    changes = dates.map { |d| changes_raw[d] || 0 }
    destroys = dates.map { |d| destroys_raw[d] || 0 }

    # Per-environment data
    by_environment = {}
    env_names.each do |env_name|
      env_adds = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 14.days.ago.beginning_of_day..)
        .group("DATE(drift_checks.created_at)")
        .sum(:add_count)

      env_changes = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 14.days.ago.beginning_of_day..)
        .group("DATE(drift_checks.created_at)")
        .sum(:change_count)

      env_destroys = metrics_drift_checks
        .joins(:environment)
        .where(environments: { name: env_name })
        .where(created_at: 14.days.ago.beginning_of_day..)
        .group("DATE(drift_checks.created_at)")
        .sum(:destroy_count)

      by_environment[env_name] = {
        adds: dates.map { |d| env_adds[d] || 0 },
        changes: dates.map { |d| env_changes[d] || 0 },
        destroys: dates.map { |d| env_destroys[d] || 0 }
      }
    end

    {
      labels: date_labels,
      all: { adds: adds, changes: changes, destroys: destroys },
      by_environment: by_environment
    }
  end

  def build_stability_score_data
    # Stability Score: percentage of project-environments that have been consecutively OK
    # Shows a gauge with overall stability and breakdown by streak duration
    env_names = metrics_environments.distinct.pluck(:name)

    # Get all project-environments with their recent check history
    environments = metrics_environments.includes(:project).where.not(last_checked_at: nil)

    total_envs = environments.count
    return { score: 0, breakdown: { stable_7plus: 0, stable_3to6: 0, unstable: 0 }, by_environment: {} } if total_envs == 0

    # Calculate consecutive OK streak for each environment
    streaks = environments.map do |env|
      # Get last N checks for this environment, most recent first
      recent_checks = env.drift_checks.order(created_at: :desc).limit(14).pluck(:status)

      # Count consecutive OKs from most recent
      consecutive_ok = 0
      recent_checks.each do |status|
        break unless status == "ok"
        consecutive_ok += 1
      end

      { env: env, streak: consecutive_ok, current_status: env.last_check_status }
    end

    # Categorize by streak length
    stable_7plus = streaks.count { |s| s[:streak] >= 7 }
    stable_3to6 = streaks.count { |s| s[:streak] >= 3 && s[:streak] < 7 }
    unstable = streaks.count { |s| s[:streak] < 3 }

    # Calculate overall stability score (weighted)
    # 7+ days = 100%, 3-6 days = 50%, <3 days = 0%
    score = ((stable_7plus * 100) + (stable_3to6 * 50)).to_f / total_envs
    score = score.round(1)

    # Per-environment breakdown
    by_environment = {}
    env_names.each do |env_name|
      env_streaks = streaks.select { |s| s[:env].name == env_name }
      env_total = env_streaks.count
      next if env_total == 0

      env_stable_7plus = env_streaks.count { |s| s[:streak] >= 7 }
      env_stable_3to6 = env_streaks.count { |s| s[:streak] >= 3 && s[:streak] < 7 }
      env_unstable = env_streaks.count { |s| s[:streak] < 3 }
      env_score = ((env_stable_7plus * 100) + (env_stable_3to6 * 50)).to_f / env_total

      by_environment[env_name] = {
        score: env_score.round(1),
        breakdown: {
          stable_7plus: env_stable_7plus,
          stable_3to6: env_stable_3to6,
          unstable: env_unstable
        }
      }
    end

    {
      score: score,
      total: total_envs,
      breakdown: {
        stable_7plus: stable_7plus,
        stable_3to6: stable_3to6,
        unstable: unstable
      },
      by_environment: by_environment
    }
  end
end
