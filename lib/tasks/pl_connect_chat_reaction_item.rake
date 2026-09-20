namespace :pl_connect_chat_reaction_item do
  desc "Description for the test rake command"
  desc "Execute: bundle exec rake pl_connect_chat_reaction_item:test_rake_command['Hello rake user!'] DEBUG_MODE=true"
  task :test_rake_command, [:example_parameter] => :environment  do |task_name, args|
    debug_mode = ((ENV["DEBUG_MODE"] == "0" || "#{ENV["DEBUG_MODE"]}".downcase == "false") ? false : true)
    Rails.logger.warn("task:  #{task_name} - start")
    @c = ApplicationHelper.init_tenant(:default)
    puts "You write: #{args[:example_parameter]}"
    Rails.logger.warn("task:  #{task_name} - end")
  end
end
