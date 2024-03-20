require 'open3'
require 'pathname'
require 'English'

def env_has_key(key)
  !ENV[key].nil? && ENV[key] != '' ? ENV[key] : abort("Missing #{key}.")
end

platform = ENV['AC_PLATFORM_TYPE']
output_dir = env_has_key('AC_OUTPUT_DIR')
app_path = env_has_key('AC_MARATHON_APP_PATH')
test_app_path = env_has_key('AC_MARATHON_UITEST_RUNNER_APP_PATH')
api_key = env_has_key('AC_MARATHON_API_KEY')
test_name = env_has_key('AC_MARATHON_TEST_NAME')

def run_command(command)
  puts "@@[command] #{command}"
  return if system(command)

  exit_status = $?.exitstatus

  if exit_status == 1
    puts 'Marathon has failed test case. Pipeline broken. Please check your MarathonLab Dashboard'
    exit exit_status
  elsif exit_status == 0
    puts 'Marathon success. There are no any fail test case.'
    exit exit_status
  else
    exit exit_status
  end
end

def prepare_marathon_cli
  puts 'Preparing Marathon-Cloud CLI Tools'
  run_command('brew tap malinskiy/tap')
  run_command('HOMEBREW_NO_INSTALL_CLEANUP=1 brew install malinskiy/tap/marathon-cloud')
end

def run_marathon(output_dir, app_path, test_app_path, api_key, test_name, platform)
  puts 'Starting Marathon Tests'
  platform_type = platform == 'ObjectiveCSwift' ? 'ios' : 'android'
  command = "marathon-cloud run #{platform_type} --application #{app_path} --test-application #{test_app_path} --name #{test_name} --api-key #{api_key} --output #{output_dir}"
  run_command(command)
end

prepare_marathon_cli
run_marathon(output_dir, app_path, test_app_path, api_key, test_name, platform)
