require 'open3'
require 'pathname'
require 'English'
require 'digest'
require 'fileutils'

# The version the malinskiy/tap formula installed when this was pinned; checksums from the release's checksums.txt.
MARATHON_CLI_VERSION = '1.0.68'.freeze
MARATHON_CLI_SHA256 = {
  'universal-apple-darwin' => 'be683879af552da8266625ebfe47e0d3c40fd7b6d166fbd96292ce92303864df',
  'x86_64-unknown-linux-gnu' => '93bf8132638ce4d04148d839beca62528631d47aeb6b6a13cf564b22cf08b077',
  'aarch64-unknown-linux-gnu' => '9ce9a683a8d25c4b1b97120ceac7c85f22f2a5fb7d737b47dd36616d4b1e2293'
}.freeze

def env_has_key(key)
  !ENV[key].nil? && ENV[key] != '' ? ENV[key] : abort("Missing #{key}.")
end

platform = ENV['AC_PLATFORM_TYPE']
output_dir = env_has_key('AC_OUTPUT_DIR')
app_path = env_has_key('AC_MARATHON_APP_PATH')
test_app_path = env_has_key('AC_MARATHON_UITEST_RUNNER_APP_PATH')
api_key = env_has_key('AC_MARATHON_API_KEY')
test_name = env_has_key('AC_MARATHON_TEST_NAME')
marathon_base_url = (ENV['AC_MARATHON_BASE_URL'].to_s.empty? ? 'https://github.com/MarathonLabs/marathon-cloud-cli/releases/download' : ENV['AC_MARATHON_BASE_URL']).chomp('/')

def run_command(command)
  puts "@@[command] #{command}"
  return if system(command)

  exit_status = $?.exitstatus

  if exit_status == 1
    puts 'Marathon has failed test cases! Please check your Marathon Cloud dashboard.'
  end
  exit exit_status
end

def prepare_marathon_cli(base_url)
  puts 'Preparing Marathon Cloud CLI Tools...'
  if system('which marathon-cloud > /dev/null 2>&1')
    puts 'marathon-cloud is already installed, skipping download.'
    return
  end

  target = marathon_target
  install_dir = "#{Dir.home}/marathon-cloud/#{MARATHON_CLI_VERSION}"
  unless File.exist?("#{install_dir}/marathon-cloud")
    archive_name = "marathon-cloud-v#{MARATHON_CLI_VERSION}-#{target}.tar.gz"
    archive_url = "#{base_url}/#{MARATHON_CLI_VERSION}/#{archive_name}"
    puts "Downloading marathon-cloud #{MARATHON_CLI_VERSION} from #{archive_url}"
    download_and_verify(archive_url, archive_name, MARATHON_CLI_SHA256[target])
    FileUtils.mkdir_p(install_dir)
    install_command = "tar -xzf #{archive_name} --strip-components 1 -C #{install_dir}"
    puts "@@[command] #{install_command}"
    system(install_command) || abort('Could not extract the marathon-cloud archive.')
    FileUtils.rm_f(archive_name)
  end
  ENV['PATH'] = "#{install_dir}:#{ENV['PATH']}"
end

# Release targets of the pinned CLI: universal on macOS, gnu builds on Linux.
def marathon_target
  return 'universal-apple-darwin' if RUBY_PLATFORM.include?('darwin')

  `uname -m`.strip == 'aarch64' ? 'aarch64-unknown-linux-gnu' : 'x86_64-unknown-linux-gnu'
end

# Install failures abort here instead of going through run_command, which reports exit code 1 as failed tests.
def download_and_verify(url, file, expected_checksum)
  command = "curl -fsSL --retry 3 -o #{file} #{url}"
  puts "@@[command] #{command}"
  system(command) || abort("Could not download #{url}")
  checksum = Digest::SHA256.file(file).hexdigest
  abort "Checksum mismatch for #{file}: expected #{expected_checksum}, got #{checksum}" unless checksum == expected_checksum
  puts "Checksum verified: #{checksum}"
end

def run_marathon(output_dir, app_path, test_app_path, api_key, test_name, platform)
  puts 'Starting Tests on Marathon Cloud...'
  platform_type = platform == 'ObjectiveCSwift' ? 'ios' : 'android'
  command = "marathon-cloud run #{platform_type} --application #{app_path} --test-application #{test_app_path} --name #{test_name} --api-key #{api_key} --output #{output_dir}"
  run_command(command)
end

prepare_marathon_cli(marathon_base_url)
run_marathon(output_dir, app_path, test_app_path, api_key, test_name, platform)
puts 'Marathon finished with success. There are no failed test cases.'
