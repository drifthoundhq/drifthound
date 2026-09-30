namespace :api_tokens do
  desc "Generate a new API token (access: write, read_plans or read, default write)"
  task :generate, [ :name, :access ] => :environment do |t, args|
    name = args[:name] || "default"
    access = args[:access] || "write"
    token = ApiToken.create!(name: name, access: access)
    puts "API Token created successfully!"
    puts "Name: #{token.name}"
    puts "Access: #{token.access}"
    puts "Token: #{token.token}"
    puts ""
    puts "Use this token in the Authorization header:"
    puts "Authorization: Bearer #{token.token}"
  end

  desc "List all API tokens"
  task list: :environment do
    tokens = ApiToken.all
    if tokens.empty?
      puts "No API tokens found."
    else
      puts "API Tokens:"
      puts "-" * 60
      tokens.each do |token|
        puts "ID: #{token.id} | Name: #{token.name} | Access: #{token.access} | Created: #{token.created_at}"
      end
    end
  end

  desc "Revoke an API token by ID"
  task :revoke, [ :id ] => :environment do |t, args|
    token = ApiToken.find_by(id: args[:id])
    if token
      token.destroy
      puts "API Token '#{token.name}' (ID: #{token.id}) has been revoked."
    else
      puts "API Token with ID #{args[:id]} not found."
    end
  end
end
