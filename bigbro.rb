require File.join(File.dirname(__FILE__), 'harvest')
require 'json'
require 'yaml'
require 'date'

class Bigbro 
  def initialize
    @harvest = Harvest.new

    #load YAML databases
    @projects = YAML.load_file("projects.yml") if File.exists?("projects.yml")
    @users = YAML.load_file("users.yml") if File.exists?("users.yml")
  end
  
  # grab user db from harvest and save as YAML
  def update_users_db
    response = @harvest.request "/people", :get
    people = Hash.new
    JSON.parse(response.body).each do |p|
      people[p["user"]["id"]] = "#{p["user"]["first_name"]} #{p["user"]["last_name"]}"
    end
    File.open('users.yml', 'w') { |f| f.write people.to_yaml } 
  end

  # grab user db from harvest and save as YAML
  def update_projects_db
    response = @harvest.request "/projects", :get
    projects = Hash.new
    JSON.parse(response.body).each do |p|
      projects[p["project"]["id"]] = p["project"]["name"]
    end
    File.open('projects.yml', 'w') { |f| f.write projects.to_yaml } 
  end

  def range_summary project_id, start_date, end_date
    response = @harvest.request "/projects/#{project_id}/entries?from=#{start_date}&to=#{end_date}", :get
    entries = JSON.parse(response.body)
    total, users = 0, Hash.new(0)
    
    entries.each do |e|
      users[e["day_entry"]["user_id"]] += e["day_entry"]["hours"].to_f
      total = total + e["day_entry"]["hours"].to_f
    end
    users.each { |k,v| puts "#{@users[k]} had #{v.to_i} hours" }
    puts "PROJECT SUMMARY #{@projects[project_id]} #{start_date} - #{end_date} TOTAL: #{total.to_i}"

  end

  def weekly_summary project_id
    day_of_week = Time.now.wday
    past_sunday = (Date.today - day_of_week).to_s
    two_saturdays_ago = (Date.today - day_of_week - 6).to_s
    range_summary project_id, two_saturdays_ago, past_sunday
  end

  def project_total project_id, end_date = nil
    end_date = Date.today.to_s if end_date.nil?
    response = @harvest.request "/projects/#{project_id}", :get
    project = JSON.parse(response.body)

    response = @harvest.request "/projects/#{project_id}/entries?from=2006-01-01&to=#{end_date}", :get
    entries = JSON.parse(response.body)
    to_date = 0
    entries.each { |e| to_date += e["day_entry"]["hours"].to_f }

    puts "PROJECT TOTAL #{@projects[project_id]} #{to_date.to_i}/#{project["project"]["budget"]} through #{end_date}"
  end

end
