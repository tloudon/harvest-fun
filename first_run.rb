require File.join(File.dirname(__FILE__), 'bigbro')

obrien = Bigbro.new

obrien.update_projects_db
obrien.update_users_db
